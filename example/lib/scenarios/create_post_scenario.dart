import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/bridge_token_signer.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Create Post (Bridge Share) scenario — open the Octopus post editor as a
/// standalone entry point, prefilled with a payload the host app builds.
///
/// Each preset builds one [OctopusPrefilledPost] combination and hands it to
/// [OctopusSDK.showOctopusCreatePostScreen] inside a
/// [CreatePostScreenInfo]. The editor then opens with the text, image, target
/// group and call-to-action the preset supplied; the member can still edit
/// everything before publishing.
///
/// The five presets cover the payload matrix the QA catalog specifies:
/// text only, text + CTA, text + image, the full payload, and image only.
/// Every field the presets read is editable in the form above them and is
/// prefilled with a valid value, so a preset works on a single tap and can also
/// be driven with custom content.
///
/// Payload validation happens eagerly, in the [OctopusPrefilledPost]
/// constructor: an out-of-bounds text or a half-filled CTA throws an
/// [OctopusPrefilledPostValidationError] before the editor opens, and the
/// scenario reports the concrete subtype in the result panel instead of opening
/// anything. Shortening the text below 10 characters is the quickest way to see
/// that path.
///
/// The image-bearing presets also register a
/// [CreatePostScreenInfo.bridgeShareTokenProvider]. It only matters in a
/// community configured to forbid member pictures: there, the SDK asks the host
/// to sign the share at publish time. The demo signer returns an HS256 JWT when
/// an SSO secret is injected at build time, and `null` otherwise — in which case
/// the image is not published.
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
  /// Default prefill text — comfortably above the 10-character minimum so the
  /// presets carry a valid payload on first tap.
  static const String _defaultText =
      'Bridge Share preset — a host-supplied prefilled post from the Flutter '
      'example app.';

  /// Default CTA, attached by the presets whose name mentions a CTA.
  static const String _defaultCtaLabel = 'Open';
  static const String _defaultCtaUrl = 'https://octopuscommunity.com/preset';

  /// Bundled asset used by the image-bearing presets. Shipping the bytes with
  /// the app keeps those presets a single tap — no system media picker to drive.
  static const String _imageAsset = 'assets/logo.png';

  /// Display name of the group the dropdown defaults to when nothing has been
  /// picked yet — the open read+write group every demo community ships. Falls
  /// back to the first available group.
  static const String _defaultGroupName = 'General';

  late final TextEditingController _textCtrl;
  late final TextEditingController _ctaLabelCtrl;
  late final TextEditingController _ctaUrlCtrl;

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
    if (groups.isEmpty) return null;
    for (final group in groups) {
      if (group.name == _defaultGroupName) return group.id;
    }
    return groups.first.id;
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
  /// [withText] / [withCta] / [withImage] describe the preset's combination;
  /// the values themselves come from the form above the presets.
  Future<void> _openEditor(
    ScenarioResultSink setResult, {
    required String presetLabel,
    required bool withText,
    required bool withCta,
    required bool withImage,
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
      cta = OctopusPostCTA(url: parsedUrl, label: label);
    }

    Uint8List? image;
    if (withImage) {
      image = await _loadBundledImage(setResult);
      if (image == null) return;
      if (!mounted) return;
    }

    OctopusPrefilledPost prefill;
    try {
      prefill = OctopusPrefilledPost(
        text: text,
        image: image,
        topicId: topicId,
        cta: cta,
      );
    } on OctopusPrefilledPostValidationError catch (e) {
      setResult(
        'OctopusPrefilledPost rejected the payload: ${e.runtimeType} '
        '(${e.message ?? 'no message'}). The editor was not opened.',
        isError: true,
      );
      return;
    }

    final payloadSummary =
        'text: ${text == null || text.isEmpty ? '(none)' : '${text.length} chars'} · '
        'image: ${image == null ? '(none)' : '$_imageAsset (${image.length} bytes)'} · '
        'group: ${topicId ?? '(member picks)'} · '
        'CTA: ${cta == null ? '(none)' : '"${cta.label}" → ${cta.url}'}';
    if (mounted) setState(() => _lastPayload = payloadSummary);

    try {
      demoLog.apiCall('showOctopusCreatePostScreen', {
        'preset': presetLabel,
        'text': text ?? '(none)',
        'image': image == null ? '(none)' : '$_imageAsset (${image.length} B)',
        'topicId': topicId ?? '(none)',
        'cta': cta == null ? '(none)' : 'label="${cta.label}", url=${cta.url}',
        'bridgeShareTokenProvider': withImage
            ? (hasInjectedSsoSecret
                  ? 'set (signs via the demo SSO secret)'
                  : 'set (returns null — no SSO secret injected)')
            : '(none)',
      });
      setResult(
        'Opening the post editor prefilled with — $payloadSummary. Publishing '
        'requires a connected member; close the editor to come back here.',
      );
      await OctopusSDK().showOctopusCreatePostScreen(
        info: CreatePostScreenInfo(
          prefilledPost: prefill,
          // Only registered for the image-bearing presets: a community that
          // allows member pictures needs no signature, and a provider that is
          // never asked for one is noise.
          bridgeShareTokenProvider: withImage
              ? (fingerprint) async =>
                    BridgeTokenSigner.signBridgeFingerprint(fingerprint)
              : null,
        ),
        theme: app.effectiveOctopusTheme(),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payload', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Prefilled text (presets 1-4)',
                helperText:
                    'Min 10 / max 5000 characters. Shorten it below 10 to see '
                    'the payload rejected before the editor opens. Preset 5 '
                    'sends no text.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 8),
            Text(
              'The call-to-action rides along invisibly: it is not shown in the '
              'editor, only on the published post. Emptying either field makes '
              'presets 2 & 4 report a CtaLabelEmpty / CtaUrlEmpty rejection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              // Keyed on the effective value so a default seeded once the
              // groups stream loads is reflected in the displayed selection.
              key: ValueKey<String>('group-dd-${effectiveSelected ?? 'none'}'),
              initialValue: effectiveSelected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Target group (all presets)',
                helperText:
                    'Defaults to the "General" group (or the first available) '
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
            const SizedBox(height: 16),
            Text('Image (presets 3, 4 & 5)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _imageAsset,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The image-bearing presets attach this bundled asset '
                    '($_imageAsset), so they stay a one-tap action with no '
                    'media picker to drive.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Last payload sent', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
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
          'a payload this app builds — text, an image, a target group and an '
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
            withImage: false,
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
            withImage: false,
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
            withImage: true,
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
            withImage: true,
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
            withImage: true,
          ),
        ),
      ],
    );
  }
}
