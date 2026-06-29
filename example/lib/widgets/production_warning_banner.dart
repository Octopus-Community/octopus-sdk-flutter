import 'package:flutter/material.dart';

import '../octopus_demo_config.dart';

/// A persistent red banner shown whenever the sample may be talking to a
/// production / client-facing Octopus server.
///
/// The published native SDK targets `api.8pus.io` (PROD) and exposes no host
/// setter, so the Flutter sample reaches PROD by default — every action
/// (connect, follow, post) can hit real client communities. The banner is
/// shown on every screen (wired via `MaterialApp.builder`) and is not
/// dismissible, mirroring the Android sample's `ProductionWarningBanner`. A QA
/// build that swaps in a demo/dev native SDK suppresses it with
/// `--dart-define=OCTOPUS_API_HOST=<non-prod host>`.
class ProductionWarningBanner extends StatelessWidget {
  const ProductionWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!octopusIsProdServer) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // The banner only renders on prod (see the guard above), so the host is
    // always the published SDK's production endpoint.
    const hostLabel = 'api.8pus.io';

    return Semantics(
      identifier: 'env-warning-banner',
      container: true,
      child: Material(
        color: scheme.errorContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRODUCTION SERVER — $hostLabel',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onErrorContainer,
                            ),
                      ),
                      Text(
                        'Client communities may be reachable. '
                        'DO NOT publish test content.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onErrorContainer.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
