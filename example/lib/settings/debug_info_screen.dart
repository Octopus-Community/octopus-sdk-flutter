import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../design.dart';
import '../octopus_demo_config.dart';

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

    final rows = <(String, String)>[
      ('Sample version', app.sampleVersionLabel ?? '—'),
      ('Server environment', config?.serverEnv.label ?? '—'),
      ('Host', config?.hostLabel ?? '—'),
      ('API key source', config?.apiKeyLabel ?? '—'),
      ('SSO user', app.effectiveUserId),
      ('SSO signer', hasInjectedSsoSecret ? 'injected' : 'pre-baked token'),
      ('SDK initialized', app.initialized ? 'yes' : 'no'),
      ('Init error', app.initError ?? 'none'),
      ('Connection', app.userConnected ? 'connected' : 'guest'),
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
      ('Unseen notifications', app.notSeenCount?.toString() ?? '—'),
      ('Has access', app.hasAccess?.toString() ?? '—'),
    ];

    return SampleScaffold(
      appBar: AppBar(
        title: const SampleAppBarTitle('Debug info'),
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
            padding: const EdgeInsets.all(16),
            children: [
              SampleSection(
                title: 'Build & session',
                child: Column(
                  children: [
                    for (final (label, value) in rows)
                      SampleKeyValue(label, value, mono: true),
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
