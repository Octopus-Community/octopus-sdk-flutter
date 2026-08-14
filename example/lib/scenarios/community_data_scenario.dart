import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../community/client_profile_page.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Unified Profile community-data scenario — reads a member's public Octopus
/// stats so the **host** can render them on its own profile screen, instead of
/// pushing the user into the SDK's native profile.
///
/// Exercises the whole read surface added in 1.13:
/// - `fetchCommunityData(clientUserId:)` — the id kind a host actually has.
/// - `fetchCommunityData(profileId:)` — replayed with the Octopus id the first
///   fetch returned, so both lookup paths are covered without asking QA to
///   paste an opaque id.
/// - `communityDataFlow(clientUserId:)` — the reactive counterpart; start/stop
///   presets make the native observation lifecycle observable.
/// - `OctopusProfile.clientUserId` — surfaced in the live-state card.
/// - The exactly-one-id contract (`ArgumentError` on both/neither).
class CommunityDataScenario extends StatefulWidget {
  const CommunityDataScenario({super.key});

  @override
  State<CommunityDataScenario> createState() => _CommunityDataScenarioState();
}

class _CommunityDataScenarioState extends State<CommunityDataScenario> {
  /// Latest value seen from either a fetch or the flow.
  OctopusCommunityData? _data;

  /// Where [_data] came from — makes it obvious in QA whether the value on
  /// screen was pushed by the observation or pulled by a fetch.
  String _source = '—';

  /// The Octopus profile id learned from a successful lookup, so the
  /// `profileId` presets need no hand-typed id.
  String? _lastProfileId;

  StreamSubscription<OctopusCommunityData?>? _flowSub;
  Object? _flowError;

  @override
  void dispose() {
    // The subscription owns a native observation — dropping it without
    // cancelling would leak the native collector for the app's lifetime.
    unawaited(_flowSub?.cancel());
    super.dispose();
  }

  void _record(OctopusCommunityData? data, String source) {
    if (!mounted) return;
    setState(() {
      _data = data;
      _source = source;
      if (data != null) _lastProfileId = data.profileId;
    });
  }

  /// The host-side id to look the member up by: the id the SDK reports for the
  /// connected user when available, else the configured SSO subject.
  String _clientUserId(AppState app) =>
      app.profile?.clientUserId ?? app.effectiveUserId;

  Future<void> _stopObserving() async {
    final sub = _flowSub;
    _flowSub = null;
    await sub?.cancel();
    if (mounted) setState(() => _flowError = null);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final data = _data;
    final gamification = data?.gamification;
    return ScenarioScaffold(
      title: 'Community Data (Unified Profile)',
      description:
          'Reads a member\'s public Octopus stats with `fetchCommunityData` '
          '(one shot) and `communityDataFlow` (reactive), by Octopus '
          '`profileId` or by your own `clientUserId`. Note that '
          '`gamification.score` is always null through this API — use `level`.',
      resultTestId: 'communityData-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('profile.clientUserId', app.profile?.clientUserId ?? '—'),
          ('lookup clientUserId', _clientUserId(app)),
          ('observing', _flowSub == null ? 'no' : 'yes'),
          ('last value from', _source),
          ('profileId', data?.profileId ?? '—'),
          ('messageCount', data?.messageCount?.toString() ?? 'null'),
          ('gamification.level', gamification?.level.toString() ?? 'null'),
          ('gamification.score', gamification?.score?.toString() ?? 'null'),
          if (_flowError != null) ('flow error', _flowError.toString()),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-communityData-1',
          label: 'Preset 1 · Fetch by clientUserId',
          onRun: (setResult) async {
            final clientUserId = _clientUserId(app);
            try {
              demoLog.apiCall('fetchCommunityData', {
                'clientUserId': clientUserId,
              });
              final data = await app.octopus.fetchCommunityData(
                clientUserId: clientUserId,
              );
              if (!mounted) return;
              _record(data, 'fetch(clientUserId)');
              setResult(
                data == null
                    ? 'Unknown member for clientUserId "$clientUserId" '
                          '(null — the community may not expose client user ids).'
                    : 'Fetched: $data',
              );
            } catch (e) {
              if (!mounted) return;
              setResult('fetchCommunityData failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityData-2',
          label: 'Preset 2 · Fetch by profileId (from the last lookup)',
          onRun: (setResult) async {
            final profileId = _lastProfileId;
            if (profileId == null) {
              setResult(
                'No profileId known yet — run Preset 1 or 3 first.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('fetchCommunityData', {'profileId': profileId});
              final data = await app.octopus.fetchCommunityData(
                profileId: profileId,
              );
              if (!mounted) return;
              _record(data, 'fetch(profileId)');
              setResult(
                data == null
                    ? 'Unknown member for profileId "$profileId".'
                    : 'Fetched: $data',
              );
            } catch (e) {
              if (!mounted) return;
              setResult('fetchCommunityData failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityData-3',
          label: 'Preset 3 · Observe by clientUserId (start)',
          onRun: (setResult) async {
            final clientUserId = _clientUserId(app);
            await _stopObserving();
            try {
              demoLog.apiCall('communityDataFlow', {
                'clientUserId': clientUserId,
              });
              final sub =
                  OctopusSDK.communityDataFlow(
                    clientUserId: clientUserId,
                  ).listen(
                    (data) => _record(data, 'flow(clientUserId)'),
                    onError: (Object e) {
                      if (!mounted) return;
                      setState(() => _flowError = e);
                    },
                  );
              if (!mounted) {
                await sub.cancel();
                return;
              }
              setState(() {
                _flowSub = sub;
                _flowError = null;
              });
              setResult(
                'Observing community data for clientUserId "$clientUserId". '
                'Run Preset 1 or act in the community to see an emission.',
              );
            } catch (e) {
              if (!mounted) return;
              setResult('communityDataFlow failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityData-4',
          label: 'Preset 4 · Stop observing',
          onRun: (setResult) async {
            final wasObserving = _flowSub != null;
            await _stopObserving();
            if (!mounted) return;
            setState(() {});
            setResult(
              wasObserving
                  ? 'Cancelled the subscription — the native observation is '
                        'torn down.'
                  : 'Nothing was being observed.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityData-5',
          label: 'Preset 5 · Contract: both / neither id throws',
          onRun: (setResult) async {
            final failures = <String>[];
            try {
              await app.octopus.fetchCommunityData();
              failures.add('fetch with neither id did not throw');
            } on ArgumentError catch (_) {
              // expected
            }
            try {
              await app.octopus.fetchCommunityData(
                profileId: 'a',
                clientUserId: 'b',
              );
              failures.add('fetch with both ids did not throw');
            } on ArgumentError catch (_) {
              // expected
            }
            try {
              OctopusSDK.communityDataFlow();
              failures.add('communityDataFlow with neither id did not throw');
            } on ArgumentError catch (_) {
              // expected — thrown synchronously, when the stream is built.
            }
            if (!mounted) return;
            setResult(
              failures.isEmpty
                  ? 'Exactly-one-id contract enforced on both APIs '
                        '(ArgumentError thrown — a real throw, not a debug '
                        'assert).'
                  : 'Contract violations: ${failures.join('; ')}',
              isError: failures.isNotEmpty,
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityData-6',
          label: 'Preset 6 · Open the host-rendered profile page',
          onRun: (setResult) async {
            final clientUserId = _clientUserId(app);
            final navigator = Navigator.of(context);
            demoLog.apiCall('Navigator.push(ClientProfilePage)', {
              'clientUserId': clientUserId,
            });
            setResult(
              'Pushed the host profile page for "$clientUserId" — it fetches '
              'and renders the community data in the host\'s own UI.',
            );
            await navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => ClientProfilePage(clientUserId: clientUserId),
              ),
            );
          },
        ),
      ],
    );
  }
}
