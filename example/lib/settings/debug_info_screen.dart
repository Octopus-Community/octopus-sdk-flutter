import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../design.dart';
import '../octopus_demo_config.dart';
import '../debug/debug_log.dart';
import '../feature_toggles.dart';
import 'sdk_summary.dart';

/// Developer tools → Debug info: the build and session facts a bug report
/// needs, copyable in one gesture.
///
/// Never a secret: the API key itself is not shown here (only which *source*
/// it came from), and the host is the resolved one, which on a public build is
/// the SDK's own production default.
class DebugInfoScreen extends StatelessWidget {
  const DebugInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config;

    final rawRows = <(String, String)>[
      ('Sample version', app.sampleVersionLabel ?? '—'),
      ('Server environment', config?.serverLabel ?? '—'),
      ('Host', config?.hostLabel ?? '—'),
      ('Community', config?.communityLabel ?? '—'),
      ('API key source', config?.apiKeyLabel ?? '—'),
      ('SSO user', app.effectiveUserId),
      ('SSO signer', hasInjectedSsoSecret ? 'injected' : 'pre-baked token'),
      ('SDK version', 'Not exposed by the Flutter plugin'),
      ('Status', sdkStatusLabel(app)),
      ('Network', 'Not exposed by the Flutter plugin'),
      ('Initialized', app.initialized.toString()),
      ('Auth mode', 'SSO'),
      ('Init error', app.initError ?? 'none'),
      ('Connection', sdkConnectionLabel(app)),
      (
        'Entitlements',
        app.currentEntitlements.isEmpty
            ? 'none'
            : (app.currentEntitlements.toList()..sort()).join(', '),
      ),
      ('Theme', app.activeThemeLabel),
      ('Language', app.localeLabel),
      // A bug report that omits these is a bug report twice: they change what
      // the sample does, and they are the two facts nothing else on this screen
      // records. Copied along with the rest by the Copy action above.
      ('Feature toggles', app.featureToggles.summaryLine),
      ('Profile taps', app.unifiedProfileWired ? 'host' : 'SDK'),
      ('exposeClientUserId', app.exposeClientUserIdSummary),
      ('Host callbacks', app.hostCallbacksSummary),
      for (final (name, wired) in app.hostCallbacks)
        (name, wired ? 'Wired' : 'Not wired'),
      ('Unread notifications', app.notSeenCount?.toString() ?? '—'),
      (
        'Community access',
        app.hasAccess == null ? '—' : (app.hasAccess! ? 'Granted' : 'Denied'),
      ),
    ];

    final key = config?.effectiveApiKey ?? '';
    final rows = rawRows
        .map(
          (row) => (
            row.$1,
            redactDebugText(
              key.isEmpty ? row.$2 : row.$2.replaceAll(key, '[redacted]'),
            ),
          ),
        )
        .toList();

    return SampleScaffold(
      appBar: SampleTopAppBar(
        title: 'Debug info',
        actions: [
          Semantics(
            identifier: 'debug-info-copy-button',
            button: true,
            child: TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: rows.map((r) => '${r.$1}: ${r.$2}').join('\n'),
                  ),
                );
                if (context.mounted) {
                  showSampleSnackBar(context, 'Debug info copied');
                }
              },
              child: const Text('Copy'),
            ),
          ),
        ],
      ),
      // A pushed route: nothing above it consumes the bottom system inset the
      // way the app shell's own `SafeArea` does for the tabs. Without this the
      // list scrolls under Android's gesture handle, which crosses whatever
      // label rests there (#359, same defect as Account in #355).
      body: SafeArea(
        child: Semantics(
          identifier: 'debug-info-screen',
          child: ListView(
            padding: const EdgeInsets.all(SampleSpacing.space4),
            children: [
              SampleSection(
                title: 'SDK',
                child: Column(
                  children: [
                    for (final (label, value) in rows.where(
                      (row) => [
                        'SDK version',
                        'Status',
                        'Network',
                        'Initialized',
                        'Auth mode',
                        'Init error',
                        'Connection',
                        'Unread notifications',
                        'Community access',
                      ].contains(row.$1),
                    ))
                      SampleKeyValue(label, value),
                  ],
                ),
              ),
              const SizedBox(height: SampleSpacing.space4),
              SampleSection(
                title: 'Feature toggles',
                child: Column(
                  children: [
                    for (final toggle in FeatureToggle.values)
                      SampleKeyValue(
                        toggle.label,
                        toggle.readOnlyValueLine(app.featureToggles[toggle]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SampleSpacing.space4),
              const ConfigurationSummary(),
              const SizedBox(height: SampleSpacing.space4),
              SampleSection(
                title: 'Host app integration',
                child: Column(
                  children: [
                    SampleKeyValue(
                      'Callbacks',
                      '${app.wiredHostCallbackCount}/5 wired',
                    ),
                    for (final (name, wired) in app.hostCallbacks)
                      SampleKeyValue(name, wired ? 'Wired' : 'Not wired'),
                    SampleKeyValue('Links', app.hostUrlHandling.label),
                  ],
                ),
              ),
              const SizedBox(height: SampleSpacing.space4),
              SampleSection(
                title: 'Build',
                child: Column(
                  children: [
                    SampleKeyValue(
                      'Sample version',
                      app.sampleVersionLabel ?? '—',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
