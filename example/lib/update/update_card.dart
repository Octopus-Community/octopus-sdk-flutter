import 'package:flutter/material.dart';

import 'sample_update_checker.dart';
import 'sample_update_status.dart';

/// The sample's own update surface — only Play's flow itself belongs to Play.
///
/// Lives in Settings rather than on Home, unlike the Android sample: the
/// Flutter Home tab is a read-only dashboard by design ("every state-changing
/// action lives in a scenario or Settings"), and a button that installs a new
/// build is the least read-only thing in the app. The test ids are the shared
/// ones either way — the QA lane must not need to know which sample it drives.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.checker});

  final SampleUpdateChecker checker;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: checker,
      builder: (context, _) {
        final status = checker.status;
        if (status is UpdateUnsupported) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final (label, isProblem) = switch (status) {
          UpdateUnknown() => ('Tap to check for updates', false),
          UpdateChecking() => ('Checking…', false),
          UpdateUpToDate() => ('App is up to date', false),
          UpdateAvailableStatus() => ('A new version is available', false),
          UpdateNotInstallable() => (
            "A new version exists, but Play won't install it over this build",
            true,
          ),
          UpdateNotFromPlayStore() => ('Not installed from Play Store', false),
          UpdateCheckFailed(errorCode: final code) => (
            code == null
                ? 'Update check failed — tap to retry'
                : 'Update check failed (code $code) — tap to retry',
            true,
          ),
          UpdateUnsupported() => ('', false),
        };
        final canUpdate = status is UpdateAvailableStatus;
        final busy = status is UpdateChecking;

        return Semantics(
          identifier: 'sample-update-card',
          label: 'App update',
          explicitChildNodes: true,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          identifier: 'sample-update-status',
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isProblem
                                      ? scheme.error
                                      : canUpdate
                                      ? scheme.primary
                                      : scheme.onSurface.withValues(
                                          alpha: 0.74,
                                        ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'sample-update-action',
                    button: true,
                    child: canUpdate
                        ? FilledButton(
                            // Nothing starts Play's flow but this tap — the
                            // rule the shared contract actually binds.
                            onPressed: () => checker.startUpdate(),
                            child: const Text('Update now'),
                          )
                        : OutlinedButton(
                            onPressed: busy ? null : () => checker.check(),
                            child: const Text('Check for Update'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
