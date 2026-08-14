import 'package:flutter/material.dart';

import '../app_state.dart';
import '../octopus_demo_config.dart';
import 'api_key_registry.dart';
import 'user_id_registry.dart';

/// First-launch / reset Config screen.
///
/// Captures the API-key source, theme, and server env, then initialises the
/// SDK on Start. Shown by the root whenever no [DemoConfig] is set; once Start
/// succeeds the root swaps to the main bottom-nav shell.
///
/// **API key picking.** When the build carries the named demo-key set
/// (private `--dart-define` launcher — see `api_key_registry.dart`), the
/// screen lists them as a single-choice radio picker with one "Custom…"
/// fallback entry for pasting an arbitrary key. On keyless / public builds
/// the list is empty, and the screen falls back to the original Demo / Custom
/// segmented selector (the generic `OCTOPUS_API_KEY` define).
class ConfigScreen extends StatefulWidget {
  /// Choices restored from the persisted config when bootstrap could not
  /// auto-start it (see [AppState.restoredConfig]) — everything except the
  /// API key, which is never persisted. `null` on a true first launch and
  /// after Settings → Reset.
  final DemoConfig? initialConfig;

  const ConfigScreen({super.key, this.initialConfig});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late ApiKeySource _apiKeySource;

  /// Selected named key — restored from [ConfigScreen.initialConfig] when
  /// there is one, else the slot matching the generic `OCTOPUS_API_KEY` (the
  /// launcher's primary key), so the picker starts on the key the sample
  /// would have used anyway; first slot otherwise.
  late InjectedApiKey? _selectedKey;

  late AppThemeChoice _theme;
  // The server is fixed at build time (--dart-define=OCTOPUS_API_HOST), so this
  // is final: the Config picker only displays it, it can't be changed. Default
  // to the server the native SDK is actually built against (prod for the
  // published SDK) so the recorded config matches reality.
  final ServerEnv _serverEnv = octopusIsProdServer
      ? ServerEnv.prod
      : ServerEnv.custom;
  final _customKeyController = TextEditingController();

  /// Free-text User ID controller — seeded with the restored user id when
  /// there is one, else the build-time [octopusUserId] (or the first picker
  /// slot, which is always the seed). The quick-pick chips below the field
  /// overwrite this controller's text rather than maintaining a separate
  /// selection model — one source of truth, simpler UX.
  late final TextEditingController _userIdController;

  bool _starting = false;

  bool get _hasNamedKeys => injectedApiKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Everything the persisted config still carries is restored here; the API
    // key is not, by design (see [DemoConfig.toJson]), so the user re-enters
    // that one field and nothing else. `_serverEnv` stays build-derived — it
    // must keep reporting the host the SDK is actually routed to.
    final restored = widget.initialConfig;
    _apiKeySource = restored?.apiKeySource ?? ApiKeySource.demo;
    _selectedKey =
        restored?.selectedInjectedKey ??
        (injectedApiKeys.isEmpty
            ? null
            : injectedApiKeys.firstWhere(
                (k) => k.key == octopusApiKey,
                orElse: () => injectedApiKeys.first,
              ));
    _theme = restored?.theme ?? AppThemeChoice.system;
    _userIdController = TextEditingController(
      text:
          restored?.userId ??
          (pickerUserIds.isNotEmpty ? pickerUserIds.first : octopusUserId),
    );
  }

  @override
  void dispose() {
    _customKeyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  /// The user id Start records on [DemoConfig]: whatever's in the text field
  /// after trim. Empty falls back to the build-time seed so the JWT signer
  /// always gets a non-empty `sub`.
  String get _effectiveUserId {
    final raw = _userIdController.text.trim();
    return raw.isEmpty ? octopusUserId : raw;
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final config = DemoConfig(
      apiKeySource: _apiKeySource,
      customApiKey: _customKeyController.text.trim(),
      selectedInjectedKey: _apiKeySource == ApiKeySource.demo
          ? _selectedKey
          : null,
      userId: _effectiveUserId,
      theme: _theme,
      serverEnv: _serverEnv,
    );
    await AppScope.of(context).start(config);
    // The root rebuilds to the main shell once config is set; nothing else to
    // do here. Guard the setState in case start() resolved after dispose.
    if (mounted) setState(() => _starting = false);
  }

  /// Single-choice picker over the injected named keys + a Custom fallback.
  Widget _buildKeyPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API key', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'config-apiKeySource-select',
          container: true,
          child: Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final key in injectedApiKeys)
                  Semantics(
                    identifier: 'config-apiKey-option-${key.id}',
                    child: RadioListTile<String>(
                      dense: true,
                      title: Text(key.label),
                      value: key.id,
                      // ignore: deprecated_member_use
                      groupValue: _apiKeySource == ApiKeySource.demo
                          ? _selectedKey?.id
                          : null,
                      // ignore: deprecated_member_use
                      onChanged: (_) => setState(() {
                        _apiKeySource = ApiKeySource.demo;
                        _selectedKey = key;
                      }),
                    ),
                  ),
                Semantics(
                  identifier: 'config-apiKey-option-custom',
                  child: RadioListTile<String>(
                    dense: true,
                    title: const Text('Custom…'),
                    subtitle: const Text('Paste any API key'),
                    value: 'custom',
                    // ignore: deprecated_member_use
                    groupValue: _apiKeySource == ApiKeySource.custom
                        ? 'custom'
                        : null,
                    // ignore: deprecated_member_use
                    onChanged: (_) =>
                        setState(() => _apiKeySource = ApiKeySource.custom),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Free-text User ID field with a row of quick-pick chips that fill the
  /// field. Always-visible text input keeps the UX flat — no dropdown, no
  /// modal — so QA can type any `sub` (or tap a shortcut) and get on with
  /// it. The seed (build-time `OCTOPUS_USER_ID`) is always present in
  /// [pickerUserIds] so the default chip row offers the launcher's identity.
  Widget _buildUserIdPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User ID', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'config-userId-input',
          child: TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User id (SSO `sub`)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (pickerUserIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final id in pickerUserIds)
                Semantics(
                  identifier: 'config-userId-quickpick-$id',
                  child: ActionChip(
                    label: Text(id),
                    onPressed: () => setState(() {
                      _userIdController.text = id;
                      _userIdController.selection = TextSelection.collapsed(
                        offset: id.length,
                      );
                    }),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Used by Connection-scenario presets (the JWT `sub`) and the '
          'profile-edit re-connect path. Running two instances of the sample '
          'side-by-side? Pick a different id on each so the BE sees two '
          'distinct users — required for push-notification end-to-end QA.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!hasInjectedSsoSecret && _effectiveUserId != octopusUserId) ...[
          const SizedBox(height: 4),
          Text(
            'Note: this build has no SSO secret injected, so connect uses the '
            'pre-baked OCTOPUS_USER_TOKEN — which is signed for '
            '"$octopusUserId". A different id will fail to connect until a '
            'signer is available.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// Original Demo / Custom segmented selector — keyless / public builds.
  Widget _buildLegacySourceSelect(BuildContext context) {
    return _ConfigSelect<ApiKeySource>(
      testId: 'config-apiKeySource-select',
      label: 'API key source',
      selected: _apiKeySource,
      segments: const [
        (ApiKeySource.demo, 'Demo'),
        (ApiKeySource.custom, 'Custom'),
      ],
      onChanged: (v) => setState(() => _apiKeySource = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demoKeyMissing =
        _apiKeySource == ApiKeySource.demo &&
        !_hasNamedKeys &&
        !hasInjectedApiKey;
    // The common landing state now that a pasted key is never persisted: the
    // user comes back to a restored `custom` config with an empty field.
    // Starting from there would initialise the SDK with no key at all, so the
    // button waits for the paste instead of dropping them on Home with an
    // init error.
    final customKeyMissing =
        _apiKeySource == ApiKeySource.custom &&
        _customKeyController.text.trim().isEmpty;
    return Semantics(
      identifier: 'config-screen',
      child: Scaffold(
        appBar: AppBar(title: const Text('Configuration')),
        body: ListView(
          // ConfigScreen is mounted as `home` in main.dart, outside the
          // SafeArea that MainScreen applies — so nothing else keeps the last
          // child clear of the Android navigation bar, and the Start button
          // ends up half under it once the list is scrolled to the bottom.
          // `viewPadding` rather than `padding`: the latter collapses
          // to 0 while the keyboard is up (custom-key field), which would make
          // the reserved space blink away mid-edit.
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Text(
              'Configure the SDK, then Start.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_hasNamedKeys)
              _buildKeyPicker(context)
            else
              _buildLegacySourceSelect(context),
            if (_apiKeySource == ApiKeySource.custom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customKeyController,
                // Drives `customKeyMissing` (Start button + hint below) as
                // the user types.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Custom API key',
                  border: OutlineInputBorder(),
                ),
              ),
              if (customKeyMissing) ...[
                const SizedBox(height: 8),
                Text(
                  'Paste an API key to start. It is kept for this session '
                  'only — never written to device storage, so it has to be '
                  're-entered on the next launch.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (demoKeyMissing) ...[
              const SizedBox(height: 8),
              Text(
                'No demo key injected. Pass '
                '--dart-define=OCTOPUS_API_KEY=… to initialize the SDK; '
                'otherwise Home will show an init error.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            _buildUserIdPicker(context),
            const SizedBox(height: 16),
            _ConfigSelect<AppThemeChoice>(
              testId: 'config-theme-select',
              label: 'Theme',
              selected: _theme,
              segments: const [
                (AppThemeChoice.system, 'System'),
                (AppThemeChoice.light, 'Light'),
                (AppThemeChoice.dark, 'Dark'),
              ],
              onChanged: (v) => setState(() => _theme = v),
            ),
            const SizedBox(height: 16),
            _ConfigSelect<ServerEnv>(
              testId: 'config-serverEnv-select',
              label: 'Server',
              selected: _serverEnv,
              segments: const [
                (ServerEnv.custom, 'custom'),
                (ServerEnv.prod, 'prod'),
              ],
              // Display-only: the host is fixed at build time by
              // `--dart-define=OCTOPUS_API_HOST` (see [octopusApiHost]) and
              // routed in `AppState.start`, so there is nothing to pick at
              // runtime.
              enabled: false,
              onChanged: (_) {},
              helperText:
                  'Set by the build (--dart-define=OCTOPUS_API_HOST); '
                  'shown for reference.',
            ),
            const SizedBox(height: 32),
            MergeSemantics(
              child: Semantics(
                identifier: 'config-start-button',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_starting || customKeyMissing) ? null : _start,
                    child: Text(_starting ? 'Starting…' : 'Start'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled [SegmentedButton] carrying a verbatim catalog [testId].
///
/// When [enabled] is false the segments are shown but non-interactive (the
/// native disabled styling), so the control can display a build-time value
/// without letting the user pick one that wouldn't take effect. [helperText],
/// when set, is rendered underneath as a small caption.
class _ConfigSelect<T> extends StatelessWidget {
  final String testId;
  final String label;
  final T selected;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final String? helperText;

  const _ConfigSelect({
    required this.testId,
    required this.label,
    required this.selected,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Semantics(
          identifier: testId,
          container: true,
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              segments: [
                for (final (value, text) in segments)
                  ButtonSegment(value: value, label: Text(text)),
              ],
              selected: {selected},
              showSelectedIcon: false,
              // Passing null disables the whole control (the build-time value
              // stays selected but can't be changed).
              onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
