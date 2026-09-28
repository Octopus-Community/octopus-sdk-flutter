/// Settings tab — a pure summary: every line is a chevron into a screen that
/// owns one subject, and each subtitle shows the value that is live right now.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config/config_screen.dart';
import '../design.dart';
import '../octopus_demo_config.dart';
import '../sample_feedback.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'developer_tools_screen.dart';

/// Settings tab.
///
/// Nothing is *changed* here — no switch, no segmented control, no destructive
/// action beyond the single red Reset Configuration row. Account first and
/// alone (it is the one line about the person using the sample), then a
/// single "Change Configuration" line for everything the SDK runs on
/// (appearance, language and server/community changed to live in Config —
/// one setting, one place — rather than as separate Settings entries), then
/// Support, then Reset Configuration as the group's last, red row.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmReset(BuildContext context) async {
    final app = AppScope.of(context);
    // Reset swaps the root back to the Config screen; any pushed route stack
    // would otherwise stay on top of it.
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset configuration?'),
        content: const Text(
          "Clears the sample's saved setup — server, community, SSO user, "
          'theme — and restarts on the Config screen. Local demo setup only — '
          'nothing is deleted on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          Semantics(
            identifier: 'settings-reset-confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: sampleDangerButtonStyle(dialogContext),
              child: const Text('Reset Configuration'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.reset();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final config = app.config;
    final feedbackOpener = sampleFeedbackOpener;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Account stands alone at the head, with no group header: it is the one
        // line about the person using the sample, not a category of settings.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: sampleBorderFor(theme.brightness)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SampleNavTile(
            icon: Icons.person,
            title: 'Account',
            subtitle: app.userConnected
                ? 'Connected as ${app.displayName} · '
                      '${app.currentEntitlements.length} entitlements'
                : 'Not connected · browsing as guest',
            identifier: 'settings-account-entry',
            onTap: () => _push(context, const AccountScreen()),
          ),
        ),
        const SizedBox(height: 16),
        SampleSection(
          title: 'SDK',
          identifier: 'settings-group-sdk',
          child: SampleNavTile(
            icon: Icons.dns,
            title: 'Change Configuration',
            subtitle:
                '${config?.serverEnv.label ?? '—'} · '
                '${config?.hostLabel ?? '—'} · '
                '${config?.theme.label ?? AppThemeChoice.system.label}',
            identifier: 'settings-reconfigure-button',
            onTap: () => _push(
              context,
              ConfigScreen(initialConfig: config, entry: ConfigEntry.revisit),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SampleSection(
          title: 'Support',
          identifier: 'settings-group-support',
          child: Column(
            children: [
              SampleNavTile(
                icon: Icons.code,
                title: 'Developer tools',
                subtitle: 'Events log · Debug info · Debug console',
                identifier: 'settings-devtools-entry',
                onTap: () => _push(context, const DeveloperToolsScreen()),
              ),
              // Internal builds only, and only once a destination repository
              // has been configured — `sampleFeedbackOpener` is null in every
              // other build, which is what keeps this row (and the code behind
              // it) out of the public sample. The one row here that acts
              // instead of navigating, which is why it opens a sheet listing
              // what it is about to send rather than sending it.
              if (feedbackOpener != null)
                SampleNavTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send feedback',
                  subtitle: 'Pre-filled GitHub issue · internal builds only',
                  identifier: 'settings-feedback-entry',
                  onTap: () => feedbackOpener(
                    context,
                    FeedbackContext(
                      where: app.lastContentBreadcrumb,
                      environment: config?.serverEnv.label ?? '—',
                      togglesSummary: app.featureToggles.summaryLine,
                      platform: Theme.of(context).platform.name,
                      versions: app.sampleVersionLabel ?? 'Sample',
                    ),
                  ),
                ),
              SampleNavTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: octopusDesignReferenceUrl.isEmpty
                    ? (app.sampleVersionLabel ?? 'Sample')
                    : '${app.sampleVersionLabel ?? 'Sample'} · '
                          'Design reference',
                identifier: 'settings-about-entry',
                onTap: () => _push(context, const AboutScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Its own group, red, last on screen. A destructive action that shares
        // a group with About is a destructive action one mis-tap away from the
        // row above it.
        SampleSection(
          title: 'Reset',
          identifier: 'settings-group-reset',
          child: SampleNavTile(
            icon: Icons.delete_forever,
            title: 'Reset Configuration',
            // Answers the question a destructive row provokes — "what am I
            // about to lose?" — before the dialog does, and the answer is the
            // reassuring half: the blast radius stops at this device.
            subtitle:
                'Local demo setup only — nothing is deleted on the server',
            danger: true,
            identifier: 'settings-reset-button',
            onTap: () => _confirmReset(context),
          ),
        ),
        const SizedBox(height: 20),
        // `app.sampleVersionLabel` is read from real platform build metadata
        // (`package_info_plus`) and resolves during `AppState.bootstrap` — null
        // for at most one frame before the first paint in practice. Omit the
        // line entirely rather than show a placeholder.
        if (app.sampleVersionLabel != null)
          Center(
            child: Semantics(
              identifier: 'settings-version-label',
              child: Text(
                'Sample ${app.sampleVersionLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
