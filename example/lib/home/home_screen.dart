import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/key_value_card.dart';

/// Home tab — a read-only dashboard of SDK + session state.
///
/// Reads only; every state-changing action lives in a scenario or Settings,
/// so the dashboard never mutates anything on its own.
/// The presentation modes (Modal / Fullscreen / Sheet) used to be launchable
/// from cards here; they now live exclusively in the Scenarios tab so each
/// integration shape is demoed in exactly one place.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config;

    String status;
    if (app.initError != null) {
      status = 'Initialization error';
    } else if (app.initialized) {
      status = 'Initialized';
    } else {
      status = 'Initializing…';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (app.initError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('SDK init failed: ${app.initError}')),
                ],
              ),
            ),
          ),
        if (app.initError != null) const SizedBox(height: 12),
        KeyValueCard(
          title: 'SDK',
          rows: [
            ('Status', status),
            // Shows the picked named-key label when a build-time key set is
            // injected, or "Demo (--dart-define)" / "Custom" / "Demo (no key
            // injected)" for the other sources — see [DemoConfig.apiKeyLabel].
            ('API key source', config?.apiKeyLabel ?? '—'),
            ('Server', config?.serverEnv == ServerEnv.prod ? 'prod' : 'custom'),
          ],
        ),
        const SizedBox(height: 12),
        KeyValueCard(
          title: 'User',
          rows: [
            ('Connection', app.userConnected ? 'connected' : 'anonymous'),
            ('User id', app.effectiveUserId),
          ],
        ),
        const SizedBox(height: 12),
        KeyValueCard(
          title: 'Community',
          rows: [
            ('Unseen notifications', app.notSeenCount?.toString() ?? '—'),
            ('Has access', app.hasAccess?.toString() ?? '—'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Use the Scenarios tab to exercise each SDK capability — including '
          'the Modal / Fullscreen / Sheet presentation modes — and the '
          'Community tab for the embedded experience.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
