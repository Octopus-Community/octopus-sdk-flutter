import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import '../octopus_demo_config.dart';
import 'api_key_registry.dart';
import 'user_id_registry.dart';

/// How the Config screen was reached — it is a single screen with two entries.
enum ConfigEntry {
  /// First launch / after Reset data: mounted as the app's `home`, commits
  /// with **Start SDK** and hands over to the shell.
  onboarding,

  /// Settings → Server & community: pushed on top of the shell, commits with
  /// **Apply** and pops back.
  revisit,
}

/// The sample's one configuration screen, reached from two places
/// ([ConfigEntry]).
///
/// Five sections, in this order: Community, Server environment,
/// Authentication (SSO), Theme, Host callbacks (flat list of all 7 rows, none
/// buried behind a nested "Advanced" expander). Nothing is applied until the
/// anchored bottom button is pressed — the screen is a pure form, so backing
/// out of a revisit changes nothing.
///
/// **API key picking.** When the build carries the named demo-key set
/// (private `--dart-define` launcher — see `api_key_registry.dart`), the
/// screen lists them as a single-choice radio picker with one "Custom…"
/// fallback entry for pasting an arbitrary key. On keyless / public builds
/// the list is empty, and the screen falls back to the original Demo / Custom
/// segmented selector (the generic `OCTOPUS_API_KEY` define).
class ConfigScreen extends StatefulWidget {
  /// Choices restored from the persisted config when bootstrap could not
  /// auto-start it (see [AppState.restoredConfig]), or the live config when
  /// revisiting — everything except the API key, which is never persisted.
  /// `null` on a true first launch and after Settings → Reset data.
  final DemoConfig? initialConfig;

  final ConfigEntry entry;

  const ConfigScreen({
    super.key,
    this.initialConfig,
    this.entry = ConfigEntry.onboarding,
  });

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
  late bool _octopusNavyTheme;

  /// Runtime server environment. Defaults to [ServerEnv.demo] so a fresh
  /// install can never land on production by omission.
  late ServerEnv _serverEnv;

  final _customKeyController = TextEditingController();
  late final TextEditingController _customHostController;

  /// Free-text User ID controller — seeded with the restored user id when
  /// there is one, else the build-time [octopusUserId] (or the first picker
  /// slot, which is always the seed). The quick-pick chips below the field
  /// overwrite this controller's text rather than maintaining a separate
  /// selection model — one source of truth, simpler UX.
  late final TextEditingController _userIdController;

  /// Local edit of the host-callback toggles; committed with the rest of the
  /// form. `null` until touched — the live value then shows through.
  bool? _profileWired;
  bool? _onNavigateToContentWired;
  bool? _onAuthenticationRequiredWired;
  bool? _onPushNotificationTappedWired;
  bool? _onUnreadCountChangedWired;
  bool? _onEventWired;
  bool? _onErrorWired;

  bool _starting = false;

  bool get _hasNamedKeys => injectedApiKeys.isNotEmpty;

  bool get _isRevisit => widget.entry == ConfigEntry.revisit;

  @override
  void initState() {
    super.initState();
    // Everything the persisted config still carries is restored here; the API
    // key is not, by design (see [DemoConfig.toJson]), so the user re-enters
    // that one field and nothing else.
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
    _octopusNavyTheme = restored?.octopusNavyTheme ?? true;
    _serverEnv = restored?.serverEnv ?? ServerEnv.demo;
    _customHostController = TextEditingController(
      text: restored?.customHost ?? '',
    );
    _userIdController = TextEditingController(
      text:
          restored?.userId ??
          (pickerUserIds.isNotEmpty ? pickerUserIds.first : octopusUserId),
    );
  }

  @override
  void dispose() {
    _customKeyController.dispose();
    _customHostController.dispose();
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

  DemoConfig get _draft => DemoConfig(
    apiKeySource: _apiKeySource,
    customApiKey: _customKeyController.text.trim(),
    selectedInjectedKey: _apiKeySource == ApiKeySource.demo
        ? _selectedKey
        : null,
    userId: _effectiveUserId,
    theme: _theme,
    serverEnv: _serverEnv,
    customHost: _customHostController.text.trim(),
    octopusNavyTheme: _octopusNavyTheme,
  );

  Future<void> _commit() async {
    setState(() => _starting = true);
    final app = AppScope.of(context);
    final wired = _profileWired;
    if (wired != null) app.setUnifiedProfileWired(wired);
    if (_onNavigateToContentWired case final v?) {
      app.setOnNavigateToContentWired(v);
    }
    if (_onAuthenticationRequiredWired case final v?) {
      app.setOnAuthenticationRequiredWired(v);
    }
    if (_onPushNotificationTappedWired case final v?) {
      app.setOnPushNotificationTappedWired(v);
    }
    if (_onUnreadCountChangedWired case final v?) {
      app.setOnUnreadCountChangedWired(v);
    }
    if (_onEventWired case final v?) app.setOnEventWired(v);
    if (_onErrorWired case final v?) app.setOnErrorWired(v);
    await app.start(_draft);
    if (!mounted) return;
    setState(() => _starting = false);
    // Onboarding: the root rebuilds to the main shell once config is set,
    // nothing to pop. Revisit: hand the user back where they came from.
    if (_isRevisit) Navigator.of(context).maybePop();
  }

  /// Single-choice picker over the injected named keys + a Custom fallback.
  Widget _buildKeyPicker(BuildContext context) {
    return Semantics(
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
        Semantics(
          identifier: 'config-userId-input',
          container: true,
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
    final theme = Theme.of(context);
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
    final customHostMissing =
        _serverEnv == ServerEnv.custom &&
        _customHostController.text.trim().isEmpty;
    final draft = _draft;
    final wired =
        _profileWired ??
        AppScope.maybeOf(context)?.unifiedProfileWired ??
        false;

    return Semantics(
      identifier: 'config-screen',
      child: Scaffold(
        appBar: AppBar(
          title: SampleAppBarTitle(
            _isRevisit ? 'Server & community' : 'Configuration',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(
              _isRevisit
                  ? 'Change the setup, then Apply — the SDK restarts with it.'
                  : 'Configure the SDK, then start it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // ── 1. Community ────────────────────────────────────────────
            SampleSection(
              title: 'Community',
              identifier: 'config-section-community',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasNamedKeys)
                    _buildKeyPicker(context)
                  else
                    _buildLegacySourceSelect(context),
                  if (_apiKeySource == ApiKeySource.custom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customKeyController,
                      // Drives `customKeyMissing` (commit button + hint below)
                      // as the user types.
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Custom API key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (customKeyMissing) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Paste an API key to start. It is kept for this '
                        'session only — never written to device storage, so '
                        'it has to be re-entered on the next launch.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                  if (demoKeyMissing) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No demo key injected. Pass '
                      '--dart-define=OCTOPUS_API_KEY=… to initialize the SDK; '
                      'otherwise Home will show an init error.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Server environment ───────────────────────────────────
            SampleSection(
              title: 'Server environment',
              identifier: 'config-section-server',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConfigSelect<ServerEnv>(
                    testId: 'config-serverEnv-select',
                    selected: _serverEnv,
                    segments: [
                      for (final env in ServerEnv.values) (env, env.label),
                    ],
                    onChanged: (v) => setState(() => _serverEnv = v),
                  ),
                  if (_serverEnv == ServerEnv.custom) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      identifier: 'config-customHost-input',
                      container: true,
                      child: TextField(
                        controller: _customHostController,
                        onChanged: (_) => setState(() {}),
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          hintText: 'api.example.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SampleKeyValue('Host', draft.hostLabel, mono: true),
                  const SizedBox(height: 6),
                  Text(switch (_serverEnv) {
                    ServerEnv.demo =>
                      hasInjectedDemoHost
                          ? 'The demo backend injected into this build '
                                '(--dart-define=OCTOPUS_API_HOST).'
                          : 'This build injected no demo host, so Demo '
                                'falls back to the SDK default — which is '
                                'production.',
                    ServerEnv.prod =>
                      'No host is passed to the SDK: it uses its built-in '
                          'production server, where every action hits real '
                          'communities.',
                    ServerEnv.custom =>
                      'Point the SDK at any reachable backend — a feature '
                          'environment, a local relay.',
                  }, style: theme.textTheme.bodySmall),
                  if (customHostMissing) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Type a host to apply, or switch back to Demo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Authentication (SSO) ─────────────────────────────────
            SampleSection(
              title: 'Authentication (SSO)',
              identifier: 'config-section-auth',
              child: _buildUserIdPicker(context),
            ),
            const SizedBox(height: 16),

            // ── 4. Theme ────────────────────────────────────────────────
            SampleSection(
              title: 'Theme',
              identifier: 'config-section-theme',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  _ConfigSelect<AppThemeChoice>(
                    testId: 'config-theme-select',
                    selected: _theme,
                    segments: const [
                      (AppThemeChoice.system, 'System'),
                      (AppThemeChoice.light, 'Light'),
                      (AppThemeChoice.dark, 'Dark'),
                    ],
                    onChanged: (v) => setState(() => _theme = v),
                  ),
                  const SizedBox(height: 12),
                  // Spec 01: "Theme preset" / "Octopus navy" | "SDK default".
                  // The underlying OctopusTheme preset ([brandOctopusTheme])
                  // is repainted navy to match — see the doc comment on
                  // `_sdkPrimaryMainLight` in branding.dart. Sample-only: the
                  // "SDK default" preset (an unset OctopusTheme) is untouched.
                  Text('Theme preset', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  _ConfigSelect<bool>(
                    testId: 'config-themePreset-select',
                    selected: _octopusNavyTheme,
                    segments: const [
                      (true, 'Octopus navy'),
                      (false, 'SDK default'),
                    ],
                    onChanged: (v) => setState(() => _octopusNavyTheme = v),
                    helperText:
                        'Which OctopusTheme the embedded community starts on. '
                        'Theme scenarios can still override it live.',
                  ),
                  const SizedBox(height: 12),
                  Text('Language', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  // Applied immediately, not batched with the rest of the
                  // form: a locale override has no server round-trip and no
                  // reason to wait for Apply/Start SDK. `maybeOf`, like the
                  // rest of this screen must tolerate: the Config screen also
                  // renders standalone in its widget test, outside the app
                  // shell that normally provides AppScope. Confirmed with
                  // grammar D (spec 08): a reversible, already-applied
                  // change gets a snackbar with Undo, never a silent no-op.
                  _ConfigSelect<LocaleChoice>(
                    testId: 'config-language-select',
                    selected:
                        AppScope.maybeOf(context)?.localeChoice ??
                        LocaleChoice.system,
                    segments: const [
                      (LocaleChoice.system, 'System'),
                      (LocaleChoice.en, 'en'),
                      (LocaleChoice.fr, 'fr'),
                    ],
                    onChanged: (v) {
                      final app = AppScope.maybeOf(context);
                      if (app == null) return;
                      final previous = app.localeChoice;
                      if (previous == v) return;
                      app.setLocale(v);
                      showSampleSnackBar(
                        context,
                        'Language applied',
                        undoLabel: 'Undo',
                        onUndo: () => app.setLocale(previous),
                      );
                    },
                    helperText:
                        "Overrides the locale the SDK renders its own "
                        'screens in. The sample is English-only by design.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 5. Host callbacks — flat list, all 7 rows, not collapsed ──
            SampleSection(
              title: 'Host callbacks',
              identifier: 'config-section-hostCallbacks',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What the SDK calls back into the host app. On = the '
                    "sample provides the implementation; off = the callback "
                    "isn't passed to the SDK, so you see its default "
                    'behaviour.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    identifier: 'qa-toggle-unifiedProfileWired',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: wired,
                      title: const Text('onNavigateToProfile'),
                      subtitle: const Text(
                        "Opens the host's profile screen. Requires the "
                        'community to expose client user ids.',
                      ),
                      onChanged: (v) => setState(() => _profileWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onNavigateToContent',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onNavigateToContentWired ??
                          AppScope.maybeOf(context)?.onNavigateToContentWired ??
                          true,
                      title: const Text('onNavigateToContent'),
                      subtitle: const Text(
                        "Deep-links to a piece of the host's own content. "
                        'Not wired in the Flutter binding yet.',
                      ),
                      onChanged: (v) =>
                          setState(() => _onNavigateToContentWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onAuthenticationRequired',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onAuthenticationRequiredWired ??
                          AppScope.maybeOf(
                            context,
                          )?.onAuthenticationRequiredWired ??
                          true,
                      title: const Text('onAuthenticationRequired'),
                      subtitle: const Text(
                        'The host must sign the user in. Not wired in the '
                        'Flutter binding yet.',
                      ),
                      onChanged: (v) =>
                          setState(() => _onAuthenticationRequiredWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onPushNotificationTapped',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onPushNotificationTappedWired ??
                          AppScope.maybeOf(
                            context,
                          )?.onPushNotificationTappedWired ??
                          true,
                      title: const Text('onPushNotificationTapped'),
                      subtitle: const Text(
                        'An Octopus push payload was received by the host. '
                        'Not wired in the Flutter binding yet.',
                      ),
                      onChanged: (v) =>
                          setState(() => _onPushNotificationTappedWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onUnreadCountChanged',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onUnreadCountChangedWired ??
                          AppScope.maybeOf(
                            context,
                          )?.onUnreadCountChangedWired ??
                          true,
                      title: const Text('onUnreadCountChanged'),
                      subtitle: const Text(
                        "Feeds the host's own badge. Not wired in the "
                        'Flutter binding yet.',
                      ),
                      onChanged: (v) =>
                          setState(() => _onUnreadCountChangedWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onEvent',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onEventWired ??
                          AppScope.maybeOf(context)?.onEventWired ??
                          false,
                      title: const Text('onEvent'),
                      subtitle: const Text(
                        'Analytics: SDK events forwarded to the host. Not '
                        'wired in the Flutter binding yet.',
                      ),
                      onChanged: (v) => setState(() => _onEventWired = v),
                    ),
                  ),
                  Semantics(
                    identifier: 'qa-toggle-onError',
                    container: true,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _onErrorWired ??
                          AppScope.maybeOf(context)?.onErrorWired ??
                          false,
                      title: const Text('onError'),
                      subtitle: const Text(
                        'SDK errors surfaced to the host. Not wired in the '
                        'Flutter binding yet.',
                      ),
                      onChanged: (v) => setState(() => _onErrorWired = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: MergeSemantics(
            child: Semantics(
              identifier: 'config-start-button',
              button: true,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed:
                      (_starting || customKeyMissing || customHostMissing)
                      ? null
                      : _commit,
                  child: Text(
                    _starting
                        ? (_isRevisit ? 'Applying…' : 'Starting…')
                        : (_isRevisit ? 'Apply' : 'Start SDK'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [SegmentedButton] carrying a verbatim catalog [testId], with an optional
/// caption underneath.
class _ConfigSelect<T> extends StatelessWidget {
  final String testId;
  final T selected;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;
  final String? helperText;

  const _ConfigSelect({
    required this.testId,
    required this.selected,
    required this.segments,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onSelectionChanged: (s) => onChanged(s.first),
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
