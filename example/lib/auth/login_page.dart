import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import 'connect_user_result.dart';

/// Login page backing the embedded UI's `onNavigateToLogin` callback (SSO mode).
///
/// In SSO mode the host app owns authentication. Here we connect the bundled
/// demo SSO user; a real app would run its own login and call `connectUser`
/// with the resulting JWT.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AppScope.of(context).connectDemoUser();
      final failure = describeConnectUserFailure(result);
      if (failure != null) {
        setState(() => _error = failure);
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SampleScaffold(
      appBar: const SampleTopAppBar(title: 'Login'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SampleSpacing.space6),

          children: [
            Text(
              'Connect the demo SSO user',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SampleSpacing.space4),
            Text(
              'User id: ${AppScope.of(context).effectiveUserId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SampleSpacing.space6),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: SampleSpacing.space4),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_busy ? 'Connecting…' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
