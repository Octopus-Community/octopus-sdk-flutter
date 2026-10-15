import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import '../app_state.dart';
import '../design.dart';

/// Shared by Settings and Debug info; network reachability is not exposed.
String sdkStatusLabel(AppState app) {
  if (app.initError != null) return 'Failed';
  if (!app.initialized) return 'Not started';
  if (app.connectionState is! OctopusConnected) return 'Started, no session';
  return app.userConnected ? 'Running, signed in' : 'Running as guest';
}

String sdkConnectionLabel(AppState app) => switch (app.connectionState) {
  OctopusConnected(:final isGuest) =>
    isGuest
        ? 'Guest'
        : 'Connected · ${app.connectedProfile?.userId ?? app.effectiveUserId}',
  _ => 'Not connected',
};

String sdkStatusDetail(AppState app) {
  if (app.initError != null) {
    return 'Check Debug info for the initialization error.';
  }
  if (!app.initialized) return 'Apply the SDK setup from Configuration.';
  if (app.connectionState is! OctopusConnected) {
    return 'The SDK has not opened a session yet, not even a guest one.';
  }
  return app.userConnected
      ? 'Every scenario is available.'
      : 'Read-only: connect an SSO user to post and react.';
}

/// Read-only configuration details formerly displayed on Home.
class ConfigurationSummary extends StatelessWidget {
  const ConfigurationSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config;
    return SampleSection(
      title: 'Current configuration',
      identifier: 'settings-configuration',
      child: Column(
        children: [
          SampleKeyValue('Server environment', config?.serverLabel ?? '—'),
          SampleKeyValue('Host', config?.hostLabel ?? '—', mono: true),
          SampleKeyValue('Community', config?.communityLabel ?? '—'),
          // The source kind — "Demo (--dart-define)", "Named key
          // (--dart-define)" or "Custom", see
          // [DemoConfig.apiKeyLabel]. Never the key, nor its label
          // (that is the Community row above).
          SampleKeyValue('API key source', config?.apiKeyLabel ?? '—'),
          SampleKeyValue('SSO user', app.effectiveUserId, mono: true),
          SampleKeyValue(
            'Entitlements',
            app.currentEntitlements.isEmpty
                ? 'None'
                : (app.currentEntitlements.toList()..sort()).join(', '),
          ),
          SampleKeyValue('Theme', app.activeThemeLabel),
          SampleKeyValue('Language', app.localeLabel),
        ],
      ),
    );
  }
}

/// "SDK initialized" card — the first thing the tester should be able to read
/// without interpreting anything: is the SDK up, and on what session.
class SdkStatusSummary extends StatelessWidget {
  const SdkStatusSummary({super.key, required this.app});

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
        identifier: 'settings-sdk-card',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, size: 18, color: sampleDangerFor(brightness)),
                const SizedBox(width: SampleSpacing.space2),
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
            const SizedBox(height: SampleSpacing.space2),
            SampleCodeBlock(error, identifier: 'settings-init-error'),
          ],
        ),
      );
    }

    return SampleSection(
      title: 'SDK',
      identifier: 'settings-sdk-card',
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
              const SizedBox(width: SampleSpacing.space2),
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
class ConnectionSummary extends StatelessWidget {
  const ConnectionSummary({super.key, required this.app});

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
        : (failed ? sampleDangerFor(brightness) : sampleAmberFor(brightness));
    final label = app.userConnected ? 'CONNECTED' : (failed ? 'OFF' : 'GUEST');
    final message = app.userConnected
        ? 'Connected as ${app.displayName}'
        : (failed
              ? 'Not connected · SSO session failed'
              : 'Browsing as guest · Read-only');

    return SampleSection(
      title: 'Connection',
      tone: tone,
      identifier: 'settings-connection-card',
      child: Row(
        children: [
          SampleDot(color),
          const SizedBox(width: SampleSpacing.space2),
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

/// The same compact community/session summary as the Android Settings root.
class CommunitySettingsSummary extends StatelessWidget {
  const CommunitySettingsSummary({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final config = app.config;
    final status = sdkStatusLabel(app);
    return SampleSection(
      title: 'Community',
      identifier: 'settings-community-summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SampleKeyValue('Name', config?.communityLabel ?? '—'),
          const SizedBox(height: 8),
          SampleKeyValue('Server', config?.serverLabel ?? '—'),
          const SizedBox(height: 8),
          Row(
            children: [
              SampleDot(
                app.initialized && app.initError == null
                    ? sampleGreenFor(Theme.of(context).brightness)
                    : sampleAmberFor(Theme.of(context).brightness),
              ),
              const SizedBox(width: SampleSpacing.space2),
              Expanded(child: SampleKeyValue('SDK', status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sdkStatusDetail(app),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
