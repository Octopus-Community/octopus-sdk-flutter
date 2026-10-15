import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../design.dart';
import '../feature_toggles.dart';
import '../octopus_demo_config.dart';
import '../settings/account_screen.dart';
import '../settings/host_integration_screen.dart';
import '../settings/settings_choices.dart';
import 'api_key_registry.dart';
import 'user_id_registry.dart';

/// A section of the Config screen an in-app link can land on.
///
/// The enum name is the anchor as written in a link (`community`, `server`,
/// `auth`, `theme`, `integration`); [identifier] is the section's catalog
/// test id, unchanged. `integration` is the *Host callbacks* section — the
/// callbacks are how the host integrates with the SDK, and the anchor keeps
/// the name the other samples link with.
enum ConfigSection {
  server('config-section-server', 'Server environment'),
  community('config-section-community', 'Community'),
  auth('config-section-auth', 'Connect your users (SSO)'),
  theme('config-section-theme', 'Theme'),
  integration('config-section-hostCallbacks', 'Host callbacks');

  const ConfigSection(this.identifier, this.title);

  /// The section's `Semantics.identifier`, verbatim from the QA catalog.
  final String identifier;

  /// The section header as rendered.
  final String title;

  /// The section an anchor string names, or `null` for an unknown anchor —
  /// the screen then opens at the top, as it would with no anchor at all.
  static ConfigSection? fromAnchor(String? anchor) =>
      anchor == null ? null : values.asNameMap()[anchor];
}

/// Pushes Configuration, scrolled to [anchor] when given.
///
/// The one way an in-app link opens Config, so every link lands the same way:
/// seeded with the live config, committed with Apply, popped back afterwards.
Future<void> openConfigScreen(BuildContext context, {ConfigSection? anchor}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ConfigScreen(
        initialConfig: AppScope.maybeOf(context)?.configurationChoices,
        anchor: anchor,
      ),
    ),
  );
}

/// A staged configuration form pushed above the permanent sample shell.
/// Sections start collapsed except for a requested anchor.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({
    super.key,
    this.initialConfig,
    this.anchor,
    this.injectedKeys,
  });
  final DemoConfig? initialConfig;
  final ConfigSection? anchor;

  /// Synthetic build keys for widget tests; otherwise uses the build registry.
  @visibleForTesting
  final List<InjectedApiKey>? injectedKeys;
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late ApiKeySource _apiKeySource;
  late InjectedApiKey? _selectedKey;
  late AppThemeChoice _theme;
  late bool _navy;
  late ServerEnv _server;
  final _customKey = TextEditingController();
  late final TextEditingController _userId;
  late final TextEditingController _host;
  late final TextEditingController _port;
  bool _applying = false;
  final _keys = {
    for (final section in ConfigSection.values) section: GlobalKey(),
  };
  bool get _restarting => AppScope.maybeOf(context)?.initialized ?? false;
  List<InjectedApiKey> get _injectedKeys =>
      widget.injectedKeys ?? injectedApiKeys;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _apiKeySource = config?.apiKeySource ?? ApiKeySource.demo;
    _selectedKey = config?.selectedInjectedKey;
    _customKey.text = config?.customApiKey ?? '';
    _userId = TextEditingController(
      text: config?.userId ?? pickerUserIds.first,
    );
    _theme = config?.theme ?? AppThemeChoice.system;
    _navy = config?.octopusNavyTheme ?? true;
    // Demo resolves to the build-injected host. No feature-environment picker.
    _server = config?.serverEnv ?? ServerEnv.demo;
    _host = TextEditingController(
      text: (config?.customHost.trim().isNotEmpty ?? false)
          ? config!.customHost.trim()
          : _buildHost.trim().isNotEmpty
          ? _buildHost.trim()
          : productionHost,
    );
    _port = TextEditingController(text: '${config?.customPort ?? 443}');
    if (widget.anchor case final anchor?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _keys[anchor]?.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  String get _buildHost =>
      context
          .getInheritedWidgetOfExactType<AppScope>()
          ?.notifier
          ?.configurationChoices
          .buildHost ??
      widget.initialConfig?.buildHost ??
      octopusDemoApiHost;

  @override
  void dispose() {
    _customKey.dispose();
    _userId.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  DemoConfig get _draft => DemoConfig(
    apiKeySource: _apiKeySource,
    customApiKey: _customKey.text.trim(),
    selectedInjectedKey: _apiKeySource == ApiKeySource.demo
        ? _selectedKey
        : null,
    userId: _userId.text.trim().isEmpty ? octopusUserId : _userId.text.trim(),
    theme: _theme,
    octopusNavyTheme: _navy,
    serverEnv: _server,
    customHost: _server == ServerEnv.custom ? _host.text.trim() : '',
    customPort: int.tryParse(_port.text) ?? 443,
    buildHost: _buildHost,
    featureToggles:
        widget.initialConfig?.featureToggles ??
        AppScope.maybeOf(context)?.featureToggles ??
        FeatureToggles.defaults,
  );

  String? get _serverError {
    if (_server != ServerEnv.custom) return null;
    final port = int.tryParse(_port.text);
    if (port == null || port < 1 || port > 65535) {
      return 'Use a port from 1 to 65535.';
    }
    try {
      ApiServer(host: _host.text.trim(), port: port);
      return null;
    } on ArgumentError {
      return 'Enter a hostname without a scheme, path or port.';
    }
  }

  Future<void> _commit() async {
    setState(() => _applying = true);
    final app = AppScope.of(context);
    await app.start(_draft);
    // A configuration preset replaces the temporary Theme scenario preset.
    app.setThemePreset(_navy);
    if (!mounted) return;
    setState(() => _applying = false);
    if (app.initError != null) {
      showSampleSnackBar(
        context,
        'Could not apply configuration. Check Debug info.',
      );
      return;
    }
    if (Navigator.of(context).canPop() &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  Widget _section(ConfigSection section, Widget child) => KeyedSubtree(
    key: _keys[section],
    child: Semantics(
      identifier: section.identifier,
      child: Column(
        children: [
          const Divider(height: 1),
          ExpansionTile(
            key: ValueKey('config-${section.name}'),
            tilePadding: EdgeInsets.zero,
            minTileHeight: 48,
            title: Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            initiallyExpanded: widget.anchor == section,
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [child],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Semantics(
      identifier: 'config-screen',
      child: SampleScaffold(
        appBar: const SampleTopAppBar(
          title: 'Configuration',
          size: SampleTopBarSize.medium,
          showPlatformBadge: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _restarting
                      ? 'Change the setup, then Apply — the SDK restarts with it.'
                      : 'Change the setup, then Apply.',
                ),
                if (_restarting) ...[
                  const Text(
                    'The restart drops the connected SSO user — reconnect from Settings › Account.',
                  ),
                  SampleLink(
                    label: 'Open Settings › Account',
                    identifier: 'config-account-link',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountScreen(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: SampleSpacing.space4),
                _section(
                  ConfigSection.server,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SettingsChoices<ServerEnv>(
                        identifier: 'config-serverEnv-select',
                        selected: _server,
                        options: const [
                          (ServerEnv.demo, 'Demo'),
                          (ServerEnv.prod, 'Prod'),
                          (ServerEnv.custom, 'Custom'),
                        ],
                        onChanged: (value) => setState(() => _server = value),
                      ),
                      if (_server == ServerEnv.custom) ...[
                        TextField(
                          controller: _host,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: SampleSpacing.space2),
                        TextField(
                          controller: _port,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_serverError case final error?)
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                      SampleKeyValue('Host', draft.hostLabel, mono: true),
                      const Text(
                        'Demo uses the server injected into this build. Prod uses the SDK default. Feature environments are not available here.',
                      ),
                    ],
                  ),
                ),
                _section(
                  ConfigSection.community,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_injectedKeys.isNotEmpty)
                        SettingsChoices<String>(
                          identifier: 'config-apiKeySource-select',
                          selected: _apiKeySource == ApiKeySource.custom
                              ? 'custom'
                              : (_selectedKey?.id ?? ''),
                          options: [
                            ('', 'Demo'),
                            for (final key in _injectedKeys)
                              (key.id, key.label),
                            ('custom', 'Custom…'),
                          ],
                          onChanged: (value) => setState(() {
                            _apiKeySource = value == 'custom'
                                ? ApiKeySource.custom
                                : ApiKeySource.demo;
                            _selectedKey = value.isEmpty || value == 'custom'
                                ? null
                                : _injectedKeys.firstWhere(
                                    (key) => key.id == value,
                                  );
                          }),
                        )
                      else
                        SettingsChoices<ApiKeySource>(
                          identifier: 'config-apiKeySource-select',
                          selected: _apiKeySource,
                          options: const [
                            (ApiKeySource.demo, 'Demo'),
                            (ApiKeySource.custom, 'Custom'),
                          ],
                          onChanged: (value) =>
                              setState(() => _apiKeySource = value),
                        ),
                      if (_apiKeySource == ApiKeySource.custom) ...[
                        TextField(
                          controller: _customKey,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Custom API key',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const Text(
                          'Demo keys only. Kept for this session, never saved.',
                        ),
                      ],
                      if (_apiKeySource == ApiKeySource.demo &&
                          !hasInjectedApiKey &&
                          _selectedKey == null)
                        const Text(
                          'No demo key injected. The sample remains navigable; the SDK cannot initialize.',
                        ),
                      SampleKeyValue(
                        'API key',
                        draft.effectiveApiKey.isEmpty
                            ? 'Not configured'
                            : '••••••••',
                      ),
                    ],
                  ),
                ),
                _section(
                  ConfigSection.auth,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        identifier: 'config-userId-input',
                        container: true,
                        child: TextField(
                          controller: _userId,
                          decoration: const InputDecoration(
                            labelText: 'User id (SSO sub)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: SampleSpacing.space2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final id in pickerUserIds)
                            ActionChip(
                              label: Text(id),
                              onPressed: () => setState(() {
                                _userId.text = id;
                                _userId.selection = TextSelection.collapsed(
                                  offset: id.length,
                                );
                              }),
                            ),
                        ],
                      ),
                      const Text(
                        'Used by the sign-in scenario and Account. Apply records the user ID; connect from Account.',
                      ),
                      SampleKeyValue(
                        'Unified Profile',
                        AppScope.maybeOf(context)?.exposeClientUserIdSummary ??
                            'Unknown',
                      ),
                      SampleLink(
                        label: 'Open Unified Profile scenario',
                        identifier: 'config-unified-profile-link',
                        onTap: () {
                          AppScope.maybeOf(
                            context,
                          )?.requestScenariosSection('sso');
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                      ),
                    ],
                  ),
                ),
                _section(
                  ConfigSection.theme,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Appearance'),
                      SettingsChoices<AppThemeChoice>(
                        segmented: true,
                        identifier: 'config-theme-select',
                        selected: _theme,
                        options: [
                          for (final choice in AppThemeChoice.values)
                            (choice, choice.label),
                        ],
                        onChanged: (value) => setState(() => _theme = value),
                      ),
                      const Text('Theme preset'),
                      SettingsChoices<bool>(
                        segmented: true,
                        identifier: 'config-themePreset-select',
                        selected: _navy,
                        options: const [
                          (true, 'Octopus navy'),
                          (false, 'SDK default'),
                        ],
                        onChanged: (value) => setState(() => _navy = value),
                      ),
                    ],
                  ),
                ),
                KeyedSubtree(
                  key: _keys[ConfigSection.integration],
                  child: Semantics(
                    identifier: ConfigSection.integration.identifier,
                    child: SampleNavTile(
                      icon: Icons.code,
                      title: 'Host app integration',
                      subtitle:
                          'Profile, sign-in, links: now in Settings › Developer tools',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HostIntegrationScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SampleActionBar(
          child: Semantics(
            identifier: 'config-start-button',
            button: true,
            child: FilledButton(
              onPressed:
                  _applying ||
                      _serverError != null ||
                      (_apiKeySource == ApiKeySource.custom &&
                          _customKey.text.trim().isEmpty)
                  ? null
                  : _commit,
              child: Text(_applying ? 'Applying…' : 'Apply'),
            ),
          ),
        ),
      ),
    );
  }
}
