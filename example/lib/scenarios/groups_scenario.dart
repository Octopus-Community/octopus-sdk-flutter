import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';
import '../design.dart';

/// Browse live community groups and change each group's follow status.
class GroupsScenario extends StatefulWidget {
  const GroupsScenario({super.key});

  @override
  State<GroupsScenario> createState() => _GroupsScenarioState();
}

class _GroupsScenarioState extends State<GroupsScenario> {
  final Set<String> _loadingGroupIds = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_maybeFetchGroups());
    });
  }

  Future<void> _maybeFetchGroups() async {
    final app = AppScope.of(context);
    if (!app.isInitialised) return;
    try {
      demoLog.apiCall('fetchGroups (auto-refresh on entry)');
      final _ = await app.octopus.fetchGroups();
    } catch (_) {
      // Best-effort entry refresh; the explicit preset reports failures.
    }
  }

  Future<void> _toggleFollow(AppState app, OctopusGroup group) async {
    if (!group.canChangeFollowStatus || _loadingGroupIds.contains(group.id)) {
      return;
    }
    final method = group.isFollowed ? 'unfollowGroup' : 'followGroup';
    setState(() {
      _loadingGroupIds.add(group.id);
      _errors.remove(group.id);
    });
    try {
      demoLog.apiCall(method, {'groupId': group.id});
      final result = group.isFollowed
          ? await app.octopus.unfollowGroup(group.id)
          : await app.octopus.followGroup(group.id);
      if (!mounted) return;
      if (result.isFailure) _errors[group.id] = '$method failed: $result';
    } catch (e) {
      if (!mounted) return;
      _errors[group.id] = '$method failed: $e';
    } finally {
      if (mounted) setState(() => _loadingGroupIds.remove(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final groups = app.groups;
    return ScenarioScaffold(
      title: 'Browse Groups',
      api: 'fetchGroups',
      description:
          'Browse every group in the community and follow or unfollow each '
          'one. Follow status updates live from the SDK. Groups managed by '
          'the server cannot be toggled.',
      resultTestId: 'groups-result',
      verifyInCommunity: true,
      liveState: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueCard(
            title: 'Community groups (live)',
            rows: [('groups', '${groups.length}')],
          ),
          if (groups.isEmpty) const Text('No groups available.'),
          for (final group in groups)
            Card(
              key: ValueKey(group.id),
              child: Padding(
                padding: const EdgeInsets.all(SampleSpacing.space4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(group.isFollowed ? 'Followed' : 'Not followed'),
                          if (!group.canChangeFollowStatus)
                            const Text('Managed by server'),
                          if (_errors[group.id] case final error?)
                            Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (group.canChangeFollowStatus) ...[
                      const SizedBox(width: SampleSpacing.space3),
                      MergeSemantics(
                        child: group.isFollowed
                            ? Semantics(
                                identifier: 'qa-groups-unfollow-${group.id}',
                                button: true,
                                child: _GroupFollowButton(
                                  isLoading: _loadingGroupIds.contains(
                                    group.id,
                                  ),
                                  label: 'Unfollow',
                                  onPressed: () => _toggleFollow(app, group),
                                ),
                              )
                            : Semantics(
                                identifier: 'qa-groups-follow-${group.id}',
                                button: true,
                                child: _GroupFollowButton(
                                  isLoading: _loadingGroupIds.contains(
                                    group.id,
                                  ),
                                  label: 'Follow',
                                  onPressed: () => _toggleFollow(app, group),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-groups-1',
          label: 'Fetch groups',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('fetchGroups');
              final result = await app.octopus.fetchGroups();
              setResult('fetchGroups → $result', isError: result.isFailure);
            } catch (e) {
              setResult('fetchGroups failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}

class _GroupFollowButton extends StatelessWidget {
  const _GroupFollowButton({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  final bool isLoading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
