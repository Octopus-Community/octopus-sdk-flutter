import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Sync Followed Groups scenario — `syncFollowGroups` (batch follow/unfollow).
///
/// Drives the batch against the **real** community groups exposed by the
/// reactive [OctopusSDK.groups] stream (surfaced through [AppState.groups]),
/// using their actual ids and live `isFollowed` state — so follow/unfollow
/// acts on groups that exist (no more `groupNotFound` from hard-coded demo
/// ids). If the community has no groups yet, the presets report that the
/// backend community needs groups provisioned.
///
/// Mirrors the Android sample: three trigger
/// flavours — **invert all**, **FOLLOW all**, **UNFOLLOW all** — plus an
/// `actionDate` offset selector. FOLLOW-all / UNFOLLOW-all let QA reach the
/// [SyncFollowGroupStatus.alreadyFollowed] / [SyncFollowGroupStatus.alreadyUnfollowed]
/// statuses that the invert-all trigger never reaches, and the past offset lets
/// QA exercise the stale-action [SyncFollowGroupStatus.skipped] path (the
/// backend only applies actions more recent than the stored timestamp).
/// Groups whose follow status is locked (`canChangeFollowStatus == false`,
/// e.g. force-followed) are left untouched, matching Android.
class SyncFollowGroupsScenario extends StatefulWidget {
  const SyncFollowGroupsScenario({super.key});

  @override
  State<SyncFollowGroupsScenario> createState() =>
      _SyncFollowGroupsScenarioState();
}

/// The `actionDate` offsets QA can apply to a batch, relative to now.
enum _ActionDateOffset {
  past(
    'Past (−5 min)',
    'qa-syncFollowGroups-offset-past',
    Duration(minutes: -5),
  ),
  now('Now', 'qa-syncFollowGroups-offset-now', Duration.zero),
  future(
    'Future (+5 min)',
    'qa-syncFollowGroups-offset-future',
    Duration(minutes: 5),
  );

  const _ActionDateOffset(this.label, this.testId, this.value);

  final String label;
  final String testId;
  final Duration value;
}

class _SyncFollowGroupsScenarioState extends State<SyncFollowGroupsScenario> {
  _ActionDateOffset _offset = _ActionDateOffset.now;

  @override
  void initState() {
    super.initState();
    // Mirror NotSeenNotificationsScenario.initState (and iOS `.onAppear`):
    // refresh the SDK's groups list on entry so the live state reflects
    // the latest server-side groups and presets can act on them
    // immediately. The reactive `OctopusSDK.groups` stream is populated
    // lazily — the native SDK does not auto-fetch on init/connect, so
    // without this the scenario always opens on an empty live state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeFetchGroups());
    });
  }

  Future<void> _maybeFetchGroups() async {
    final app = AppScope.of(context);
    // Skip until the SDK is initialised: calling fetchGroups() before
    // init makes the native handler reject with a PlatformException, and
    // a fire-and-forget call would then surface as an unhandled
    // async-zone error.
    if (!app.isInitialised) return;
    try {
      demoLog.apiCall('fetchGroups (auto-refresh on entry)');
      // Fire-and-forget. The returned OctopusResult (success or
      // OctopusFailure) is discarded into `_` to make the intent explicit —
      // fetchGroups is not `@useResult`, so nothing forces this; it is a
      // best-effort entry refresh, and the presets call fetchGroups again as
      // needed and surface real errors themselves. The catch only handles
      // platform throws (PlatformException, missing-plugin) so initState
      // never breaks the frame.
      final _ = await app.octopus.fetchGroups();
    } catch (_) {}
  }

  Future<void> _sync(
    AppState app,
    ScenarioResultSink setResult,
    bool Function(OctopusGroup group) targetFollowed,
  ) async {
    final groups = app.groups;
    if (groups.isEmpty) {
      setResult(
        'No groups in this community to sync. Provision at least one group on '
        'the backend — the SDK only follows groups that exist.',
        isError: true,
      );
      return;
    }
    // Only groups whose follow status can be changed (force-followed /
    // otherwise-locked groups stay untouched — matches the Android sample).
    final controllable = groups
        .where((g) => g.canChangeFollowStatus)
        .toList(growable: false);
    if (controllable.isEmpty) {
      setResult(
        'No groups with canChangeFollowStatus = true. Every group here is '
        'force-followed / locked, so a batch would leave them all untouched.',
        isError: true,
      );
      return;
    }
    final actionDate = DateTime.now().add(_offset.value);
    final actions = [
      for (final g in controllable)
        SyncFollowGroupAction(
          groupId: g.id,
          followed: targetFollowed(g),
          actionDate: actionDate,
        ),
    ];
    demoLog.apiCall('syncFollowGroups', {
      'offset': _offset.name,
      'actionDate': actionDate.toIso8601String(),
      'actions': {for (final a in actions) a.groupId: a.followed},
    });
    try {
      final results = await app.octopus.syncFollowGroups(actions);
      final nameById = {for (final g in groups) g.id: g.name};
      final lines = results
          .map((r) => '${nameById[r.groupId] ?? r.groupId}: ${r.status.name}')
          .join('\n');
      setResult(
        'syncFollowGroups (${_offset.label}) returned ${results.length} '
        'result(s):\n$lines',
      );
    } catch (e) {
      setResult('syncFollowGroups failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final groups = app.groups;
    return ScenarioScaffold(
      title: 'Sync Followed Groups',
      api: 'syncFollowGroups',
      verifyInCommunity: true,
      description:
          'Batch follow/unfollow the community\'s real groups in one '
          'round-trip (from the OctopusSDK.groups stream). Requires a connected '
          'user. Pick an actionDate offset (a past offset is stale → the '
          'backend returns "skipped"), then run a trigger. Force-followed / '
          'locked groups (canChangeFollowStatus = false) are left untouched. If '
          'the community has no groups, provision some on the backend first.',
      resultTestId: 'syncFollowGroups-result',
      liveState: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OffsetSelector(
            selected: _offset,
            onChanged: (offset) => setState(() => _offset = offset),
          ),
          const SizedBox(height: 16),
          KeyValueCard(
            title: 'Community groups (live)',
            rows: groups.isEmpty
                ? const [('groups', 'none — provision on backend')]
                : [
                    for (final g in groups)
                      (
                        g.name,
                        g.canChangeFollowStatus
                            ? (g.isFollowed ? 'followed' : 'not followed')
                            : (g.isFollowed
                                  ? 'followed · locked (untouched)'
                                  : 'not followed · locked (untouched)'),
                      ),
                  ],
          ),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-syncFollowGroups-1',
          label: 'Preset 1 · Invert all',
          onRun: (setResult) => _sync(app, setResult, (g) => !g.isFollowed),
        ),
        ScenarioPreset(
          testId: 'qa-preset-syncFollowGroups-2',
          label: 'Preset 2 · FOLLOW all',
          onRun: (setResult) => _sync(app, setResult, (_) => true),
        ),
        ScenarioPreset(
          testId: 'qa-preset-syncFollowGroups-3',
          label: 'Preset 3 · UNFOLLOW all',
          onRun: (setResult) => _sync(app, setResult, (_) => false),
        ),
      ],
    );
  }
}

/// Single-tap selector for the batch `actionDate` offset relative to now.
class _OffsetSelector extends StatelessWidget {
  final _ActionDateOffset selected;
  final ValueChanged<_ActionDateOffset> onChanged;

  const _OffsetSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('actionDate offset', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final offset in _ActionDateOffset.values)
              MergeSemantics(
                child: Semantics(
                  identifier: offset.testId,
                  button: true,
                  selected: offset == selected,
                  child: ChoiceChip(
                    label: Text(offset.label),
                    selected: offset == selected,
                    onSelected: (_) => onChanged(offset),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
