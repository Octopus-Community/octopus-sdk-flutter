import 'package:flutter/material.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';

/// Settings tab — user actions, language, server, reset, and the Debug-console
/// entry (injected only in the QA/debug build).
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('User'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Log in'),
                subtitle: Text(app.userConnected ? 'Connected' : 'Anonymous'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileEditPage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Disconnect'),
                enabled: app.userConnected,
                onTap: () async {
                  try {
                    await app.disconnectUser();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Disconnected')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Disconnect failed: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Language'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<LocaleChoice>(
              segments: const [
                ButtonSegment(
                  value: LocaleChoice.system,
                  label: Text('System'),
                ),
                ButtonSegment(value: LocaleChoice.fr, label: Text('fr')),
                ButtonSegment(value: LocaleChoice.en, label: Text('en')),
              ],
              selected: {app.localeChoice},
              onSelectionChanged: (s) => app.setLocale(s.first),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Server'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dns),
            title: Text(
              app.config?.serverEnv == ServerEnv.prod ? 'prod' : 'demo2',
            ),
            subtitle: const Text(
              'Set by the build (--dart-define=OCTOPUS_SERVER); '
              'not switchable at runtime.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Configuration'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset configuration'),
            subtitle: const Text('Return to the Config screen.'),
            onTap: app.reset,
          ),
        ),
        if (debugConsoleEntryBuilder != null) ...[
          const SizedBox(height: 16),
          _SectionTitle('Debug'),
          debugConsoleEntryBuilder!(context),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
