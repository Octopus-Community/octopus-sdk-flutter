/// Home tab — the sample's dashboard: what the SDK is running on, what the
/// session is, and the dock that opens the community three ways.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../community/present_community.dart';
import '../config/config_screen.dart';
import '../design.dart';
import '../update/update_card.dart';

/// Home tab — a read-only dashboard of SDK + session state, plus the anchored
/// dock.
///
/// Everything above the dock reads; nothing here mutates SDK state except the
/// dock (which only *presents* the community) and the update check. Changing
/// the setup goes through Config, reached from the `Edit` control on the
/// current-configuration block.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final config = app.config;

    return Column(
      children: [
        Expanded(
          child: SampleDockFade(
            child: ListView(
              // 16 + the trailing 8dp gap = 24dp clear of the dark dock fade at
              // scroll end, the clearance of the Config and scenario pages.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _SdkCard(app: app),
                const SizedBox(height: 16),
                SampleSection(
                  title: 'Current configuration',
                  identifier: 'home-configuration',
                  // The strong hairline frames it in dark theme; light keeps the
                  // neutral section frame.
                  borderColor: brightness == Brightness.dark
                      ? sampleDarkBorderStrong
                      : null,
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConfigScreen(
                          initialConfig: config,
                          entry: ConfigEntry.revisit,
                        ),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                  child: Column(
                    children: [
                      SampleKeyValue(
                        'Server environment',
                        config?.serverEnv.label ?? '—',
                      ),
                      SampleKeyValue(
                        'Host',
                        config?.hostLabel ?? '—',
                        mono: true,
                      ),
                      SampleKeyValue(
                        'Community',
                        config?.selectedInjectedKey?.label ??
                            (config == null ? '—' : 'Default community'),
                      ),
                      // The source kind — "Demo (--dart-define)", "Named key
                      // (--dart-define)" or "Custom", see
                      // [DemoConfig.apiKeyLabel]. Never the key, nor its label
                      // (that is the Community row above).
                      SampleKeyValue(
                        'API key source',
                        config?.apiKeyLabel ?? '—',
                      ),
                      SampleKeyValue(
                        'SSO user',
                        app.effectiveUserId,
                        mono: true,
                      ),
                      SampleKeyValue(
                        'Entitlements',
                        app.currentEntitlements.isEmpty
                            ? 'None'
                            : (app.currentEntitlements.toList()..sort()).join(
                                ', ',
                              ),
                      ),
                      SampleKeyValue('Theme', app.activeThemeLabel),
                      SampleKeyValue('Language', app.localeLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ConnectionCard(app: app),
                const SizedBox(height: 16),
                SampleSection(
                  title: 'App',
                  identifier: 'home-app',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (app.sampleVersionLabel != null)
                        SampleKeyValue(
                          'Sample version',
                          app.sampleVersionLabel!,
                        ),
                      // Android-only in practice: on iOS the card renders
                      // nothing, because TestFlight prompts for a newer build in
                      // the OS before the app even runs.
                      UpdateCard(checker: app.updateChecker),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // ── Dock ────────────────────────────────────────────────────────
        // Anchored, always reachable: the sample's whole point is opening the
        // community, and it should never take a scroll to get there.
        // No hairline and no band: light cards are borderless, and in dark
        // theme [SampleDockFade] fades the list out above it instead. The
        // transparent side only keeps the dock's 1dp of spacing.
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.transparent)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MergeSemantics(
                  child: Semantics(
                    identifier: 'home-open-community',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => app.requestTab(2),
                        child: const Text('Open community'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Semantics(
                      identifier: 'home-open-sheet',
                      button: true,
                      child: TextButton(
                        onPressed: () => openCommunitySheet(context),
                        child: const Text('Open in sheet'),
                      ),
                    ),
                    Semantics(
                      identifier: 'home-open-modal',
                      button: true,
                      child: TextButton(
                        onPressed: () => openCommunityModal(context),
                        child: const Text('Open as modal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "SDK initialized" card — the first thing the tester should be able to read
/// without interpreting anything: is the SDK up, and on what session.
class _SdkCard extends StatelessWidget {
  const _SdkCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final error = app.initError;
    final ready = app.initialized && error == null;

    if (error != null) {
      return SampleSection(
        title: 'SDK',
        tone: SampleTone.danger,
        identifier: 'home-sdk-card',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, size: 18, color: sampleDangerFor(brightness)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Initialization failed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: sampleDangerFor(brightness),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SampleCodeBlock(error, identifier: 'home-init-error'),
          ],
        ),
      );
    }

    return SampleSection(
      title: 'SDK',
      identifier: 'home-sdk-card',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.hourglass_top,
                size: 18,
                color: ready
                    ? sampleGreenFor(brightness)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready ? 'SDK initialized' : 'Initializing…',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ready) ...[
                SampleDot(sampleGreenFor(brightness)),
                const SizedBox(width: 6),
                Text(
                  'READY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sampleGreenFor(brightness),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SampleKeyValue(
            'Session',
            app.userConnected
                ? 'SSO · ${app.displayName}'
                : (app.initialized ? 'Guest' : '—'),
          ),
        ],
      ),
    );
  }
}

/// Three-state connection card: connected (green), guest (amber), failed SSO
/// session (red). Never two of them at once — the tester reads one line and
/// knows what the community will let them do.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final failed = !app.userConnected && app.lastConnectError != null;
    final tone = app.userConnected
        ? SampleTone.success
        : (failed ? SampleTone.danger : SampleTone.warning);
    final color = app.userConnected
        ? sampleGreenFor(brightness)
        : (failed ? sampleDangerFor(brightness) : sampleGuestAmber);
    // The GUEST label text is the darker half of the amber pair — the dot
    // above keeps the brighter `sampleGuestAmber` (spec 02: pastille and text
    // are two distinct shades, not one color reused).
    final textColor = app.userConnected
        ? sampleGreenFor(brightness)
        : (failed ? sampleDangerFor(brightness) : sampleGuestAmberText);
    final label = app.userConnected ? 'CONNECTED' : (failed ? 'OFF' : 'GUEST');
    final message = app.userConnected
        ? 'Connected as ${app.displayName}'
        : (failed
              ? 'Not connected · SSO session failed'
              : 'Browsing as guest · Read-only');

    return SampleSection(
      title: 'Connection',
      tone: tone,
      identifier: 'home-connection-card',
      child: Row(
        children: [
          SampleDot(color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
