import 'package:flutter/material.dart';

import '../octopus_demo_config.dart';

/// A persistent red banner shown on **internal builds only**
/// (`--dart-define=OCTOPUS_INTERNAL=true`) whenever the sample talks to the
/// production / client-facing Octopus server — which is the fail-safe default
/// (see [octopusApiHost]) whenever no `--dart-define=OCTOPUS_API_HOST=<host>`
/// is injected. The internal gate ([octopusShowsServerWarning], decided
/// 2026-08-26) exists because this sample is mirrored publicly and a client's
/// nominal configuration IS the production server (or their own host) with
/// their own key — the banner is an internal "don't post test content here"
/// safety net, not part of the product surface, and the opaque API key gives
/// no client-side way to tell a sandbox key from a production one. When shown,
/// the banner covers every screen (wired via `MaterialApp.builder`, which
/// keeps it above every subsequently-pushed route, dialog, or modal sheet —
/// covering D7.3's "visible everywhere, including modals" requirement without
/// per-screen wiring) and is not dismissible, mirroring the Android sample's
/// `ProductionWarningBanner`.
class ProductionWarningBanner extends StatelessWidget {
  /// [show] overrides the compile-time decision — tests only (a default
  /// `flutter test` run injects no dart-defines, so the real
  /// [octopusShowsServerWarning] can never be true there). `null` (production
  /// path) defers to it.
  const ProductionWarningBanner({super.key, this.show});

  final bool? show;

  @override
  Widget build(BuildContext context) {
    if (!(show ?? octopusShowsServerWarning)) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // The banner only renders on the fail-safe (no host injected) path, so
    // the host is always the published SDK's production endpoint.
    const hostLabel = 'api.8pus.io';

    return Semantics(
      identifier: 'env-warning-banner',
      // `label` gives the banner one addressable node in the native
      // accessibility tree (`identifier` alone is Flutter-internal — widget
      // test lookups only, never sent to the platform). Historical note: an
      // on-device QA pass (lot 3, D7.3/D4) found NO semantics node for the
      // banner at all — not even its `Text` children — despite it rendering
      // correctly. That was never a problem with this widget's flags: the
      // banner used to be painted BEFORE the Navigator, whose route
      // machinery blocks the semantics of everything painted before it. The
      // fix lives in `octopusDemoAppBuilder` (see `main.dart`), which paints
      // the banner after the Navigator; `production_warning_banner_test.dart`
      // locks the semantics node's presence.
      label: 'Production server warning',
      // Without this, the container merges its `Text` descendants into its
      // own node: the label becomes the concatenation of all three strings,
      // so nothing can address the banner by its stable label above.
      explicitChildNodes: true,
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
