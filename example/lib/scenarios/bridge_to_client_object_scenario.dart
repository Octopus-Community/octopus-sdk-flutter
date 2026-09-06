import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/bridge_token_signer.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Bridge-post scenario — `fetchOrCreateClientObjectRelatedPost` + `setReaction`
/// in one flow, mirroring the iOS sample's two-recipe pattern
/// (`Sample/OctopusSample/UI/Scenarios/BridgeToClientObject/Recipe.swift`).
///
/// Two recipes are exercised:
///
///   * **Stable recipe** (`recipe-1`, matches iOS) — same objectId on every run,
///     so the SDK returns the SAME post id once it has been created and we can
///     react/unreact on it deterministically.
///   * **Random recipe** — a fresh `objectId` is generated on every tap (via
///     [DateTime.now().millisecondsSinceEpoch]; mirrors iOS's
///     `UUID().uuidString`). Every tap produces a NEW post on the backend.
///
/// Both presets pass:
///
///   * a `text` long enough to clear [OctopusPrefilledPost.textMinLength];
///   * a `catchPhrase` (bold sub-headline);
///   * `viewObjectButtonText: 'View recipe'` (drives the navigate-to-client
///     object callback when the user taps the button inside the SDK feed);
///   * an [OctopusRemoteImageAttachment] pointing at a stable
///     Octopus-CDN image — the native SDK downloads it server-side, so the
///     host app never has to ship the bytes;
///   * `groupId` resolved at run-time from [OctopusSDK.groups] by topic name
///     (e.g. `Gourmands`). Falls back to `null` when no group matches.
///   * a `tokenProvider` callback that signs the SDK-provided fingerprint as
///     an HS256 JWT via [BridgeTokenSigner] (`OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET`
///     injected at build time by `--dart-define`). Returns `null`
///     for keyless / public builds — the SDK then surfaces an
///     `invalidClientToken` error from the backend. Mirrors iOS's
///     `RecipeViewModel.swift` lines 86–96 which signs in SSO mode via
///     `TokenProvider().getBridgeSignature(bridgeFingerprint:)`.
///
/// Reads from [AppState.lastNavigateObjectId] / [AppState.navigateFireCount]
/// to surface fires of [OctopusSDK.setNavigateToClientObjectCallback] in the
/// live-state card. The callback is registered at app level in
/// `AppState.bootstrap` — not in this scenario's `initState` — because the
/// user has to leave this scenario to reach the Community tab, find the
/// bridge post in the feed, and tap "View recipe" (a scenario-local
/// registration would be disposed in between, and the fire would be lost).
class BridgeToClientObjectScenario extends StatefulWidget {
  const BridgeToClientObjectScenario({super.key});

  @override
  State<BridgeToClientObjectScenario> createState() =>
      _BridgeToClientObjectScenarioState();
}

class _BridgeToClientObjectScenarioState
    extends State<BridgeToClientObjectScenario> {
  // Stable recipe — same id every run, matches iOS line 26 of Recipe.swift.
  static const String _stableObjectId = 'recipe-1';
  static const String _stableText =
      'The perfects Cannelés (Bordeaux specialty) — Flutter demo bridge post '
      'linked to the stable recipe object. Tap "View recipe" inside the SDK '
      'feed to fire navigateToClientObject back to this scenario.';
  static const String _stableCatchPhrase =
      'A delicious recipe to test the bridge';

  // Random recipe — fresh objectId every tap, mirrors iOS Recipe.swift line 72
  // (`UUID().uuidString`). We use `millisecondsSinceEpoch` to keep the value
  // stable, monotonic, and dependency-free.
  static const String _randomText =
      'French macaroons — Flutter demo bridge post with a randomised objectId '
      'so every tap produces a brand-new post on the backend. Useful to '
      'exercise create-path validation end-to-end.';
  static const String _randomCatchPhrase =
      'Once baked and eaten, tell us what you think.';
  static const String _randomTopicName = 'Gourmands';

  // A stable Octopus-CDN image URL. The native SDK downloads this server-side;
  // the host app never has to ship or buffer the bytes. Same image as iOS
  // Recipe.swift line 120.
  static final Uri _bridgeImageUrl = Uri.parse(
    'https://media-content-demo.octocdn.net/misc/macarons.jpeg',
  );

  OctopusPost? _latestPost;
  String? _latestObjectId;

  void _updatePost(OctopusPost post, String objectId) {
    if (!mounted) return;
    setState(() {
      _latestPost = post;
      _latestObjectId = objectId;
    });
  }

  String _reactionsSummary(OctopusPost post) {
    if (post.reactions.isEmpty) return '0';
    final total = post.reactions.fold<int>(0, (sum, r) => sum + r.count);
    return total.toString();
  }

  String _userReactionLabel(OctopusPost post) {
    final kind = post.userReactionKind;
    if (kind == null) return 'none';
    return kind.unicode;
  }

  /// Match a topic name against the live [OctopusSDK.groups] list and return
  /// the corresponding group id. Returns `null` when no group with that name
  /// is loaded — the SDK will then fall back to the community-default group.
  ///
  /// Mirrors iOS `RecipeViewModel.swift` lines 72–74:
  /// `groups.first(where: { $0.name == topicName })?.id`.
  String? _resolveGroupIdByTopicName(
    List<OctopusGroup> groups,
    String topicName,
  ) {
    for (final g in groups) {
      if (g.name == topicName) return g.id;
    }
    return null;
  }

  /// Host-side bridge tokenProvider. Signs the SDK-provided `fingerprint` as
  /// an HS256 JWT using the demo SSO secret (`OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET`,
  /// injected at build time via `--dart-define`).
  ///
  /// Returns `null` for keyless / public builds (secret not injected) — the
  /// SDK then surfaces an `invalidClientToken` error which the result panel
  /// reports. Mirrors iOS `RecipeViewModel.swift` lines 86–96 which signs in
  /// SSO mode via `TokenProvider().getBridgeSignature(bridgeFingerprint:)`.
  Future<String?> _hostBridgeTokenProvider(String fingerprint) async =>
      BridgeTokenSigner.signBridgeFingerprint(fingerprint);

  Future<void> _runFetchOrCreate({
    required ScenarioResultSink setResult,
    required String objectId,
    required String text,
    required String catchPhrase,
    String? topicName,
    required String presetLabel,
  }) async {
    final app = AppScope.of(context);
    final groupId = topicName == null
        ? null
        : _resolveGroupIdByTopicName(app.groups, topicName);
    final clientPost = ClientPost(
      objectId: objectId,
      text: text,
      catchPhrase: catchPhrase,
      viewObjectButtonText: 'View recipe',
      groupId: groupId,
      attachment: OctopusRemoteImageAttachment(_bridgeImageUrl),
    );
    try {
      demoLog.apiCall('fetchOrCreateClientObjectRelatedPost', {
        'preset': presetLabel,
        'objectId': objectId,
        'textLength': text.length,
        'catchPhrase': catchPhrase,
        'viewObjectButtonText': 'View recipe',
        'groupId': groupId,
        'attachment': 'remoteImage($_bridgeImageUrl)',
        'topicName': topicName,
      });
      final result = await app.octopus.fetchOrCreateClientObjectRelatedPost(
        clientPost,
        tokenProvider: _hostBridgeTokenProvider,
      );
      switch (result) {
        case OctopusSuccess(:final data):
          _updatePost(data, objectId);
          setResult(
            '$presetLabel ready. objectId=$objectId, postId=${data.id}, '
            'comments=${data.commentCount}, '
            'reactions=${_reactionsSummary(data)}, '
            'userReaction=${_userReactionLabel(data)}'
            '${groupId == null ? "" : ", groupId=$groupId"}.',
          );
        case OctopusInvalidArguments<OctopusServerError>(:final errors):
          setResult(
            '$presetLabel typed error: '
            '${errors.map((e) => e.errorMessage).join(', ')}',
            isError: true,
          );
        case OctopusConnectionFailure():
          setResult('$presetLabel failed: $result', isError: true);
      }
    } catch (e) {
      setResult('$presetLabel threw: $e', isError: true);
    }
  }

  Future<void> _runReaction({
    required ScenarioResultSink setResult,
    required OctopusReactionKind? reaction,
    required String presetLabel,
  }) async {
    final app = AppScope.of(context);
    final current = _latestPost;
    if (current == null) {
      setResult(
        'No post yet — run Preset 1 (stable) or Preset 2 (random) first to '
        'fetch-or-create the bridge post.',
        isError: true,
      );
      return;
    }
    try {
      demoLog.apiCall('setReaction', {
        'reaction': reaction?.toWire()['kind'],
        'postId': current.id,
      });
      final result = await app.octopus.setReaction(reaction, current.id);
      switch (result) {
        case OctopusSuccess():
          setResult(
            '$presetLabel succeeded on post ${current.id}. Latest cached '
            'count is stale until the next fetch — re-run Preset 1 or 2 to '
            'refresh.',
          );
        case OctopusInvalidArguments<OctopusServerError>(:final errors):
          setResult(
            '$presetLabel typed error: '
            '${errors.map((e) => e.errorMessage).join(', ')}',
            isError: true,
          );
        case OctopusConnectionFailure():
          setResult('$presetLabel failed: $result', isError: true);
      }
    } catch (e) {
      setResult('$presetLabel threw: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _latestPost;
    // App-scoped navigate state — registered in AppState.bootstrap so it
    // survives navigating away from this scenario to the Community tab,
    // tapping "View recipe" on the bridge post, and coming back to read
    // the fire count. The scenario was previously the registration site,
    // which meant the callback got disposed before the user could trigger
    // it (internal testing flagged this as not verifiable).
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Bridge to client object',
      api: 'setNavigateToClientObjectCallback',
      verifyInCommunity: true,
      description:
          'Link external objects (here two recipes — stable and random) to '
          'Octopus posts via fetchOrCreateClientObjectRelatedPost (with a '
          'remote image, a catchPhrase, a "View recipe" button label, and a '
          'topic→groupId lookup against OctopusSDK.groups), then set / clear '
          'a reaction on the returned post id with setReaction. The SDK '
          'downloads the remote image natively — the host never ships bytes. '
          '\n\nTo verify the navigateToClientObject callback: run Preset 1 '
          'or 2, navigate back to the Community tab, find the bridge post '
          'in the feed, tap "View recipe" — the SDK closes back to this '
          'scenario; "Navigate-to-client-object fires" / "Last navigate '
          'objectId" below reflect the fire (app-scoped, persists across '
          'navigation).',
      resultTestId: 'bridge-result',
      liveState: KeyValueCard(
        title: 'Latest bridge post',
        rows: [
          ('Object id', _latestObjectId ?? '—'),
          ('Post id', post?.id ?? '—'),
          ('Reactions (total)', post != null ? _reactionsSummary(post) : '—'),
          ('Comment count', post?.commentCount.toString() ?? '—'),
          ('User reaction', post != null ? _userReactionLabel(post) : '—'),
          ('Navigate-to-client-object fires', app.navigateFireCount.toString()),
          ('Last navigate objectId', app.lastNavigateObjectId ?? '—'),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-bridge-1',
          label: 'Preset 1 · Stable recipe (objectId="$_stableObjectId")',
          onRun: (setResult) async {
            await _runFetchOrCreate(
              setResult: setResult,
              objectId: _stableObjectId,
              text: _stableText,
              catchPhrase: _stableCatchPhrase,
              topicName: null,
              presetLabel: 'Stable recipe',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-bridge-2',
          label: 'Preset 2 · Random recipe (fresh objectId each tap)',
          onRun: (setResult) async {
            // Mirrors iOS `UUID().uuidString` — millisecondsSinceEpoch is
            // monotonic + collision-free at one tap per millisecond.
            final randomId = 'recipe-${DateTime.now().millisecondsSinceEpoch}';
            await _runFetchOrCreate(
              setResult: setResult,
              objectId: randomId,
              text: _randomText,
              catchPhrase: _randomCatchPhrase,
              topicName: _randomTopicName,
              presetLabel: 'Random recipe',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-bridge-3',
          label: 'Preset 3 · Heart-react on latest post',
          onRun: (setResult) async {
            await _runReaction(
              setResult: setResult,
              reaction: OctopusReactionKind.heart,
              presetLabel: 'setReaction(heart)',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-bridge-4',
          label: 'Preset 4 · Unreact on latest post',
          onRun: (setResult) async {
            await _runReaction(
              setResult: setResult,
              reaction: null,
              presetLabel: 'setReaction(null)',
            );
          },
        ),
      ],
    );
  }
}
