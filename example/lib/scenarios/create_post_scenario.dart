import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/bridge_token_signer.dart';
import '../design.dart';
import '../octopus_demo_config.dart';
import '../widgets/localized_label_editor.dart';
import '../widgets/scenario_scaffold.dart';
import '../sample_fixtures.dart';

/// Create Post (Bridge Share) scenario — open the Octopus post editor as a
/// standalone entry point, prefilled with a payload the host app builds.
///
/// Each preset builds one [OctopusPrefilledPost] combination and hands it to
/// [OctopusSDK.showOctopusCreatePostScreen] inside a
/// [CreatePostScreenInfo]. The editor then opens with the text, images, target
/// group and call-to-action the preset supplied; the member can still edit
/// everything before publishing.
///
/// The first five presets cover the payload matrix the QA catalog specifies:
/// text only, text + CTA, text + image, the full payload, and image only. The
/// last two prefill several photos: the most a post carries
/// ([OctopusPrefilledPost.maxImageCount]), then one too many, which the
/// constructor refuses with an [OctopusPrefilledPostTooManyImagesError].
/// Every field the presets read is editable in the form above them and is
/// prefilled with a valid value, so a preset works on a single tap and can also
/// be driven with custom content.
///
/// The CTA label is auto-translated by default; the form's "Label per
/// language" switch sends an [OctopusLocalizedText.perLanguage] label built from
/// its language rows (default language `en`), through
/// [OctopusPostCTA.localized].
///
/// Payload validation happens eagerly, in the [OctopusPrefilledPost]
/// constructor: an out-of-bounds text or a half-filled CTA throws an
/// [OctopusPrefilledPostValidationError] before the editor opens, and the
/// scenario reports the concrete subtype in the result panel instead of opening
/// anything. Lengthening the text past 5000 characters is the quickest way to
/// see that path.
///
/// When an SSO secret is injected at build time, the image-bearing presets also
/// register a [CreatePostScreenInfo.bridgeShareTokenProvider], which signs the
/// share with an HS256 JWT. A community configured to forbid member pictures
/// needs that signature. Without a secret (the store builds) no provider is
/// registered and the post is sent unsigned, as a provider replying `null`
/// would: a community that allows pictures publishes it, one that forbids them
/// refuses it.
///
/// A note on what this scenario is not: opening the editor *embedded* in a host
/// route (`OctopusInitialScreen.createPost`) is a different entry point, covered
/// by the Initial Screen scenario. This one presents the editor as a full
/// platform-owned screen.
class CreatePostScenario extends StatefulWidget {
  const CreatePostScenario({super.key});

  @override
  State<CreatePostScenario> createState() => _CreatePostScenarioState();
}

class _CreatePostScenarioState extends State<CreatePostScenario> {
  /// Default prefill text — a valid payload on first tap (a post text needs
  /// one visible character and at most 5000).
  static const String _defaultText =
      'Bridge Share preset — a host-supplied prefilled post from the Flutter '
      'example app.';

  /// Default CTA, attached by the presets whose name mentions a CTA.
  static const String _defaultCtaLabel = 'Open';
  static const String _defaultCtaUrl = 'https://octopuscommunity.com/preset';

  /// Bundled asset used by the image-bearing presets, repeated by the presets
  /// that prefill several photos. Shipping the bytes with the app keeps those
  /// presets a single tap — no system media picker to drive.
  static const String _imageAsset = 'assets/logo.png';

  late final TextEditingController _textCtrl;
  late final TextEditingController _ctaLabelCtrl;
  late final TextEditingController _ctaUrlCtrl;
  final LocalizedLabelController _ctaLocalizedLabel = LocalizedLabelController(
    initialRows: const [('en', _defaultCtaLabel), ('fr', 'Ouvrir')],
  );

  String? _selectedGroupId;
  bool _groupSelectionTouched = false;

  /// Payload summary of the most recent preset run, mirrored in the live-state
  /// card so the sent values stay visible while the editor is open.
  String _lastPayload = '—';

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: _defaultText);
    _ctaLabelCtrl = TextEditingController(text: _defaultCtaLabel);
    _ctaUrlCtrl = TextEditingController(text: _defaultCtaUrl);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _ctaLocalizedLabel.dispose();
    super.dispose();
  }

  /// The group id the presets target, defaulting to a real group discovered on
  /// the live [OctopusSDK.groups] stream so a preset runs out of the box.
  /// `null` means "let the member pick a group in the editor".
  String? _effectiveGroupId(List<OctopusGroup> groups) {
    if (_groupSelectionTouched) {
      final selected = _selectedGroupId;
      if (selected == null) return null;
      return groups.any((g) => g.id == selected) ? selected : null;
    }
    return sampleFixtures.defaultGroupId(groups);
  }

  Future<Uint8List?> _loadBundledImage(ScenarioResultSink setResult) async {
    try {
      final data = await rootBundle.load(_imageAsset);
      return data.buffer.asUint8List();
    } catch (e) {
      setResult('Failed to load $_imageAsset: $e', isError: true);
      return null;
    }
  }

  /// Builds the payload for one preset and opens the editor with it.
  ///
  /// [withText] / [withCta] / [imageCount] describe the preset's combination;
  /// the values themselves come from the form above the presets.
  Future<void> _openEditor(
    ScenarioResultSink setResult, {
    required String presetLabel,
    required bool withText,
    required bool withCta,
    required int imageCount,
  }) async {
    final app = AppScope.of(context);
    final text = withText ? _textCtrl.text : null;
    final topicId = _effectiveGroupId(app.groups);

    OctopusPostCTA? cta;
    if (withCta) {
      final label = _ctaLabelCtrl.text;
      final rawUrl = _ctaUrlCtrl.text;
      final parsedUrl = Uri.tryParse(rawUrl);
      if (parsedUrl == null) {
        setResult('CTA url is not a valid URI: "$rawUrl"', isError: true);
        return;
      }
      // Unchecked here when given per language: the native SDK validates it
      // when the editor opens, and the call then throws the typed error.
      cta = OctopusPostCTA.localized(
        url: parsedUrl,
        localizedLabel: _ctaLocalizedLabel.build(label),
      );
    }

    var images = const <Uint8List>[];
    if (imageCount > 0) {
      final image = await _loadBundledImage(setResult);
      if (image == null) return;
      if (!mounted) return;
      images = List.filled(imageCount, image);
    }
    final hasImages = images.isNotEmpty;

    OctopusPrefilledPost prefill;
    try {
      prefill = OctopusPrefilledPost(
        text: text,
        images: images,
        topicId: topicId,
        cta: cta,
      );
    } on OctopusPrefilledPostTooManyImagesError catch (e) {
      setResult(
        'OctopusPrefilledPost rejected the payload: ${e.count} images, at most '
        '${e.max} accepted (${e.runtimeType}). The editor was not opened.',
        isError: true,
      );
      return;
    } on OctopusPrefilledPostValidationError catch (e) {
      setResult(
        'OctopusPrefilledPost rejected the payload: ${e.runtimeType} '
        '(${e.message ?? 'no message'}). The editor was not opened.',
        isError: true,
      );
      return;
    }

    final imagesSummary = hasImages
        ? '${images.length} × $_imageAsset (${images.first.length} bytes each)'
        : '(none)';
    final payloadSummary =
        'text: ${text == null || text.isEmpty ? '(none)' : '${text.length} chars'} · '
        'images: $imagesSummary · '
        'group: ${topicId ?? '(member picks)'} · '
        'CTA: ${cta == null ? '(none)' : '${LocalizedLabelController.describe(cta.localizedLabel)} → ${cta.url}'}';
    if (mounted) setState(() => _lastPayload = payloadSummary);

    try {
      demoLog.apiCall('showOctopusCreatePostScreen', {
        'preset': presetLabel,
        'text': text ?? '(none)',
        'images': imagesSummary,
        'topicId': topicId ?? '(none)',
        'cta': cta == null
            ? '(none)'
            : 'label=${LocalizedLabelController.describe(cta.localizedLabel)}, '
                  'url=${cta.url}',
        'bridgeShareTokenProvider': hasImages && hasInjectedSsoSecret
            ? 'set (signs via the demo SSO secret)'
            : '(none)',
      });
      setResult(
        'Opening the post editor prefilled with — $payloadSummary. Publishing '
        'requires a connected member; close the editor to come back here.',
      );
      await OctopusSDK().showOctopusCreatePostScreen(
        info: CreatePostScreenInfo(
          prefilledPost: prefill,
          // Only registered for the image-bearing presets, and only when the
          // build can sign: a provider that cannot sign would reply `null`,
          // which sends the post unsigned on both platforms, the same as
          // registering none.
          bridgeShareTokenProvider: hasImages && hasInjectedSsoSecret
              ? (fingerprint) async =>
                    BridgeTokenSigner.signBridgeFingerprint(fingerprint)
              : null,
        ),
        theme: app.effectiveOctopusTheme(),
      );
    } on OctopusLocalizedTextValidationError catch (e) {
      setResult(
        'The native SDK rejected the CTA label: ${e.kind.name}'
        '${e.languageCode == null ? '' : ' (${e.languageCode})'}. The editor '
        'was not opened.',
        isError: true,
      );
    } catch (e) {
      setResult('Failed to open the post editor: $e', isError: true);
    }
  }

  /// Editable payload form, rendered above the presets.
  Widget _buildInputForm(BuildContext context, AppState app) {
    final theme = Theme.of(context);
    final groups = app.groups;
    final effectiveSelected = _effectiveGroupId(groups);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SampleSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payload', style: theme.textTheme.titleSmall),
            const SizedBox(height: SampleSpacing.space3),
            TextField(
              controller: _textCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Prefilled text (presets 1-4)',
                helperText:
                    'Min 1 / max 5000 characters. Go past 5000 to see the '
                    'payload rejected before the editor opens. Preset 5 '
                    'sends no text.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: SampleSpacing.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctaLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CTA label (presets 2 & 4)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: SampleSpacing.space3),
                Expanded(
                  child: TextField(
                    controller: _ctaUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'CTA url (presets 2 & 4)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SampleSpacing.space2),
            LocalizedLabelEditor(
              controller: _ctaLocalizedLabel,
              testIdPrefix: 'createPost-cta-label',
            ),
            const SizedBox(height: SampleSpacing.space2),
            Text(
              'The call-to-action rides along invisibly: it is not shown in the '
              'editor, only on the published post. Emptying either field makes '
              'presets 2 & 4 report a CtaLabelEmpty / CtaUrlEmpty rejection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SampleSpacing.space3),
            DropdownButtonFormField<String?>(
              dropdownColor: theme.brightness == Brightness.dark
                  ? sampleDarkElevated
                  : null,
              // Keyed on the effective value so a default seeded once the
              // groups stream loads is reflected in the displayed selection.
              key: ValueKey<String>('group-dd-${effectiveSelected ?? 'none'}'),
              initialValue: effectiveSelected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Target group (all presets)',
                helperText:
                    'Prefers topic.default, then "General" (or the first available) '
                    'from the live groups stream. Pick "— (none)" to make the '
                    'editor ask the member for a group instead. Empty only '
                    'while no community is selected or no groups have loaded.',
                border: OutlineInputBorder(),
              ),
              hint: const Text('—'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— (none)'),
                ),
                for (final group in groups)
                  DropdownMenuItem<String?>(
                    value: group.id,
                    child: Text(
                      '${group.name} · ${group.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (!mounted) return;
                setState(() {
                  _groupSelectionTouched = true;
                  _selectedGroupId = value;
                });
              },
            ),
            const SizedBox(height: SampleSpacing.space4),
            Text('Images (presets 3 to 7)', style: theme.textTheme.titleSmall),
            const SizedBox(height: SampleSpacing.space2),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(SampleRadius.md),
                  child: Image.asset(
                    _imageAsset,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: SampleSpacing.space3),
                Expanded(
                  child: Text(
                    'The image-bearing presets attach this bundled asset '
                    '($_imageAsset) — once, or repeated for presets 6 & 7 — so '
                    'they stay a one-tap action with no media picker to drive.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SampleSpacing.space4),
            Text('Last payload sent', style: theme.textTheme.titleSmall),
            const SizedBox(height: SampleSpacing.space1),
            Text(_lastPayload, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Create post (Bridge Share)',
      api: 'showOctopusCreatePostScreen',
      verifyInCommunity: true,
      description:
          'Open the Octopus post editor as a standalone screen, prefilled with '
          'a payload this app builds — text, photos, a target group and an '
          'invisible call-to-action. Each preset sends one combination; edit '
          'the form below to send your own values. An invalid payload is '
          'reported here instead of opening the editor.',
      resultTestId: 'createPost-result',
      liveState: _buildInputForm(context, app),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-createPost-1',
          label: 'Preset 1 · Text only',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'text only',
            withText: true,
            withCta: false,
            imageCount: 0,
          ),
        ),
        ScenarioPreset(
          testId: 'qa-preset-createPost-2',
          label: 'Preset 2 · Text + CTA',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'text + CTA',
            withText: true,
            withCta: true,
            imageCount: 0,
          ),
        ),
        ScenarioPreset(
          testId: 'qa-preset-createPost-3',
          label: 'Preset 3 · Text + bundled image',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'text + bundled image',
            withText: true,
            withCta: false,
            imageCount: 1,
          ),
        ),
        ScenarioPreset(
          testId: 'qa-preset-createPost-4',
          label: 'Preset 4 · Full (text + CTA + bundled image)',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'full payload',
            withText: true,
            withCta: true,
            imageCount: 1,
          ),
        ),
        ScenarioPreset(
          testId: 'qa-preset-createPost-5',
          label: 'Preset 5 · Image only (bundled)',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'image only',
            withText: false,
            withCta: false,
            imageCount: 1,
          ),
        ),
        ScenarioPreset(
          // Multi-photo presets take sample-only ids, outside the shared
          // catalog, as in the native Android sample and the React Native
          // example.
          testId: 'sample-preset-createPost-10-images',
          label:
              'Text + ${OctopusPrefilledPost.maxImageCount} bundled images '
              '(the most a post carries)',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'text + max images',
            withText: true,
            withCta: false,
            imageCount: OctopusPrefilledPost.maxImageCount,
          ),
        ),
        ScenarioPreset(
          testId: 'sample-preset-createPost-11-images',
          label:
              'Text + ${OctopusPrefilledPost.maxImageCount + 1} bundled images '
              '(rejected)',
          onRun: (setResult) => _openEditor(
            setResult,
            presetLabel: 'text + too many images',
            withText: true,
            withCta: false,
            imageCount: OctopusPrefilledPost.maxImageCount + 1,
          ),
        ),
      ],
    );
  }
}
