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
import 'sdk_summary.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'settings_choices.dart';

/// Settings summary and navigation, with a separate local reset action.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmReset(BuildContext context) async {
    final app = AppScope.of(context);
    // Reset keeps the permanent shell; close any pushed Settings routes.
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset configuration?'),
        content: const Text(
          "Clears the sample's saved setup — server, community, SSO user, "
          'theme — and returns to the sample shell. Local demo setup only — '
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
      primary: false,
      padding: const EdgeInsets.only(bottom: SampleSpacing.space6),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CommunitySettingsSummary(app: app),
        ),
        // Account stands alone at the head, with no group header: it is the one
        // line about the person using the sample, not a category of settings.
        SampleNavTile(
          icon: Icons.person,
          title: 'Account',
          subtitle: app.userConnected
              ? 'Connected as ${app.displayName} · '
                    '${app.currentEntitlements.isEmpty ? 'None' : (app.currentEntitlements.toList()..sort()).join(', ')}'
              : 'Not connected · sign in with SSO',
          identifier: 'settings-account-entry',
          onTap: () => _push(context, const AccountScreen()),
        ),
        const SampleGroupHeader('SDK', identifier: 'settings-group-sdk'),
        ...[
          SampleNavTile(
            icon: Icons.dark_mode_outlined,
            title: 'Appearance',
            subtitle:
                '${app.activeThemeLabel} · ${app.configurationChoices.theme == AppThemeChoice.system ? 'Follow system' : app.configurationChoices.theme.label}',
            identifier: 'settings-appearance-entry',
            onTap: () => _push(context, const AppearanceScreen()),
          ),
          const SampleListDivider(leading: 52),
          SampleNavTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: sdkLanguageLabel(app.localeTag),
            identifier: 'settings-language-entry',
            onTap: () => _push(context, const LanguageScreen()),
          ),
          const SampleListDivider(leading: 52),
          SampleNavTile(
            icon: Icons.cloud_outlined,
            title: 'Configuration',
            subtitle: 'Community, server, SSO user, theme',
            identifier: 'settings-reconfigure-button',
            onTap: () => _push(
              context,
              ConfigScreen(initialConfig: app.configurationChoices),
            ),
          ),
        ],
        const SampleGroupHeader(
          'Support',
          identifier: 'settings-group-support',
        ),
        ...[
          SampleNavTile(
            icon: Icons.code,
            title: 'Developer tools',
            subtitle:
                'Host app integration · Events log · Debug info · Debug console',
            identifier: 'settings-devtools-entry',
            onTap: () => _push(context, const DeveloperToolsScreen()),
          ),
          // Internal builds only, and only once a destination repository
          // has been configured — `sampleFeedbackOpener` is null in every
          // other build, which is what keeps this row (and the code behind
          // it) out of the public sample. The one row here that acts
          // instead of navigating, which is why it opens a sheet listing
          // what it is about to send rather than sending it.
          if (feedbackOpener != null) ...[
            const SampleListDivider(leading: 52),
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
          ],
          const SampleListDivider(leading: 52),
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
        // Its own group, red, last on screen. A destructive action that shares
        // a group with About is a destructive action one mis-tap away from the
        // row above it.
        const SampleGroupHeader('Reset', identifier: 'settings-group-reset'),
        SampleNavTile(
          icon: Icons.delete_forever,
          title: 'Reset Configuration',
          // Answers the question a destructive row provokes — "what am I
          // about to lose?" — before the dialog does, and the answer is the
          // reassuring half: the blast radius stops at this device.
          subtitle: 'Local demo setup only — nothing is deleted on the server',
          danger: true,
          identifier: 'settings-reset-button',
          onTap: () => _confirmReset(context),
        ),
        const SizedBox(height: SampleSpacing.space5),
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
