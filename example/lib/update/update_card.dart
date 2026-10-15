import 'package:flutter/material.dart';
import '../design.dart';

import 'sample_update_checker.dart';
import 'sample_update_status.dart';

/// The sample's own update surface — only Play's flow itself belongs to Play.
///
/// Lives in Settings › About, keeping the existing Play check/install actions
/// and shared QA identifiers after removal of the Home tab.
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
              padding: const EdgeInsets.all(SampleSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update,
                        size: 20,
                        color: sampleAccent(Theme.of(context).brightness),
                      ),
                      const SizedBox(width: SampleSpacing.space2),
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
                                      ? sampleAccent(
                                          Theme.of(context).brightness,
                                        )
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SampleSpacing.space3),
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
