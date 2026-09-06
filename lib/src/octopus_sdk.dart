import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart' show useResult;

import 'api_server.dart';
import 'client_post.dart';
import 'client_post_error.dart';
import 'client_user_error.dart';
import 'content_options.dart';
import 'create_post_screen_info.dart';
import 'group_follow_unfollow_error.dart';
import 'octopus_community_data.dart';
import 'octopus_connection_state.dart';
import 'octopus_event.dart';
import 'octopus_group.dart';
import 'octopus_initial_screen.dart';
import 'octopus_nav_bar_leading_action.dart';
import 'octopus_navigation_mode.dart';
import 'octopus_notification.dart';
import 'octopus_post.dart';
import 'octopus_profile.dart';
import 'octopus_reaction_kind.dart';
import 'octopus_result.dart';
import 'override_community_access_error.dart';
import 'refresh_entitlements_error.dart';
import 'set_reaction_error.dart';
import 'profile_field.dart';
import 'profile_fields_lock.dart';
import 'octopus_sdk_platform.dart';
import 'octopus_theme.dart';
import 'octopus_home_screen.dart';
import 'sync_follow_group.dart';
import 'terms_acceptance_mode.dart';
import 'url_opening_strategy.dart';

export 'api_server.dart';
export 'client_post.dart';
export 'client_post_error.dart';
export 'client_user_error.dart';
export 'content_options.dart';
export 'octopus_community_data.dart';
export 'create_post_screen_info.dart';
export 'group_follow_unfollow_error.dart';
export 'octopus_connection_state.dart';
export 'octopus_group.dart';
export 'octopus_notification.dart';
export 'octopus_post.dart';
export 'octopus_post_cta.dart';
export 'octopus_prefilled_post.dart';
export 'octopus_profile.dart';
export 'octopus_reaction_kind.dart';
export 'octopus_result.dart';
export 'override_community_access_error.dart';
export 'refresh_entitlements_error.dart';
export 'set_reaction_error.dart';
export 'profile_field.dart';
export 'profile_fields_lock.dart';
export 'octopus_home_screen.dart';
export 'sync_follow_group.dart';
export 'terms_acceptance_mode.dart';
export 'url_opening_strategy.dart';

// Event stream controller for native events
StreamController<Map<String, dynamic>>? _eventStreamController;
EventChannel? _eventChannel;
StreamSubscription?
// ignore: unused_element
    _eventSubscription; // Stored to prevent GC and allow future cancellation
bool _isEventChannelInitialized = false;

// Cached last values so late subscribers don't miss the initial emission.
// The native side emits these during initialize(), but the Dart consumer
// may not be listening yet.
int? _lastNotSeenNotificationsCount;
bool? _lastHasAccessToCommunity;

// Profile cache. The value itself is nullable (null = not connected), so a
// separate flag tracks whether the native side has emitted at all yet — only
// then is the cached value replayed to late subscribers.
bool _hasReceivedProfile = false;
OctopusProfile? _lastProfile;

// Groups cache. The emitted value is always a non-null list (possibly empty),
// so a null cache unambiguously means "not received yet" — late subscribers
// get the last list replayed.
List<OctopusGroup>? _lastGroups;

// Connection-state cache. `null` cache unambiguously means "not received yet"
// (the value itself is always non-null), so late subscribers get the last
// snapshot replayed.
OctopusConnectionState? _lastConnectionState;

// The SDK genuinely starts uninitialised, so this defaults to `false` (unlike
// the nullable caches above). The native side snapshots the current value on
// EventChannel subscription and emits on every change; the lifecycle methods
// below also update it optimistically so the synchronous [OctopusSDK.isInitialised]
// getter is accurate immediately after awaiting initialize/switchCommunity/stop.
bool _lastIsInitialised = false;

// The currently-registered group-access-denied callback. Single-field
// (last-write-wins), mirroring the native SDK's single-callback model.
void Function(String groupId)? _groupAccessDeniedCallback;

// The currently-registered navigate-to-client-object callback. Single-field
// (last-write-wins), mirroring the native iOS single-callback model.
void Function(String objectId)? _navigateToClientObjectCallback;

// Pending bridge token providers, keyed by an in-flight requestId. Populated by
// [OctopusSDK.fetchOrCreateClientObjectRelatedPost] for the duration of one
// call and removed when it settles. The keying makes the native→Dart token
// request/reply reentrant: two concurrent calls each carry their own requestId,
// so the native side correlates the right provider with the right reply.
final Map<String, Future<String?> Function(String fingerprint)>
    _bridgeTokenProviders = <String, Future<String?> Function(String)>{};
int _bridgeTokenRequestCounter = 0;

// The in-flight requestId of the create-post editor's bridge-share token
// provider, if any. Unlike [fetchOrCreateClientObjectRelatedPost] (call-scoped,
// removed in a `finally`), the editor's provider must outlive the launch call —
// it is consulted later, at publish time. The native editor holds a single
// bridge-share provider (last-write-wins, cleared when the editor closes), so
// opening a new editor supersedes the previous one; we drop the stale Dart
// entry then to keep [_bridgeTokenProviders] bounded.
String? _createPostBridgeTokenRequestId;

// Persistent client-user tokenProviders, keyed by a stable providerId per
// connected user. Registered when connecting with a tokenProvider (see
// [OctopusSDK.connectUser]) and cleared on [OctopusSDK.disconnectUser]. The
// native SDK invokes the provider
// initially (on connect) AND on every refresh (e.g. `refreshEntitlements`
// minting a fresh JWT with the host's current entitlement set), so the
// provider must round-trip back to Dart each time — not capture a static
// token. The native bridge generates a unique requestId per invocation so
// concurrent refreshes can't race.
final Map<String, Future<String> Function()> _clientUserTokenProviders =
    <String, Future<String> Function()>{};
int _clientUserTokenProviderCounter = 0;

// Monotonic counter for client-object-post observation ids. Each
// getClientObjectRelatedPostFlow subscription gets its own id so that two
// listeners on the same clientObjectId observe independently (the native side
// keys its collection job by this id, never by the clientObjectId).
int _clientObjectObservationCounter = 0;
int _communityDataObservationCounter = 0;

class OctopusSDK {
  static void _initializeEventChannel() {
    if (_isEventChannelInitialized) return;
    _isEventChannelInitialized = true;

    _eventChannel = const EventChannel('octopus_sdk_flutter/events');
    _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

    _eventSubscription = _eventChannel!.receiveBroadcastStream().listen(
      (event) => handleNativeEvent(Map<String, dynamic>.from(event as Map)),
      onError: (error) {
        debugPrint('OctopusSDK: EventChannel error: $error');
      },
    );
  }

  /// Routes a raw native event: caches state-shaped values for late-subscriber
  /// replay, dispatches the registered callbacks (group-access-denied,
  /// navigate-to-client-object, bridge token request), and forwards the event
  /// to [eventStream]. Exposed for testing.
  @visibleForTesting
  static void handleNativeEvent(Map<String, dynamic> map) {
    switch (map['event']) {
      case 'notSeenNotificationsCountChanged':
        _lastNotSeenNotificationsCount = map['count'] as int?;
      case 'hasAccessToCommunityChanged':
        _lastHasAccessToCommunity = map['hasAccess'] as bool?;
      case 'profileChanged':
        _hasReceivedProfile = true;
        final raw = map['profile'];
        _lastProfile = raw is Map ? OctopusProfile.fromWire(raw) : null;
      case 'groupsChanged':
        _lastGroups = _decodeGroups(map['groups']);
      case 'connectionStateChanged':
        _lastConnectionState = _decodeConnectionState(map);
      case 'isInitialisedChanged':
        _lastIsInitialised = map['isInitialised'] as bool;
      case 'groupAccessDenied':
        _groupAccessDeniedCallback?.call(map['groupId'] as String);
      case 'navigateToClientObject':
        _navigateToClientObjectCallback?.call(map['objectId'] as String);
      case 'bridgeTokenRequest':
        _handleBridgeTokenRequest(map);
      case 'clientUserTokenRequest':
        _handleClientUserTokenRequest(map);
    }
    _eventStreamController?.add(map);
  }

  /// Handles a native `bridgeTokenRequest`: looks up the registered Dart token
  /// provider for the request's `requestId`, computes the token (or `null`),
  /// and **always** replies via [OctopusSDKPlatform.provideBridgeToken] — the
  /// explicit null-reply contract the native side waits on (a MethodChannel
  /// can't tell "no reply" from a `null` reply). A missing provider or a
  /// throwing provider both reply `null`.
  static void _handleBridgeTokenRequest(Map<String, dynamic> map) {
    final requestId = map['requestId'];
    if (requestId is! String) return;
    final fingerprint =
        map['fingerprint'] is String ? map['fingerprint'] as String : '';
    final provider = _bridgeTokenProviders[requestId];
    unawaited(() async {
      String? token;
      if (provider != null) {
        try {
          token = await provider(fingerprint);
        } catch (e) {
          debugPrint('OctopusSDK: bridge tokenProvider threw: $e');
          token = null;
        }
      }
      try {
        await OctopusSDKPlatform.instance.provideBridgeToken(requestId, token);
      } catch (e) {
        debugPrint('OctopusSDK: provideBridgeToken failed: $e');
      }
    }());
  }

  /// Handles a native `clientUserTokenRequest`: looks up the persistent Dart
  /// provider registered when connecting with a tokenProvider (see
  /// [connectUser]) under the request's
  /// `providerId`, awaits the freshly-signed JWT, and replies via
  /// [OctopusSDKPlatform.provideClientUserToken]. An empty token reply is the
  /// bridges' "no token available" signal (mirrors the bridge-token null-reply
  /// contract; see `_handleBridgeTokenRequest`).
  ///
  /// A missing provider (e.g. the user disconnected mid-refresh) and a
  /// throwing provider both reply with an empty token. What the host then sees
  /// differs by platform: Android refuses it locally as
  /// [ClientUserMissingTokenError], while iOS forwards it to the backend token
  /// exchange, so the failure comes back from that call and can be a
  /// connection-level `OctopusStatusError` rather than a [ClientUserError] —
  /// or not come back as a failure at all: on a first connect the native iOS
  /// SDK falls back to a guest connection and [connectUser] reports success
  /// (see its iOS caveat).
  /// [OctopusSDKPlatform.provideClientUserToken] is the canonical statement of
  /// this; keep the two in step.
  static void _handleClientUserTokenRequest(Map<String, dynamic> map) {
    final providerId = map['providerId'];
    final requestId = map['requestId'];
    if (providerId is! String || requestId is! String) return;
    final provider = _clientUserTokenProviders[providerId];
    unawaited(() async {
      String token = '';
      if (provider != null) {
        try {
          token = await provider();
        } catch (e) {
          debugPrint('OctopusSDK: clientUser tokenProvider threw: $e');
          token = '';
        }
      }
      try {
        await OctopusSDKPlatform.instance.provideClientUserToken(
          requestId,
          token,
        );
      } catch (e) {
        debugPrint('OctopusSDK: provideClientUserToken failed: $e');
      }
    }());
  }

  static Stream<Map<String, dynamic>> get eventStream {
    _initializeEventChannel();
    return _eventStreamController!.stream;
  }

  /// Reactive stream of typed SDK events.
  ///
  /// Emits [OctopusEvent] instances for content, interaction, gamification,
  /// navigation, click, profile, and session events from the native SDK.
  static Stream<OctopusEvent> get events {
    return eventStream
        .where((event) => event['event'] == 'sdkEvent')
        .map((event) => OctopusEvent.fromMap(event));
  }

  /// Initialize the Octopus SDK with SSO mode (your app manages user authentication)
  ///
  /// [apiKey] - Your Octopus Community API key
  /// [appManagedFields] - List of profile fields managed by your app instead of Octopus Community.
  ///
  /// This parameter allows you to specify which user profile fields should be managed
  /// by your application rather than by Octopus Community. When a field is in this list,
  /// users will not be able to edit it directly in the Octopus Community interface.
  /// Instead, your app should handle editing these fields through the [onModifyUser] callback.
  ///
  /// Example:
  /// ```dart
  /// await OctopusSDK().initialize(
  ///   apiKey: 'your-api-key',
  ///   appManagedFields: [ProfileField.nickname, ProfileField.picture, ProfileField.bio],
  /// );
  /// ```
  ///
  /// If empty or null, all fields will be managed by Octopus Community (default behavior).
  ///
  /// [apiServer] - Optional custom server endpoint the SDK targets. When `null`
  /// (default), the SDK uses the Octopus default endpoint over TLS. See
  /// [ApiServer] for the host validation rules.
  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) async {
    _initializeEventChannel();
    await OctopusSDKPlatform.instance.initialize(
      apiKey: apiKey,
      appManagedFields: appManagedFields,
      apiServer: apiServer,
    );
    // Keep the synchronous [isInitialised] getter accurate immediately after
    // this awaits, ahead of the native isInitialisedChanged event round-trip.
    _lastIsInitialised = true;
  }

  /// Initialize the Octopus SDK with Octopus Auth mode (Octopus manages user authentication)
  ///
  /// [apiKey] - Your Octopus Community API key
  /// [deepLink] - Optional deep link to reopen your app after magic link authentication
  /// Example: "com.yourapp.scheme://magic-link"
  /// [apiServer] - Optional custom server endpoint the SDK targets. When `null`
  /// (default), the SDK uses the Octopus default endpoint over TLS. See
  /// [ApiServer] for the host validation rules.
  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) async {
    _initializeEventChannel();
    await OctopusSDKPlatform.instance.initializeOctopusAuth(
      apiKey: apiKey,
      deepLink: deepLink,
      apiServer: apiServer,
    );
    _lastIsInitialised = true;
  }

  /// Switches the SDK to a different community in SSO mode.
  ///
  /// Use this when your app supports multiple communities (i.e. different API
  /// keys) and needs to switch between them at runtime. This disconnects the
  /// current user, clears all locally cached data, and reinitializes the SDK
  /// with the new community — equivalent to [reset] followed by [initialize].
  ///
  /// After switching, reconnect the user (via [connectUser]) and re-collect any
  /// active streams. Embedded UI should be torn down and rebuilt: give
  /// [OctopusHomeScreen] / [embeddedView] a `key: ValueKey(apiKey)` so Flutter
  /// recreates the native view for the new community.
  ///
  /// Parameters mirror [initialize].
  ///
  /// [apiKey] - The API key identifying the community to switch to.
  /// [appManagedFields] - Profile fields managed by your app. See [initialize].
  /// [apiServer] - Optional custom server endpoint. See [ApiServer].
  Future<void> switchCommunity({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) async {
    _initializeEventChannel();
    await OctopusSDKPlatform.instance.switchCommunity(
      apiKey: apiKey,
      appManagedFields: appManagedFields,
      apiServer: apiServer,
    );
    _lastIsInitialised = true;
  }

  /// Switches the SDK to a different community in Octopus Auth mode.
  ///
  /// The Octopus Auth counterpart to [switchCommunity]; mirrors
  /// [initializeOctopusAuth]. See [switchCommunity] for the switching semantics
  /// and the embedded-UI `key` recommendation.
  ///
  /// [apiKey] - The API key identifying the community to switch to.
  /// [deepLink] - Optional deep link to reopen your app after magic-link auth.
  /// [apiServer] - Optional custom server endpoint. See [ApiServer].
  Future<void> switchCommunityOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) async {
    _initializeEventChannel();
    await OctopusSDKPlatform.instance.switchCommunityOctopusAuth(
      apiKey: apiKey,
      deepLink: deepLink,
      apiServer: apiServer,
    );
    _lastIsInitialised = true;
  }

  /// Disconnects the current user and clears locally cached data without
  /// switching community.
  ///
  /// Ends the active session and returns the SDK to a clean state while keeping
  /// it **initialized** — use [switchCommunity] if you also need to change
  /// community, or [stop] to fully tear the SDK down.
  ///
  /// Platform note: on Android this also clears all SDK-stored data on the
  /// device (community content, cached images). iOS has no public cache-clearing
  /// API, so there it disconnects the user only.
  Future<void> reset() {
    return OctopusSDKPlatform.instance.reset();
  }

  /// Stops the SDK and releases all resources.
  ///
  /// Call this when the SDK is no longer needed. After this returns, the SDK is
  /// uninitialized ([isInitialised] is `false`) and [initialize] /
  /// [initializeOctopusAuth] must be called again before any further use. The
  /// native SDK cancels its ongoing operations; the Dart event streams (e.g.
  /// [events], [isInitialisedFlow]) stay open and [isInitialisedFlow] emits
  /// `false`.
  Future<void> stop() async {
    await OctopusSDKPlatform.instance.stop();
    _lastIsInitialised = false;
  }

  /// Whether the SDK is currently initialized.
  ///
  /// Returns `true` after [initialize] / [initializeOctopusAuth] /
  /// [switchCommunity] / [switchCommunityOctopusAuth] complete, and `false`
  /// before any initialization or after [stop]. [reset] does not change it.
  ///
  /// This is the synchronous complement to [isInitialisedFlow]. It reflects the
  /// last value observed from the native side (and is updated optimistically by
  /// the lifecycle methods above so it is accurate immediately after they
  /// await). For reactive UI, prefer [isInitialisedFlow].
  static bool get isInitialised {
    _initializeEventChannel();
    return _lastIsInitialised;
  }

  /// Reactive stream of the SDK initialization state.
  ///
  /// Emits `true` when the SDK becomes initialized and `false` when it is
  /// stopped. The current value is replayed immediately to late subscribers so
  /// a widget mounting after [initialize] still observes the state. Consecutive
  /// duplicate values are collapsed.
  static Stream<bool> get isInitialisedFlow {
    _initializeEventChannel();
    return buildIsInitialisedFlow(eventStream, _lastIsInitialised);
  }

  /// Returns a single-subscription stream that, on listen, subscribes to
  /// [values] **before** replaying the optional [seed] — closing the
  /// seed→listen gap where a value emitted between reading the cached seed and
  /// attaching the listener would be dropped (the underlying [eventStream] is a
  /// non-buffering broadcast). Mirrors the subscribe-then-emit ordering already
  /// used by [buildClientObjectPostStream].
  ///
  /// [seed] holds zero or one element: an empty iterable replays nothing (so a
  /// nullable seed value is distinguishable from "no value received yet"), a
  /// single element is replayed first. Because [seed] is replayed synchronously
  /// inside `onListen` — after the source subscription is live but before any
  /// microtask drains — it always lands ahead of a gap event, preserving the
  /// "current value first, then live changes" ordering.
  ///
  /// When [equals] is non-null, consecutive duplicate values — including a
  /// first live value equal to the replayed seed — are collapsed, matching each
  /// getter's documented "emits only on an actual change" contract.
  static Stream<T> _seedThenListen<T>(
    Stream<T> values, {
    required Iterable<T> seed,
    bool Function(T previous, T next)? equals,
  }) {
    late final StreamController<T> controller;
    StreamSubscription<T>? sub;
    var hasLast = false;
    late T last;
    void push(T value) {
      if (hasLast && equals != null && equals(last, value)) return;
      hasLast = true;
      last = value;
      controller.add(value);
    }

    controller = StreamController<T>(
      onListen: () {
        // Attach to the live source first so a value fired in the seed→listen
        // gap is captured, then replay the seed.
        sub = values.listen(
          push,
          onError: controller.addError,
          onDone: controller.close,
        );
        for (final value in seed) {
          push(value);
        }
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Builds the [isInitialisedFlow]: replays [seed] to the subscriber, then
  /// forwards the distinct boolean values carried by `isInitialisedChanged`
  /// events from [source]. Exposed for testing; production code should use
  /// [isInitialisedFlow].
  @visibleForTesting
  static Stream<bool> buildIsInitialisedFlow(
    Stream<Map<String, dynamic>> source,
    bool seed,
  ) =>
      _seedThenListen<bool>(
        source
            .where((event) => event['event'] == 'isInitialisedChanged')
            .map((event) => event['isInitialised'] as bool),
        seed: [seed],
        equals: (a, b) => a == b,
      );

  /// Embedded PlatformView widget to display native Octopus UI inside Flutter
  ///
  /// [navBarTitle] - Title displayed in the navigation bar
  /// [navBarPrimaryColor] - If true, uses the primary color for the navigation bar background
  /// [showBackButton] - If true, shows the back button in the navigation bar.
  ///   Renders the Android M3 leading back arrow directly; on iOS, backfills
  ///   to `OctopusNavBarLeadingAction.back` when [navBarLeadingAction] is
  ///   null. On both platforms an explicit [navBarLeadingAction] takes
  ///   precedence over this flag. The tap is surfaced as `backRequested`
  ///   (routed to [OctopusHomeScreen.onBack]) on both platforms.
  /// [titleCentered] - If true, centers the title in the native top app bar.
  ///   Supported on both platforms: Android maps it to the native
  ///   `OctopusHomeScreen(titleCentered:)` composable param, iOS to
  ///   `OctopusMainFeedTitle.Placement.center` on the main feed.
  /// [theme] - Custom theme for the interface
  /// [interceptUrls] - If true, urls opened inside the community are surfaced through the event stream
  /// [interceptProfileTaps] - If true, taps on **any** profile inside the
  ///   community (another member's or the connected user's own) are surfaced as
  ///   a `navigateToProfile` event carrying the tapped member's `clientUserId`,
  ///   and the SDK stops showing its native profile screens — the "Unified
  ///   Profile" activation switch. Routed to
  ///   [OctopusHomeScreen.onNavigateToProfile]; hosts pass a callback there
  ///   rather than setting this flag by hand.
  ///
  ///   **Activation is an AND gate**: nothing changes unless the community is
  ///   also configured to expose client user ids. A member with no client user
  ///   id (a guest, or a back-office-created profile) opens the Octopus activity
  ///   screen instead, so the event never carries a null id.
  ///
  ///   Leave it `false` (the default) to keep the SDK's native profile screens —
  ///   existing behaviour, unchanged.
  /// [hasModifyUserHandler] - Whether the host wired a profile-edit handler
  ///   ([OctopusHomeScreen.onModifyUser]). **iOS-only**, and only meaningful
  ///   together with [interceptProfileTaps]: the Unified Profile activity screen
  ///   shows its "Edit my profile" item only when the native
  ///   `onNavigateToProfileEditCallback` is wired, so passing `false` keeps that
  ///   item hidden rather than letting it dead-end in a host that has no handler.
  ///   Android wires its equivalent unconditionally (one native parameter serves
  ///   both edit paths there), so the flag is ignored on Android.
  /// [notification] - Push notification whose deep-link target the native view should open
  /// [showNavBar] - If `false`, the native SDK navigation chrome (top app bar)
  ///   is hidden so the host app can render its own title. Mirrors
  ///   `OctopusHomeContent` on Android (no top bar variant). **iOS asymmetry:**
  ///   the iOS pod 1.12.0 does not expose a no-navbar variant — when `false`,
  ///   the native iOS top bar still renders (tracked internally).
  /// [initialScreen] - The initial screen to display when the view mounts.
  ///   Defaults to the main feed. If a non-null [notification] also carries a
  ///   non-empty `linkPath`, the deep link wins and [initialScreen] is
  ///   ignored. See [OctopusInitialScreen].
  /// [navigationMode] - Which navigation container the native iOS SDK uses
  ///   internally. Defaults to [OctopusNavigationMode.navigationStack] —
  ///   the Flutter wrapper's default deliberately differs from the native iOS
  ///   default ([OctopusNavigationMode.automatic], which currently maps to
  ///   the legacy `NavigationView`) because every Flutter host is by
  ///   definition a UIKit-hosted controller, and the legacy `NavigationView`
  ///   silently drops sub-navigation pushes when the SwiftUI tree is
  ///   reparented (modal routes / hot reload / push-from-elsewhere).
  ///   Pass [OctopusNavigationMode.automatic] explicitly to opt back into
  ///   the native default. **iOS-only** (wrapped iOS SDK 1.12.2+); a no-op
  ///   on Android. See [OctopusNavigationMode].
  /// [navBarLeadingAction] - Requests a native host-driven close / back button
  ///   on the SDK's root screen whose tap is surfaced as a `backRequested`
  ///   event (routed to [OctopusHomeScreen.onBack]). Defaults to `null`.
  ///   **Supported on both platforms:** Android maps it to the native
  ///   `OctopusHomeScreen(leadingNavigationIcon:)` (wrapped native SDK 1.12.1+),
  ///   iOS to `OctopusHomeScreen(navBarLeadingAction:)` (wrapped iOS SDK
  ///   1.12.2+). When `null`, each platform keeps its existing root leading icon
  ///   (a back arrow gated by [showBackButton]). See
  ///   [OctopusNavBarLeadingAction].
  ///
  /// **Gesture handling (both platforms)** — pointer events landing inside the
  /// embedded view are dispatched directly to the native side via an
  /// `EagerGestureRecognizer`, so the SDK's internal scroll (the feed) wins
  /// vertical drags and the embedded UI's own taps / long-press / swipe-to-
  /// react work as designed — including inside a `showModalBottomSheet`, where
  /// the modal route's drag-to-dismiss would otherwise steal the vertical drag
  /// (on iOS as well, despite UIKit's recognizer delegation —
  /// flutter/flutter#26425, #66270). As a consequence, ancestor Flutter gesture
  /// recognizers — a parent `ListView`/`PageView`/`TabBarView`, a draggable
  /// modal without an explicit drag-handle, an `InteractiveViewer` — will
  /// NOT see pointers whose finger lands inside the embedded view's bounds
  /// (horizontal swipes included). Hosts that need the parent to win must
  /// expose the affordance OUTSIDE the embedded view: Material 3's
  /// `showDragHandle: true` on `showModalBottomSheet`, an explicit close
  /// button, the back chevron via [showBackButton], or a layout where the
  /// parent's gesture area doesn't overlap the SDK.
  ///
  /// **Bottom padding** — `bottomSafeAreaInset` is the *total* bottom padding
  /// reserved inside the embedded view, resolved from this widget's mount point
  /// when left at its `0` default. See
  /// [OctopusHomeScreen.bottomSafeAreaInset] for the contract.
  static Widget embeddedView({
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    bool showBackButton = true,
    bool titleCentered = false,
    OctopusTheme? theme,
    bool interceptUrls = false,
    bool interceptProfileTaps = false,
    bool hasModifyUserHandler = false,
    OctopusNotification? notification,
    double bottomSafeAreaInset = 0,
    bool showNavBar = true,
    OctopusInitialScreen? initialScreen,
    OctopusNavigationMode navigationMode =
        OctopusNavigationMode.navigationStack,
    OctopusNavBarLeadingAction? navBarLeadingAction,
  }) {
    const viewType = 'octopus_sdk_flutter/native_view';

    _initializeEventChannel();

    final creationParams = <String, dynamic>{
      if (navBarTitle != null) 'navBarTitle': navBarTitle,
      'navBarPrimaryColor': navBarPrimaryColor,
      'showBackButton': showBackButton,
      // Emit only the non-default (true); the native bridges default to
      // `false` when the key is absent, matching `showNavBar`'s wire pattern.
      if (titleCentered) 'titleCentered': true,
      'interceptUrls': interceptUrls,
      // Emit only the non-default (true): absence must read as "the host wired
      // nothing", which is what keeps the SDK's native profile screens. This is
      // the Unified Profile activation switch — see [interceptProfileTaps].
      if (interceptProfileTaps) 'interceptProfileTaps': true,
      if (hasModifyUserHandler) 'hasModifyUserHandler': true,
      // `bottomSafeAreaInset` is deliberately absent here: it depends on the
      // mount point's ambient padding, so it is resolved and added inside the
      // `Builder` below.
      if (!showNavBar) 'showNavBar': false,
      // `navigationMode` is consumed by the iOS bridge only (Android ignores
      // it). It is always emitted so the bridge sees the host's explicit choice:
      // the Flutter wrapper's default differs from the native iOS `.automatic`
      // default, so the bridge needs the wire value to know which one the host
      // picked.
      'navigationMode': navigationMode.name,
      // `navBarLeadingAction` is consumed by BOTH bridges (Android maps it to
      // the native `leadingNavigationIcon`, wrapped native SDK 1.12.1+; iOS to
      // `navBarLeadingAction`, 1.12.2+). Emit only the non-null value: both
      // bridges default to no override when the key is absent, matching the
      // `titleCentered` / `showNavBar` "emit only non-default" wire pattern.
      if (navBarLeadingAction != null)
        'navBarLeadingAction': navBarLeadingAction.name,
      if (theme != null) ...theme.toMap(),
      ...creationParamsFor(
        notification: notification,
        initialScreen: initialScreen,
      ),
    };

    // Eagerly claim every pointer that lands on the embedded platform view so
    // the SDK's internal scroll (the native feed / LazyColumn) wins vertical
    // drags over any ancestor Flutter recognizer — most importantly a
    // `showModalBottomSheet`'s drag-to-dismiss, but also a parent `ListView`.
    // Without it the platform view only sees pointers no Flutter ancestor has
    // claimed, and a bottom-sheet parent steals every vertical drag, leaving
    // the native feed unscrollable inside the sheet.
    //
    // Required on BOTH platforms. iOS was previously left without it, on the
    // assumption that UIKit's gesture-recognizer delegation lets the inner
    // `UIScrollView` win automatically — but inside a Flutter
    // `showModalBottomSheet` the modal route's pan recognizer wins the vertical
    // drag on iOS too, so the embedded feed could not be scrolled there
    // (flutter/flutter#26425, #66270). Claiming eagerly on iOS as well makes
    // scrolling work and brings the two platforms in line.
    //
    // Trade-off (both platforms): ancestor recognizers won't see pointers that
    // land inside the embedded view (horizontal swipes included), so hosts must
    // expose dismiss / navigation affordances OUTSIDE it — Material 3's
    // `showDragHandle: true`, an explicit close button, or the back chevron via
    // [showBackButton].
    final gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    };

    // `bottomSafeAreaInset` is resolved HERE, at the mount point, and nowhere
    // else: every public entry path (the four embedded widgets, and the two
    // top-level helpers through them) funnels into this method, so a single
    // resolution covers them all.
    //
    // Three states, and the `> 0` gate below is load-bearing:
    //  - a value > 0 reaches the wire exactly as the host asked;
    //  - the default `0` means "resolve from the mount point" — whatever the
    //    ambient `MediaQuery` still has left to reserve. That is what keeps the
    //    native floating "Write a post" pill clear of the Android system
    //    navigation bar on edge-to-edge devices (API 35+) when a host mounts
    //    one of these widgets full-screen without passing anything;
    //    (under `Scaffold(extendBody: true)` that is the bottom bar's height,
    //    which `Scaffold` re-injects into the body's `padding` — the very case
    //    this parameter exists for, since the view runs behind the bar there);
    //  - a *resolved* 0 — an ancestor `SafeArea` / bottom nav already consumed
    //    the padding, or the device has no bottom inset — drops the key, which
    //    is what tells the iOS bridge "the host expressed no preference", so it
    //    keeps its historical additive 10 pt default instead of collapsing to
    //    the 0.01 pt gate floor and shifting every existing iOS layout. See
    //    `SafeHostingContainerView.requestedBottomSafeAreaInset`.
    //
    // The resolution is ANDROID-ONLY, and that asymmetry is deliberate. The bug
    // it fixes only exists there: the Android bridge consumes the system-bar
    // insets before mounting the native view, so nothing reserves the bottom and
    // the pill sits behind the navigation bar. On iOS the embedded view already
    // sits inside the safe area, so there is nothing to fix — and resolving
    // anyway would actively hurt. Since 1.13.0 the iOS bridge reads the value as a
    // *total* and subtracts the safe area the view occupies: a resolved 34 over a
    // 34 pt inset gives `max(max(0, 34 - 34), 0.01)` = 0.01 pt, while an absent
    // key gives the bridge's historical additive 10 pt. iOS would gain nothing
    // and lose 10 pt above the home indicator, on the *default* full-screen
    // mount. Inferring a preference the host never expressed must not override a
    // native default that is already correct — which is exactly what the
    // key-absent state exists to protect.
    //
    // A host that wants to reserve nothing at all wraps the widget in
    // `MediaQuery.removePadding(context: context, removeBottom: true)`; that is
    // the documented opt-out, and it is how the two top-level helpers honour
    // their own "pass `0` to opt back into the previous edge-to-edge look"
    // contract. Note that it takes an ancestor which *consumes* the MediaQuery
    // padding to opt out — a plain `Padding`, a `Column` above a fixed footer or
    // a `Stack` overlay pads the layout without consuming anything, so those
    // shapes still resolve the full inset. See `_ambientBottomInset`.
    //
    // The `Builder` is UNCONDITIONAL. A wrapper that comes and goes between
    // rebuilds reparents the PlatformView, which disposes and recreates the
    // native view — the SDK then restarts on its main feed (see the tree-shape
    // warning in `OctopusHomeScreen.build`). Reading the ambient
    // `MediaQuery` also means a padding change (keyboard, rotation) rebuilds
    // this Builder: `creationParams` is consumed once at creation time, so such
    // a rebuild reconfigures nothing and never recreates the native view.
    return Builder(
      builder: (context) {
        final resolvedBottomInset = bottomSafeAreaInset > 0
            ? bottomSafeAreaInset
            : defaultTargetPlatform == TargetPlatform.android
                ? _ambientBottomInset(context)
                : 0.0;
        final params = resolvedBottomInset > 0
            ? <String, dynamic>{
                ...creationParams,
                'bottomSafeAreaInset': resolvedBottomInset,
              }
            : creationParams;
        return defaultTargetPlatform == TargetPlatform.iOS
            ? UiKitView(
                viewType: viewType,
                creationParams: params,
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers: gestureRecognizers,
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              )
            : defaultTargetPlatform == TargetPlatform.android
                ? AndroidView(
                    viewType: viewType,
                    creationParams: params,
                    creationParamsCodec: const StandardMessageCodec(),
                    gestureRecognizers: gestureRecognizers,
                    hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  )
                : const SizedBox.shrink();
      },
    );
  }

  /// The bottom padding still left to reserve at [context], used to resolve
  /// `bottomSafeAreaInset` **on Android** when the host left it at `0` or below.
  ///
  /// iOS deliberately does not resolve: its embedded view already sits inside the
  /// safe area, and since 1.13.0 its bridge treats the value as a total and
  /// subtracts that safe area — so an inferred value would replace the bridge's
  /// additive 10 pt default with ~0 and lose height for nothing. See the state
  /// table in [embeddedView].
  ///
  /// Reads `padding.bottom`, which reports what is LEFT once ancestors consumed
  /// their share. That is what makes a widget mounted inside a `SafeArea` — or
  /// under an explicit `MediaQuery.removePadding` — resolve to 0 instead of
  /// double-reserving. It is also the only field carrying a `Scaffold`
  /// `bottomNavigationBar`'s height under `extendBody: true`: the bar height is
  /// re-injected into `padding` there while `viewPadding.bottom` is zeroed, so
  /// reading `viewPadding` would silently drop a host bottom bar.
  ///
  /// **Known limitation.** While a keyboard is up the engine folds the bottom
  /// inset into `viewInsets` and reports `padding.bottom == 0`. Creation params
  /// are consumed once, at creation, so a widget first built in that state keeps
  /// `0` for its whole life. This applies to **every** host, a `Scaffold` body
  /// included: `resizeToAvoidBottomInset` zeroes `viewInsets` for the body, but
  /// `MediaQueryData.removeViewInsets` only zeroes `viewInsets` and lowers
  /// `viewPadding` — it never writes `padding` at all, so the `padding.bottom`
  /// the engine already folded to 0 stays 0. Verified by measurement on a plain
  /// `Scaffold` body, an `extendBody: true` body, and `resizeToAvoidBottomInset:
  /// false`; all report 0 at the mount point.
  ///
  /// It is not fixable from here: at that moment "an ancestor consumed the
  /// padding" and "the keyboard folded it away" are indistinguishable — both
  /// report `padding.bottom == 0` over an ambient `viewPadding` that still holds
  /// the device inset — so falling back to `viewPadding` would break the
  /// documented opt-out and make a `SafeArea` host double-reserve permanently,
  /// which is strictly worse than the narrow case it would fix. A host that may
  /// mount the SDK with the keyboard already up should pass the inset explicitly.
  /// Note this is a missed improvement rather than a regression: these widgets
  /// resolved nothing at all before, so such a mount behaves as it always did.
  ///
  /// `maybePaddingOf` keeps this from throwing, but the `?? 0` is unreachable in
  /// practice: a mounted tree always has a `MediaQuery`, since Flutter's `View`
  /// widget derives one from the `FlutterView` even when the host inserted none.
  /// The opt-out wrap in [showOctopusHomeScreen] leans on that same guarantee —
  /// `MediaQuery.removePadding` resolves through `MediaQuery.of` and would throw
  /// without one.
  static double _ambientBottomInset(BuildContext context) =>
      MediaQuery.maybePaddingOf(context)?.bottom ?? 0;

  /// Returns the notification + initial-screen portion of the platform-view
  /// creation params. Exposed for testability — production code should call
  /// [embeddedView] which composes this in.
  ///
  /// Both keys are emitted side-by-side when supplied; the precedence rule
  /// (`linkPath` wins over `initialScreen`) is applied by each native bridge,
  /// not stripped here, so this helper documents the exact wire shape the
  /// bridges receive.
  @visibleForTesting
  static Map<String, dynamic> creationParamsFor({
    OctopusNotification? notification,
    OctopusInitialScreen? initialScreen,
  }) {
    return <String, dynamic>{
      if (notification != null) ...{
        if (notification.linkPath.isNotEmpty) 'linkPath': notification.linkPath,
        'notificationUserInfo': notification.rawPayload,
      },
      if (initialScreen != null) 'initialScreen': initialScreen.toMap(),
    };
  }

  /// Builds the platform-channel args passed to `showOctopusCreatePostScreen`.
  /// Exposed for testability — production code should call
  /// [showOctopusCreatePostScreen]. The prefill payload is carried verbatim
  /// under `prefilledPost` (reusing [CreatePostScreenInfo.toMap]); the theme
  /// keys are flattened in, matching [embeddedView].
  ///
  /// When [bridgeTokenRequestId] is non-null, the host supplied a
  /// [CreatePostScreenInfo.bridgeShareTokenProvider]; the id and a
  /// `hasBridgeShareTokenProvider` flag are added so the native editor can
  /// request a signature back over the event channel at publish time (same
  /// round-trip as [fetchOrCreateClientObjectRelatedPost]). Both keys are
  /// honoured on Android and iOS — the native iOS editor wires them to
  /// `OctopusPrefilledPost.sign`.
  @visibleForTesting
  static Map<String, dynamic> createPostScreenArgs({
    CreatePostScreenInfo? info,
    OctopusTheme? theme,
    String? bridgeTokenRequestId,
  }) {
    return <String, dynamic>{
      if (theme != null) ...theme.toMap(),
      ...(info ?? const CreatePostScreenInfo()).toMap(),
      if (bridgeTokenRequestId != null) ...<String, dynamic>{
        'bridgeTokenRequestId': bridgeTokenRequestId,
        'hasBridgeShareTokenProvider': true,
      },
    };
  }

  /// Connect a user to the Octopus SDK.
  ///
  /// Note: You must call initialize() before connecting a user.
  ///
  /// Provide a [tokenProvider]: the SDK invokes it whenever it needs a signed
  /// JWT to authenticate the user — initially (on connect) **and** on every
  /// subsequent refresh (e.g. [refreshEntitlements] minting a fresh JWT with
  /// the host's current entitlement set). This mirrors the single native
  /// `OctopusSDK.connectUser(user, tokenProvider:)` contract on Android and
  /// iOS, and is what lets [refreshEntitlements] succeed. The provider is
  /// unregistered automatically by [disconnectUser]. Connecting again makes the
  /// new provider the one the native SDK uses (it holds a single callback), but
  /// the Dart side keeps every prior registration reachable until
  /// [disconnectUser] clears them, so a native refresh still targeting an
  /// earlier registration gets answered instead of receiving an empty token.
  ///
  /// [userId] - Unique identifier for the user.
  /// [tokenProvider] - Async callback returning a freshly-signed JWT (get it
  ///   from your backend). The SDK may call it more than once.
  /// [nickname] - User's display name (optional).
  /// [bio] - User's bio (optional).
  /// [picture] - User's profile picture URL or base64 (optional).
  /// [token] - **Deprecated.** A pre-minted static JWT. Prefer [tokenProvider]:
  ///   a static token cannot be re-minted when the SDK re-authenticates the
  ///   user (e.g. [refreshEntitlements]), so it fails once the JWT expires. To
  ///   migrate, wrap your token in a provider: `tokenProvider: () async => t`.
  ///
  /// Exactly one of [tokenProvider] or [token] must be provided.
  ///
  /// ## Result
  ///
  /// Returns an [OctopusResult]: **the connection can be refused** (banned
  /// user, JWT the backend rejects, missing token) and a refusal is not an
  /// exception — inspect the result rather than assuming success, or the user
  /// stays anonymous while your app believes them connected.
  ///
  /// ```dart
  /// final result = await octopus.connectUser(userId: id, tokenProvider: p);
  /// switch (result) {
  ///   case OctopusSuccess():
  ///     // connected
  ///     break;
  ///   case OctopusInvalidArguments(errors: final errors):
  ///     for (final e in errors) {
  ///       switch (e) {
  ///         case ClientUserBannedError():
  ///           showBanned(e.errorMessage); // backend wording, displayable
  ///         default:
  ///           showGenericError(e.errorMessage);
  ///       }
  ///     }
  ///   case OctopusNoNetwork():
  ///     showOffline();
  ///   default:
  ///     showGenericError('$result');
  /// }
  /// ```
  ///
  /// The [ClientUserError] variants are **not symmetric across platforms** —
  /// see the table on [ClientUserError] for who emits what.
  ///
  /// The inner `switch` above singles out one leaf, so it is non-exhaustive and
  /// the `default` is required. Enumerate every leaf instead — after narrowing
  /// with `errors.cast<ClientUserError>()` — and you must drop it: the
  /// hierarchy is sealed, so a catch-all over a complete switch is a fatal
  /// analyzer warning. [ClientUserError] carries the rule and the reason you do
  /// not need a catch-all for robustness.
  ///
  /// **iOS caveat — an [OctopusSuccess] does not prove the SSO user is
  /// connected.** When the token exchange fails while nothing is connected yet
  /// (the ordinary first login), the native SDK falls back to a **guest**
  /// connection and returns normally, so this bridge has no refusal to report.
  /// The refusal does arrive when a connection already existed. Android has no
  /// such fallback. This cannot be fixed from the bridge, but the two states are
  /// observable — through streams, which emit independently of this `Future`:
  /// [isUserConnected] emits `false` under the guest fallback, and
  /// [connectionState] emits [OctopusConnected] with `isGuest: true`. Subscribe
  /// rather than sampling right after this call returns — see MIGRATING.md.
  @useResult
  Future<OctopusResult<void, ClientUserError>> connectUser({
    required String userId,
    Future<String> Function()? tokenProvider,
    String? nickname,
    String? bio,
    String? picture,
    @Deprecated(
      'Use tokenProvider instead. A static token cannot be re-minted when the '
      'SDK re-authenticates the user (e.g. refreshEntitlements), so it fails '
      'once the JWT expires. Will be removed in a future major version.',
    )
    String? token,
  }) {
    if (tokenProvider != null && token != null) {
      throw ArgumentError(
        'connectUser requires exactly one of `tokenProvider` or `token`, '
        'not both.',
      );
    }
    if (tokenProvider != null) {
      return _connectUserWithTokenProvider(
        userId: userId,
        tokenProvider: tokenProvider,
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
    }
    if (token == null) {
      throw ArgumentError(
        'connectUser requires either `tokenProvider` or `token`.',
      );
    }
    return OctopusSDKPlatform.instance.connectUser(
      userId: userId,
      token: token,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
  }

  /// Connect a user with a **persistent** token provider.
  ///
  /// Deprecated: call [connectUser] with its `tokenProvider` parameter instead
  /// — same behavior, one canonical entry point that matches the native
  /// `OctopusSDK.connectUser(user, tokenProvider:)` shape.
  ///
  /// Returns the same [OctopusResult] as [connectUser]; see that method for
  /// how to handle a refusal.
  @Deprecated(
    'Use connectUser(tokenProvider:) instead. '
    'Will be removed in a future major version.',
  )
  @useResult
  Future<OctopusResult<void, ClientUserError>> connectUserWithTokenProvider({
    required String userId,
    required Future<String> Function() tokenProvider,
    String? nickname,
    String? bio,
    String? picture,
  }) {
    return _connectUserWithTokenProvider(
      userId: userId,
      tokenProvider: tokenProvider,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
  }

  /// Shared implementation behind [connectUser] (with a `tokenProvider`) and
  /// the deprecated `connectUserWithTokenProvider`. Registers the persistent
  /// provider under a unique `providerId` (so the native side can round-trip
  /// back to Dart on every refresh) and connects via the platform. Rolls the
  /// registration back if the platform call throws.
  Future<OctopusResult<void, ClientUserError>> _connectUserWithTokenProvider({
    required String userId,
    required Future<String> Function() tokenProvider,
    String? nickname,
    String? bio,
    String? picture,
  }) async {
    _initializeEventChannel();
    _clientUserTokenProviderCounter++;
    final providerId =
        'clientUserTokenProvider_${_clientUserTokenProviderCounter}_$userId';
    _clientUserTokenProviders[providerId] = tokenProvider;
    try {
      final result =
          await OctopusSDKPlatform.instance.connectUserWithTokenProvider(
        userId: userId,
        providerId: providerId,
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
      // The provider is deliberately kept registered whatever the outcome —
      // it is dropped only by disconnectUser(), or below if the platform call
      // itself throws. Both native SDKs assign their own tokenProvider
      // reference *before* attempting the connection, never clear it on
      // failure, and re-invoke it on every later refresh, so a Dart-side drop
      // here would desynchronize the two: the next native round-trip would
      // answer an empty token, permanently. A refusal is not a reason to
      // unregister either — several are raised with the user already
      // connected (Android returns `checkProfileUpdates` *after* saving the
      // session, so a rejected nickname surfaces as a profile error on a live
      // connection) and iOS folds transient failures into the same branch.
      return result;
    } catch (_) {
      _clientUserTokenProviders.remove(providerId);
      rethrow;
    }
  }

  /// Disconnect the current user from the Octopus SDK
  Future<void> disconnectUser() async {
    // Clear any registered persistent client-user tokenProvider so a native
    // refresh after disconnect can't call into a stale closure. The native
    // SDK side detaches its own provider on disconnect; this just keeps
    // Dart's map in sync.
    _clientUserTokenProviders.clear();
    await OctopusSDKPlatform.instance.disconnectUser();
  }

  /// Reactive stream of unseen notification count
  ///
  /// Emits the current count whenever it changes on the native side.
  /// If a value was already received before subscribing, it is replayed
  /// immediately so that late subscribers don't miss the initial count.
  /// Listen to this stream to update a badge indicator in your UI.
  static Stream<int> get notSeenNotificationsCount {
    _initializeEventChannel();
    return buildNotSeenNotificationsCountStream(
      eventStream,
      _lastNotSeenNotificationsCount != null,
      _lastNotSeenNotificationsCount ?? 0,
    );
  }

  /// Builds the [notSeenNotificationsCount] stream: replays the cached count
  /// (when [hasSeed]) to the subscriber, then forwards every count carried by
  /// `notSeenNotificationsCountChanged` events from [source]. No
  /// de-duplication — matches the getter's "emits the current count whenever it
  /// changes" contract. Exposed for testing; production code should use
  /// [notSeenNotificationsCount].
  @visibleForTesting
  static Stream<int> buildNotSeenNotificationsCountStream(
    Stream<Map<String, dynamic>> source,
    bool hasSeed,
    int seed,
  ) =>
      _seedThenListen<int>(
        source
            .where(
                (event) => event['event'] == 'notSeenNotificationsCountChanged')
            .map((event) => event['count'] as int),
        seed: hasSeed ? [seed] : const <int>[],
      );

  /// Force refresh the unseen notification count from the server
  Future<void> updateNotSeenNotificationsCount() {
    return OctopusSDKPlatform.instance.updateNotSeenNotificationsCount();
  }

  /// Reactive stream indicating whether the current user has access to the community
  ///
  /// Useful for A/B testing or gating community features.
  /// If a value was already received before subscribing, it is replayed
  /// immediately so that late subscribers don't miss the initial value.
  static Stream<bool> get hasAccessToCommunity {
    _initializeEventChannel();
    return buildHasAccessToCommunityStream(
      eventStream,
      _lastHasAccessToCommunity != null,
      _lastHasAccessToCommunity ?? false,
    );
  }

  /// Builds the [hasAccessToCommunity] stream: replays the cached access flag
  /// (when [hasSeed]) to the subscriber, then forwards the booleans carried by
  /// `hasAccessToCommunityChanged` events from [source]. Exposed for testing;
  /// production code should use [hasAccessToCommunity].
  @visibleForTesting
  static Stream<bool> buildHasAccessToCommunityStream(
    Stream<Map<String, dynamic>> source,
    bool hasSeed,
    bool seed,
  ) =>
      _seedThenListen<bool>(
        source
            .where((event) => event['event'] == 'hasAccessToCommunityChanged')
            .map((event) => event['hasAccess'] as bool),
        seed: hasSeed ? [seed] : const <bool>[],
      );

  /// Reactive stream of the connected user's public [OctopusProfile], or `null`
  /// when no user is connected.
  ///
  /// Emits whenever the profile changes — including when entitlements are
  /// refreshed via [refreshEntitlements]. Consecutive duplicate values are
  /// collapsed, so it emits only on an actual change (consistent on Android and
  /// iOS). If a value was already received before subscribing, it is replayed
  /// immediately so late subscribers don't miss it. Mirrors the native
  /// `OctopusSDK.profile`.
  static Stream<OctopusProfile?> get profile {
    _initializeEventChannel();
    return buildProfileStream(eventStream, _hasReceivedProfile, _lastProfile);
  }

  /// Builds the [profile] stream: replays [seed] (only if [hasReceived], since
  /// `null` is a valid profile value) to the subscriber, then forwards the
  /// [OctopusProfile]/`null` carried by `profileChanged` events from [source],
  /// collapsing consecutive duplicate values.
  ///
  /// The de-duplication normalises a native asymmetry at the Flutter layer:
  /// Android's `profile` Flow is already `distinctUntilChanged`, while iOS's
  /// `@Published profile` re-emits on every assignment. Both platforms therefore
  /// expose the same "emits only on actual change" contract here. Exposed for
  /// testing; production code should use [profile].
  @visibleForTesting
  static Stream<OctopusProfile?> buildProfileStream(
    Stream<Map<String, dynamic>> source,
    bool hasReceived,
    OctopusProfile? seed,
  ) =>
      _seedThenListen<OctopusProfile?>(
        source
            .where((event) => event['event'] == 'profileChanged')
            .map((event) {
          final raw = event['profile'];
          return raw is Map ? OctopusProfile.fromWire(raw) : null;
        }),
        seed: hasReceived ? [seed] : const <OctopusProfile?>[],
        equals: (a, b) => a == b,
      );

  /// Reactive stream of the community's [OctopusGroup]s (content categories the
  /// user can browse and follow).
  ///
  /// Emits whenever the group list changes (follow/unfollow, admin updates, …).
  /// Consecutive duplicate lists are collapsed, so it emits only on an actual
  /// change. The latest list is replayed to late subscribers. Emits an empty
  /// list when there are no groups. Mirrors the native `OctopusSDK.groups`.
  static Stream<List<OctopusGroup>> get groups {
    _initializeEventChannel();
    return buildGroupsStream(eventStream, _lastGroups);
  }

  /// Builds the [groups] stream: replays [seed] (the cached list, if any) to the
  /// subscriber, then forwards the lists carried by `groupsChanged` events from
  /// [source], collapsing consecutive duplicates. Exposed for testing;
  /// production code should use [groups].
  @visibleForTesting
  static Stream<List<OctopusGroup>> buildGroupsStream(
    Stream<Map<String, dynamic>> source,
    List<OctopusGroup>? seed,
  ) =>
      _seedThenListen<List<OctopusGroup>>(
        source
            .where((event) => event['event'] == 'groupsChanged')
            .map((event) => _decodeGroups(event['groups'])),
        seed: seed != null ? [seed] : const <List<OctopusGroup>>[],
        equals: (a, b) => listEquals(a, b),
      );

  static List<OctopusGroup> _decodeGroups(Object? raw) => <OctopusGroup>[
        if (raw is List)
          for (final g in raw.whereType<Map>()) OctopusGroup.fromWire(g),
      ];

  /// Reactive stream of the current [OctopusConnectionState].
  ///
  /// Emits whenever the user transitions between connected and not-connected
  /// (and whenever the guest flag flips). Consecutive duplicate values are
  /// collapsed, so it emits only on an actual change. The latest snapshot is
  /// replayed to late subscribers. Mirrors the native Android
  /// `OctopusSDK.connectionState`; on iOS, the value is derived from the
  /// `profile` publisher and the guest flag is read from `OctopusProfile.isGuest`
  /// (native iOS 1.12.6+ — see [OctopusConnected.isGuest]).
  static Stream<OctopusConnectionState> get connectionState {
    _initializeEventChannel();
    return buildConnectionStateStream(eventStream, _lastConnectionState);
  }

  /// Builds the [connectionState] stream: replays [seed] to the subscriber when
  /// non-null, then forwards the [OctopusConnectionState] carried by
  /// `connectionStateChanged` events from [source], collapsing consecutive
  /// duplicates. Exposed for testing; production code should use
  /// [connectionState].
  @visibleForTesting
  static Stream<OctopusConnectionState> buildConnectionStateStream(
    Stream<Map<String, dynamic>> source,
    OctopusConnectionState? seed,
  ) =>
      _seedThenListen<OctopusConnectionState>(
        source
            .where((event) => event['event'] == 'connectionStateChanged')
            .map(_decodeConnectionState),
        seed: seed != null ? [seed] : const <OctopusConnectionState>[],
        equals: (a, b) => a == b,
      );

  /// Reactive convenience stream derived from [connectionState]: `true` only
  /// when a fully authenticated (non-guest) user is connected.
  ///
  /// `true` iff a connected, non-guest user is present — on both platforms.
  /// (iOS distinguishes guest sessions since native SDK 1.12.6; older iOS SDKs
  /// reported every connection as non-guest.) Consecutive duplicate values are
  /// collapsed; the latest value is replayed to late subscribers. Mirrors the
  /// native Android `OctopusSDK.isUserConnected`.
  static Stream<bool> get isUserConnected =>
      buildIsUserConnectedStream(connectionState);

  /// Maps a stream of [OctopusConnectionState] snapshots to the derived
  /// non-guest connected flag, collapsing consecutive duplicate booleans.
  /// Exposed for testing; production code should use [isUserConnected].
  @visibleForTesting
  static Stream<bool> buildIsUserConnectedStream(
    Stream<OctopusConnectionState> source,
  ) =>
      source
          .map((state) => state is OctopusConnected && !state.isGuest)
          .distinct();

  static OctopusConnectionState _decodeConnectionState(
    Map<String, dynamic> event,
  ) {
    final connected = event['connected'] == true;
    if (!connected) return const OctopusNotConnected();
    return OctopusConnected(isGuest: event['isGuest'] == true);
  }

  /// Override the community access cohort attribution.
  ///
  /// [hasAccess] - Whether the user should have access to the community.
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] on success, or an
  /// [OctopusFailure] (an [OctopusConnectionFailure] such as [OctopusNoNetwork],
  /// or an [OctopusInvalidArguments] carrying [OverrideCommunityAccessError]s).
  /// This does **not** throw on a handled SDK failure — pattern-match or use the
  /// helpers ([OctopusResultExtensions.onSuccess], `getOrElse`, …).
  ///
  /// **Breaking change in 1.12.0**: previously returned `Future<void>`.
  /// Ignoring the result is not flagged by the analyzer, so a failure here is
  /// silent unless you read it.
  Future<OctopusResult<void, OverrideCommunityAccessError>>
      overrideCommunityAccess(bool hasAccess) {
    return OctopusSDKPlatform.instance.overrideCommunityAccess(hasAccess);
  }

  /// Refreshes the current user's community entitlements from the backend.
  ///
  /// Only supported in SSO mode with a connected (non-guest) user and a
  /// registered token provider. Returns an [OctopusResult]: [OctopusSuccess] on
  /// success, or an [OctopusInvalidArguments] carrying a typed
  /// [RefreshEntitlementsError] (`NoClientTokenProvider`, `UserNotConnected`,
  /// `NoNetwork`, `UserBanned` — message is BE-provided and displayable — or
  /// `ServerError`). Does not throw on a handled SDK failure.
  Future<OctopusResult<void, RefreshEntitlementsError>> refreshEntitlements() {
    return OctopusSDKPlatform.instance.refreshEntitlements();
  }

  /// Sets (or removes) the connected user's reaction on a post.
  ///
  /// Works on **any** post the current user can see — both bridge posts and
  /// community posts.
  ///
  /// [reaction] - the reaction to set, or `null` to remove the current
  /// reaction. Use the [OctopusReactionKind] singletons
  /// (`OctopusReactionKind.heart`, `.joy`, `.mouthOpen`, `.clap`, `.cry`,
  /// `.rage`). Passing an [OctopusUnknownReaction] is not supported and fails
  /// with [SetReactionUnknownReactionError].
  ///
  /// [postId] - the id of the post to react on (`OctopusPost.id`).
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] on success, or an
  /// [OctopusFailure]. Business failures are an [OctopusInvalidArguments]
  /// carrying a typed [SetReactionError]
  /// ([SetReactionUnknownReactionError], [SetReactionPostNotFoundError],
  /// [SetReactionReactionError]); transport/auth failures surface through the
  /// [OctopusConnectionFailure] branch ([OctopusNoNetwork],
  /// [OctopusUserNotAuthenticated], …). Does not throw on a handled SDK
  /// failure — pattern-match or use the helpers
  /// ([OctopusResultExtensions.onSuccess], `getOrElse`, …).
  ///
  /// **Platform note**: on Android, removing a reaction with `null` when none
  /// is set is a silent success; on iOS the native SDK currently reports this
  /// as a [SetReactionReactionError] rather than a no-op.
  Future<OctopusResult<void, SetReactionError>> setReaction(
    OctopusReactionKind? reaction,
    String postId,
  ) {
    return OctopusSDKPlatform.instance.setReaction(reaction, postId);
  }

  /// Force-refreshes the list of groups from the backend.
  ///
  /// The SDK refreshes groups internally as needed, so calling this is only
  /// useful when you want to surface the freshest values immediately (e.g. on a
  /// pull-to-refresh). The refreshed list is also published on the [groups]
  /// stream.
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] carrying the latest list of
  /// [OctopusGroup]s on success, or an [OctopusConnectionFailure] on transport/
  /// auth failure ([OctopusNoNetwork], [OctopusStatusError], …). The error type
  /// argument is widened to [OctopusServerError] because the native call has no
  /// typed business failure (Android `OctopusResult<…, Nothing>`); in practice
  /// the [OctopusInvalidArguments] branch is unreachable. Does not throw on a
  /// handled SDK failure.
  Future<OctopusResult<List<OctopusGroup>, OctopusServerError>> fetchGroups() {
    return OctopusSDKPlatform.instance.fetchGroups();
  }

  /// Follows the group with [groupId] on behalf of the connected user.
  ///
  /// Use this to programmatically follow a group from your app (the standard
  /// way is through the SDK UI). The follow state is reflected in the [groups]
  /// stream and the "For You" feed will include posts from this group.
  ///
  /// Requires a connected user.
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] on success, or an
  /// [OctopusFailure]. Business failures are an [OctopusInvalidArguments]
  /// carrying a typed [GroupFollowUnfollowError] (e.g.
  /// [GroupFollowUnfollowMissingGroupError],
  /// [GroupFollowUnfollowUnfollowableGroupError],
  /// [GroupFollowUnfollowGroupAlreadyFollowedError]); transport/auth failures
  /// surface through the [OctopusConnectionFailure] branch ([OctopusNoNetwork],
  /// [OctopusUserNotAuthenticated], …). Does not throw on a handled SDK failure
  /// — pattern-match or use the helpers ([OctopusResultExtensions.onSuccess],
  /// `getOrElse`, …).
  ///
  /// **Platform note**: on Android the native SDK exposes a dedicated
  /// `followGroup(id)` method. On iOS the bridge maps onto the batch
  /// `syncFollowGroups` API with a single action and translates the per-action
  /// status into the typed error. The user-facing contract is the same on both
  /// platforms.
  Future<OctopusResult<void, GroupFollowUnfollowError>> followGroup(
    String groupId,
  ) {
    return OctopusSDKPlatform.instance.followGroup(groupId);
  }

  /// Unfollows the group with [groupId] on behalf of the connected user.
  ///
  /// Counterpart to [followGroup]. The follow state is reflected in the
  /// [groups] stream and the "For You" feed excludes posts from this group
  /// going forward.
  ///
  /// Requires a connected user.
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] on success, or an
  /// [OctopusFailure]. Business failures are an [OctopusInvalidArguments]
  /// carrying a typed [GroupFollowUnfollowError] (e.g.
  /// [GroupFollowUnfollowMissingGroupError],
  /// [GroupFollowUnfollowGroupAlreadyUnfollowedError],
  /// [GroupFollowUnfollowLastFollowedGroupError]); transport/auth failures
  /// surface through the [OctopusConnectionFailure] branch ([OctopusNoNetwork],
  /// [OctopusUserNotAuthenticated], …).
  ///
  /// **Platform note**: see [followGroup] for the cross-platform contract. iOS
  /// has no equivalent of [GroupFollowUnfollowLastFollowedGroupError] —
  /// unfollowing the last followed group succeeds silently on iOS.
  Future<OctopusResult<void, GroupFollowUnfollowError>> unfollowGroup(
    String groupId,
  ) {
    return OctopusSDKPlatform.instance.unfollowGroup(groupId);
  }

  /// Fetches the Octopus post linked to a client object (article, product, …),
  /// creating it from [clientPost] if it does not exist yet.
  ///
  /// This is the **Bridge** entry point: it links community discussion to your
  /// app's own content. If a post already exists for `clientPost.objectId`, it
  /// is returned as-is and [clientPost]'s content is ignored; otherwise a new
  /// post is created from [clientPost]. Use the returned [OctopusPost.id] to
  /// display the post in the embedded UI.
  ///
  /// The call may take a moment (it can hit the network), so show a loader if it
  /// follows a user interaction.
  ///
  /// [tokenProvider] is an optional callback invoked **only** when a new post
  /// must be created and your community is configured to require a bridge
  /// signature. It receives the bridge fingerprint (a SHA-256 hash of the post
  /// content computed by the SDK) and must return a JWT signed by your backend
  /// authorizing the creation, or `null` if no signature is required. It is
  /// never called when the post already exists. If you omit it, no signature is
  /// supplied (fine for communities configured without bridge signatures).
  ///
  /// Returns an [OctopusResult]: [OctopusSuccess] carrying the [OctopusPost], or
  /// an [OctopusFailure]. Content/validation problems are an
  /// [OctopusInvalidArguments] carrying a typed [ClientPostError]; transport and
  /// auth failures surface through the [OctopusConnectionFailure] branch
  /// ([OctopusNoNetwork], …). Does not throw on a handled SDK failure —
  /// pattern-match or use the helpers ([OctopusResultExtensions.onSuccess],
  /// `getOrElse`, …). When switching on the failure, annotate the typed branch
  /// `case OctopusInvalidArguments<OctopusServerError>(:final errors)`.
  ///
  /// **Platform note**: on iOS the native SDK does not expose the specific
  /// validation error kinds publicly, so content errors there surface as
  /// [ClientPostOtherError]; on Android the specific [ClientPostError] subtypes
  /// are produced.
  Future<OctopusResult<OctopusPost, ClientPostError>>
      fetchOrCreateClientObjectRelatedPost(
    ClientPost clientPost, {
    Future<String?> Function(String fingerprint)? tokenProvider,
  }) async {
    _initializeEventChannel();
    final requestId = 'bridgeToken_${_bridgeTokenRequestCounter++}';
    if (tokenProvider != null) {
      _bridgeTokenProviders[requestId] = tokenProvider;
    }
    try {
      return await OctopusSDKPlatform.instance
          .fetchOrCreateClientObjectRelatedPost(
        clientPost,
        requestId: requestId,
        hasTokenProvider: tokenProvider != null,
      );
    } finally {
      _bridgeTokenProviders.remove(requestId);
    }
  }

  /// Reactive stream of the Octopus post linked to a client object, or `null`
  /// when no post exists yet for [clientObjectId].
  ///
  /// Emits the current post immediately to a new subscriber (the latest value is
  /// replayed by the native layer), then re-emits whenever the post changes —
  /// including right after [fetchOrCreateClientObjectRelatedPost] creates it, and
  /// on internal updates (new reactions, comment count, …). Mirrors the native
  /// `getClientObjectRelatedPostFlow` (Android) / `getClientObjectRelatedPostPublisher`
  /// (iOS).
  ///
  /// Each subscription drives its own native observation, so observing the same
  /// [clientObjectId] from two places is safe. Cancel the subscription to stop
  /// the native observation.
  ///
  /// [stop] tears the native observation down: the subscription stays open but
  /// silent, so re-subscribe after re-initializing.
  ///
  /// A community switch ([switchCommunity] / [switchCommunityOctopusAuth]) is
  /// **not** handled for you. The subscription stays open, but the native
  /// observation behind it belongs to the previous community, so it simply
  /// stops emitting. Cancel and re-subscribe after the switch.
  ///
  /// If the native side cannot start the observation (e.g. it is called before
  /// [initialize]), the stream forwards the error to its listener rather than
  /// hanging.
  static Stream<OctopusPost?> getClientObjectRelatedPostFlow(
    String clientObjectId,
  ) {
    _initializeEventChannel();
    return buildClientObjectPostStream(
      eventStream,
      'clientObjectPost_${_clientObjectObservationCounter++}',
      clientObjectId,
      OctopusSDKPlatform.instance,
    );
  }

  /// Builds the [getClientObjectRelatedPostFlow] stream: on listen, subscribes to
  /// [source] for `clientObjectPostChanged` events tagged with [observationId]
  /// and asks [platform] to start the native observation (subscribe-then-start,
  /// so the replayed current value isn't missed); on cancel, tears both down.
  /// Exposed for testing; production code should use
  /// [getClientObjectRelatedPostFlow].
  @visibleForTesting
  static Stream<OctopusPost?> buildClientObjectPostStream(
    Stream<Map<String, dynamic>> source,
    String observationId,
    String clientObjectId,
    OctopusSDKPlatform platform,
  ) {
    late final StreamController<OctopusPost?> controller;
    StreamSubscription<Map<String, dynamic>>? sub;
    controller = StreamController<OctopusPost?>(
      onListen: () {
        sub = source
            .where(
          (event) =>
              event['event'] == 'clientObjectPostChanged' &&
              event['observationId'] == observationId,
        )
            .listen((event) {
          final raw = event['post'];
          controller.add(raw is Map ? OctopusPost.fromWire(raw) : null);
        });
        // Fire-and-forget, but surface a start failure (e.g. called before
        // initialize) to the listener instead of leaving a silently-dead
        // stream + an unhandled async error.
        unawaited(
          platform
              .startClientObjectPostObservation(observationId, clientObjectId)
              .catchError((Object e, StackTrace st) {
            if (!controller.isClosed) controller.addError(e, st);
          }),
        );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
        await platform.stopClientObjectPostObservation(observationId);
      },
    );
    return controller.stream;
  }

  /// Fetches a read-only snapshot of a member's public Octopus community
  /// activity — the "Unified Profile" data surface, so your app can show Octopus
  /// stats on **its own** profile screen instead of sending the user to the
  /// SDK's native profile screen.
  ///
  /// Identify the member by **exactly one** of:
  /// - [clientUserId] — your app's own id for them. Requires the community to be
  ///   configured to expose client user ids; use this when your profile screen
  ///   only knows your own user ids.
  /// - [profileId] — their Octopus profile id, e.g. one reported by
  ///   [OtherUserProfileScreen] or [OtherUserPostsScreen].
  ///
  /// Passing both, or neither, throws an [ArgumentError] in every build.
  ///
  /// Returns `null` when the member is unknown — an unresolvable
  /// [clientUserId], or a [profileId] with no such profile. Refreshes from the
  /// server, so it can fail: the returned future completes with an error on a
  /// network/server failure, or when the community does not expose client user
  /// ids and you passed a [clientUserId].
  ///
  /// ```dart
  /// final data = await OctopusSDK().fetchCommunityData(
  ///   clientUserId: myUser.id,
  /// );
  /// final level = data?.gamification?.level;
  /// ```
  ///
  /// See [communityDataFlow] to observe the same data reactively.
  Future<OctopusCommunityData?> fetchCommunityData({
    String? profileId,
    String? clientUserId,
  }) async {
    _requireExactlyOneMemberId(profileId, clientUserId, 'fetchCommunityData');
    final wire = await OctopusSDKPlatform.instance.fetchCommunityData(
      profileId: profileId,
      clientUserId: clientUserId,
    );
    return wire == null ? null : OctopusCommunityData.fromWire(wire);
  }

  /// Observes a member's public Octopus community activity — the reactive
  /// counterpart of [fetchCommunityData].
  ///
  /// Identify the member by **exactly one** of [clientUserId] (your app's own
  /// id — requires the community to be configured to expose client user ids) or
  /// [profileId] (their Octopus profile id); passing both, or neither, throws an
  /// [ArgumentError] in every build (thrown synchronously, when the stream is
  /// built, not on listen).
  ///
  /// Emits the member's current data and then again on every refresh (e.g. after
  /// a [fetchCommunityData] call for the same member). Emits `null` when the
  /// member is unknown, including when a [clientUserId] cannot be resolved —
  /// resolution failures surface as `null` rather than as a stream error, so a
  /// UI binding never breaks.
  ///
  /// The returned stream is **single-subscription**. Every *call* to
  /// [communityDataFlow] drives its own native observation, so to watch the
  /// same member from two places call it twice — handing one stream to two
  /// listeners throws `Bad state: Stream has already been listened to`.
  /// Cancelling the subscription stops that native observation, and the stream
  /// cannot be listened to again afterwards.
  ///
  /// [stop] tears the native observation down: the subscription stays open but
  /// silent. After re-initializing, cancel it and call [communityDataFlow]
  /// again for a fresh stream.
  ///
  /// A community switch ([switchCommunity] / [switchCommunityOctopusAuth]) is
  /// **not** handled for you. The subscription stays open, but the native
  /// observation behind it belongs to the previous community, so it simply
  /// stops emitting. Cancel it and call [communityDataFlow] again after the
  /// switch.
  ///
  /// If the native side cannot start the observation (e.g. it is called before
  /// [initialize]), the stream forwards the error to its listener rather than
  /// hanging.
  static Stream<OctopusCommunityData?> communityDataFlow({
    String? profileId,
    String? clientUserId,
  }) {
    _requireExactlyOneMemberId(profileId, clientUserId, 'communityDataFlow');
    _initializeEventChannel();
    return buildCommunityDataStream(
      eventStream,
      'communityData_${_communityDataObservationCounter++}',
      OctopusSDKPlatform.instance,
      profileId: profileId,
      clientUserId: clientUserId,
    );
  }

  /// Throws an [ArgumentError] unless exactly one of [profileId] /
  /// [clientUserId] is provided. Mirrors [connectUser]'s exactly-one contract:
  /// a real throw in every build, not a debug-only assert.
  static void _requireExactlyOneMemberId(
    String? profileId,
    String? clientUserId,
    String methodName,
  ) {
    if ((profileId == null) == (clientUserId == null)) {
      throw ArgumentError(
        '$methodName requires exactly one of profileId or clientUserId '
        '(got ${profileId == null ? 'neither' : 'both'}).',
      );
    }
  }

  /// Builds the [communityDataFlow] stream: on listen, subscribes to [source]
  /// for `communityDataChanged` events tagged with [observationId] and asks
  /// [platform] to start the native observation (subscribe-then-start, so the
  /// replayed current value isn't missed); on cancel, tears both down.
  /// Exposed for testing; production code should use [communityDataFlow].
  @visibleForTesting
  static Stream<OctopusCommunityData?> buildCommunityDataStream(
    Stream<Map<String, dynamic>> source,
    String observationId,
    OctopusSDKPlatform platform, {
    String? profileId,
    String? clientUserId,
  }) {
    late final StreamController<OctopusCommunityData?> controller;
    StreamSubscription<Map<String, dynamic>>? sub;
    controller = StreamController<OctopusCommunityData?>(
      onListen: () {
        sub = source
            .where(
          (event) =>
              event['event'] == 'communityDataChanged' &&
              event['observationId'] == observationId,
        )
            .listen((event) {
          final raw = event['communityData'];
          controller.add(
            raw is Map ? OctopusCommunityData.fromWire(raw) : null,
          );
        });
        // Fire-and-forget, but surface a start failure (e.g. called before
        // initialize) to the listener instead of leaving a silently-dead
        // stream + an unhandled async error.
        unawaited(
          platform
              .startCommunityDataObservation(
            observationId,
            profileId: profileId,
            clientUserId: clientUserId,
          )
              .catchError((Object e, StackTrace st) {
            if (!controller.isClosed) controller.addError(e, st);
          }),
        );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
        await platform.stopCommunityDataObservation(observationId);
      },
    );
    return controller.stream;
  }

  /// Registers a callback invoked when the connected user attempts to interact
  /// with a group they do not have access to (taps a visible-but-locked group,
  /// its follow button, or a locked detail CTA). The SDK never navigates on the
  /// user's behalf — your app decides what to do (open an upsell, a paywall, …).
  ///
  /// [callback] receives the `groupId` of the locked group.
  ///
  /// Returns a [VoidCallback] that unregisters this callback — call it from your
  /// widget's `dispose`. Registering again replaces the previous callback
  /// (last-write-wins), so on hot reload the latest registration wins; storing
  /// and calling the returned handle in `dispose` avoids leaking a stale one.
  ///
  /// ```dart
  /// late final VoidCallback _cancel;
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _cancel = OctopusSDK.setGroupAccessDeniedCallback((groupId) {
  ///     // show your paywall for groupId
  ///   });
  /// }
  /// @override
  /// void dispose() {
  ///   _cancel();
  ///   super.dispose();
  /// }
  /// ```
  static VoidCallback setGroupAccessDeniedCallback(
    void Function(String groupId) callback,
  ) {
    _initializeEventChannel();
    _groupAccessDeniedCallback = callback;
    return () {
      // Only clear if this exact callback is still the registered one, so a
      // late `dispose` of an old widget doesn't unregister a newer callback.
      if (identical(_groupAccessDeniedCallback, callback)) {
        _groupAccessDeniedCallback = null;
      }
    };
  }

  /// Registers a callback invoked when the user taps the "view object" button on
  /// a bridge post (a post created via [fetchOrCreateClientObjectRelatedPost]
  /// with a `viewObjectButtonText`). The SDK never navigates on the user's
  /// behalf — your app decides what to open for the given `objectId` (the
  /// `ClientPost.objectId` you supplied).
  ///
  /// [callback] receives the `objectId` of the tapped client object.
  ///
  /// Returns a [VoidCallback] that unregisters this callback — call it from your
  /// widget's `dispose`. Registering again replaces the previous callback
  /// (last-write-wins), matching the native single-callback model; on hot reload
  /// the latest registration wins, and storing and calling the returned handle
  /// in `dispose` avoids leaking a stale one.
  ///
  /// ```dart
  /// late final VoidCallback _cancel;
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _cancel = OctopusSDK.setNavigateToClientObjectCallback((objectId) {
  ///     // open your article/product screen for objectId
  ///   });
  /// }
  /// @override
  /// void dispose() {
  ///   _cancel();
  ///   super.dispose();
  /// }
  /// ```
  static VoidCallback setNavigateToClientObjectCallback(
    void Function(String objectId) callback,
  ) {
    _initializeEventChannel();
    _navigateToClientObjectCallback = callback;
    return () {
      if (identical(_navigateToClientObjectCallback, callback)) {
        _navigateToClientObjectCallback = null;
      }
    };
  }

  /// Track community access for analytics without changing the actual access.
  ///
  /// This is for reporting only — it does not grant or restrict access.
  /// Useful when your app manages its own A/B testing logic.
  /// [hasAccess] - The access value to track
  Future<void> trackCommunityAccess(bool hasAccess) {
    return OctopusSDKPlatform.instance.trackCommunityAccess(hasAccess);
  }

  /// Override the default locale used by the Octopus SDK UI.
  ///
  /// [locale] - A Flutter [Locale] (e.g. `Locale('fr')`, `Locale('en', 'US')`).
  /// Pass `null` to reset to the system default locale.
  Future<void> overrideDefaultLocale(Locale? locale) {
    return OctopusSDKPlatform.instance.overrideDefaultLocale(locale);
  }

  /// Internal test affordance: locally overrides the per-field profile lock
  /// of the community config, without a backend-driven config. Pass `null`
  /// to clear the override and fall back to the backend value.
  ///
  /// Mirrors the native SDKs' debug-only `debugOverrideProfileFieldsLock`
  /// (Android `@InternalOctopusApi`, iOS `@_spi(OctopusInternalTesting)`),
  /// used by their sample apps to exercise the per-field profile lock before
  /// a backend serves it. **Not part of the supported public API** — it may
  /// change or be removed at any time.
  ///
  /// iOS support: pending. `ProfileFieldsLock` lives in the native SDK's
  /// `OctopusCore` module, which `octopus-sdk-swift`'s `Package.swift` does
  /// not expose as a library product, so this plugin cannot construct it —
  /// calling this on iOS resolves with an `UNSUPPORTED_PLATFORM`
  /// [PlatformException]. Android is fully supported.
  ///
  /// [lock] - the lock to apply, or `null` to restore the backend-provided
  /// config.
  Future<void> debugOverrideProfileFieldsLock(ProfileFieldsLock? lock) {
    return OctopusSDKPlatform.instance.debugOverrideProfileFieldsLock(lock);
  }

  /// Internal test affordance: locally overrides the per-content-type
  /// content options of the community config, without a backend-driven
  /// config. Pass `null` to clear the override and fall back to the backend
  /// value.
  ///
  /// Mirrors the native SDKs' debug-only `debugOverrideContentOptions`
  /// (Android `@InternalOctopusApi`, iOS `@_spi(OctopusInternalTesting)`),
  /// used by their sample apps to exercise the pictures/polls creation
  /// gating before a backend serves it. **Not part of the supported public
  /// API** — it may change or be removed at any time.
  ///
  /// iOS support: pending. `ContentOptions` lives in the native SDK's
  /// `OctopusCore` module, which `octopus-sdk-swift`'s `Package.swift` does
  /// not expose as a library product, so this plugin cannot construct it —
  /// calling this on iOS resolves with an `UNSUPPORTED_PLATFORM`
  /// [PlatformException]. Android is fully supported.
  ///
  /// [options] - the content options to apply, or `null` to restore the
  /// backend-provided config.
  Future<void> debugOverrideContentOptions(ContentOptions? options) {
    return OctopusSDKPlatform.instance.debugOverrideContentOptions(options);
  }

  /// Internal test affordance: locally overrides the terms-acceptance mode
  /// of the community config, without a backend-driven config. Pass `null`
  /// to clear the override and fall back to the backend value (currently
  /// implicit acceptance).
  ///
  /// Mirrors the native SDKs' debug-only `debugOverrideTermsAcceptanceMode`
  /// (Android `@InternalOctopusApi`, iOS `@_spi(OctopusInternalTesting)`),
  /// used by their sample apps to exercise the explicit-consent modes.
  /// **Not part of the supported public API** — it may change or be removed
  /// at any time.
  ///
  /// iOS support: pending. `TermsAcceptanceMode` lives in the native SDK's
  /// `OctopusCore` module, which `octopus-sdk-swift`'s `Package.swift` does
  /// not expose as a library product, so this plugin cannot construct it —
  /// calling this on iOS resolves with an `UNSUPPORTED_PLATFORM`
  /// [PlatformException]. Android is fully supported.
  ///
  /// [mode] - the mode to force, or `null` to restore the backend-provided
  /// config.
  Future<void> debugOverrideTermsAcceptanceMode(TermsAcceptanceMode? mode) {
    return OctopusSDKPlatform.instance.debugOverrideTermsAcceptanceMode(mode);
  }

  /// Track a custom event for analytics.
  ///
  /// [name] - The event name (e.g. "purchase", "sign_up").
  /// [properties] - Key-value pairs of event properties. All values are strings.
  ///
  /// Example:
  /// ```dart
  /// await octopus.trackCustomEvent('purchase', {
  ///   'product_id': '123',
  ///   'price': '9.99',
  ///   'currency': 'EUR',
  /// });
  /// ```
  Future<void> trackCustomEvent(
    String name, [
    Map<String, String> properties = const {},
  ]) {
    return OctopusSDKPlatform.instance.trackCustomEvent(name, properties);
  }

  /// Batch follow/unfollow groups in one round-trip.
  ///
  /// Each [SyncFollowGroupAction] carries its own [DateTime] so the backend
  /// can reject stale actions. Match returned results back to inputs by
  /// [SyncFollowGroupResult.groupId] (order is not guaranteed).
  ///
  /// Requires a connected user. Throws [PlatformException] on RPC-level
  /// failure with one of the codes: `not_connected`, `no_network`, `server`,
  /// `other`. Per-action failures are conveyed via
  /// [SyncFollowGroupStatus] in the returned list, not as exceptions.
  ///
  /// Passing an empty list is a no-op and resolves to an empty list without
  /// hitting the network.
  Future<List<SyncFollowGroupResult>> syncFollowGroups(
    List<SyncFollowGroupAction> actions,
  ) {
    return OctopusSDKPlatform.instance.syncFollowGroups(actions);
  }

  /// Register a push notification token with the Octopus SDK.
  ///
  /// Call this method with the FCM registration token (Android) or
  /// APNs device token (iOS) so that Octopus can send push notifications
  /// to this device.
  ///
  /// Typically called in your Firebase/APNs token refresh callback:
  /// ```dart
  /// FirebaseMessaging.instance.onTokenRefresh.listen((token) {
  ///   OctopusSDK().registerPushNotificationToken(token);
  /// });
  /// ```
  Future<void> registerPushNotificationToken(String token) {
    return OctopusSDKPlatform.instance.registerPushNotificationToken(token);
  }

  /// Checks whether a push notification payload originates from Octopus.
  ///
  /// Accepts either shape a Flutter app can encounter:
  /// - **Android FCM** (`RemoteMessage.data`): flat map with the Octopus keys
  ///   at the top level.
  /// - **iOS raw APNs `userInfo`**: nested map with the Octopus keys under a
  ///   `data` envelope alongside the standard `aps` dict.
  ///
  /// Returns `true` if `is_octopus_notification` equals `'true'` (string)
  /// or `true` (bool) in either location.
  static bool isOctopusNotification(Map payload) {
    return OctopusNotification.isOctopusFlag(payload);
  }

  /// Parses a push notification payload into a typed [OctopusNotification].
  ///
  /// Accepts both Android FCM and iOS raw APNs payload shapes — see
  /// [OctopusNotification.fromMap] for the full contract. Call
  /// [isOctopusNotification] first to verify the payload is from Octopus.
  static OctopusNotification? getOctopusNotification(Map payload) {
    return OctopusNotification.fromMap(payload);
  }

  /// Presents the Octopus community UI as a full-screen route push.
  ///
  /// Pushes a [MaterialPageRoute] hosting [OctopusHomeScreen] inside a
  /// `Scaffold` + `SafeArea(bottom: false)` — the same shape demonstrated
  /// inline by the sample (`example/lib/scenarios/fullscreen_scenario.dart`).
  /// Use the helper for the one-liner, or copy the inline pattern when you
  /// need to customize the route beyond the exposed parameters (e.g. a host
  /// bottom bar drawn over the embedded view, a `fullscreenDialog` modal
  /// presentation — see `example/lib/scenarios/modal_scenario.dart` — or a
  /// custom transition). The bottom safe-area inset is *not* one of those
  /// cases: it is exposed as [bottomSafeAreaInset] below.
  ///
  /// **History note (1.12.0 development).** This helper was briefly
  /// `@Deprecated` after a report that modal-style hosting silently dropped
  /// the SDK's internal sub-navigation (post taps registering a view without
  /// pushing post detail). The root cause was found and fixed in 1.12.0: the
  /// [OctopusHomeScreen] overlay gating reparented — and thereby recreated —
  /// the native PlatformView whenever a `leadingWidget`/`trailingWidget`
  /// overlay was configured (the 1.12.0-dev helper attached a default close
  /// overlay, which is why the symptom tracked the helper). The route shapes
  /// themselves were never at fault; the helper now pushes a plain
  /// [MaterialPageRoute] (no bottom sheet involved). Tracked internally.
  ///
  /// The returned [Future] completes when the route is popped — on **every**
  /// path that actually dismisses it, whether or not it went through
  /// [onBack]: the SDK's own root leading icon, Android system / predictive
  /// back **while the SDK is on its root screen**, the iOS
  /// swipe-from-left-edge gesture [MaterialPageRoute] enables, or a
  /// programmatic `Navigator.pop`. Deeper inside the SDK a back gesture is
  /// consumed by the native navigation stack and dismisses nothing — see
  /// *Which paths do NOT* below. [closeWidget] is accepted for backward
  /// compatibility with 1.11.0's API but is **not currently wired** —
  /// the full-screen route already exposes back/dismiss affordances on
  /// both platforms, so an extra overlay close button is redundant here.
  ///
  /// ## Getting notified when the user leaves — [onBack]
  ///
  /// [onBack] is a **notification, not a delegation**. The route pops itself
  /// when the SDK's root leading icon is tapped — today's behaviour, and it is
  /// unchanged whether or not you pass a callback. When [onBack] is given it
  /// is invoked **before** the pop; it does not have to pop the route itself.
  /// This helper owns the route it pushed, so it can never let a host that
  /// registered no callback — or one whose handler throws — strand the user
  /// inside the community. (A callback that throws is reported through
  /// [FlutterError.reportError] and the route still pops.) It is the same
  /// choice, for the same reason, as the React Native wrapper's
  /// `openUI({ onBackRequested })`.
  ///
  /// **If your callback navigates itself, the helper leaves the stack alone.**
  /// The pop is guarded on this helper's own route still being the current one
  /// when the callback returns. So a callback that pops the route is not
  /// double-popped, and one that pushes something (a dialog, a confirmation
  /// page) keeps what it pushed instead of having it closed from under it — in
  /// that case the SDK route stays underneath it, and dismissing it is yours
  /// to do. A callback that only does bookkeeping — the intended use — leaves
  /// the pop exactly as it was.
  ///
  /// Use it for host-side bookkeeping — analytics, restoring a bottom bar,
  /// refreshing a badge count. To run code on **every** dismissal path
  /// instead, `await` the returned [Future].
  ///
  /// **Which paths reach [onBack].** It fires exactly when the native side
  /// emits `backRequested` — see [OctopusHomeScreen.onBack], which this
  /// helper wires it to:
  /// - **Android** — the tap on the SDK's root leading icon (the M3 chevron
  ///   this helper requests via `showBackButton: true`, or the
  ///   [navBarLeadingAction] icon when you set one). Deeper SDK screens pop
  ///   inside the native navigation stack and never reach here.
  /// - **iOS** — the tap on the SDK's root leading item. With no
  ///   [navBarLeadingAction] the bridge backfills
  ///   [OctopusNavBarLeadingAction.back] from this helper's
  ///   `showBackButton: true`, so the chevron is present and routed either
  ///   way.
  ///
  /// **Which paths do NOT.** No OS-level gesture routes through [onBack]: the
  /// plugin installs no back interception of its own (no `PopScope` on the
  /// Dart side, no `BackHandler` in the Android bridge). What such a gesture
  /// does instead depends on **where the user is inside the SDK**:
  /// - **On the SDK's root screen** — Android system / predictive back pops
  ///   the Flutter route directly, without a `backRequested` event, so the
  ///   returned [Future] completes. Same for any programmatic
  ///   `Navigator.pop`.
  /// - **Deeper inside the SDK** — the native navigation stack consumes the
  ///   gesture and navigates up inside itself: the plugin hosts the native
  ///   screens in a Navigation-Compose `NavHost`, whose back callback is
  ///   enabled as soon as that stack holds more than one entry, and the
  ///   wrapped native SDK installs its own back handlers on the deeper screens
  ///   (post detail, group detail, profile, create-post…). Neither [onBack]
  ///   nor the returned [Future] fires there — the Flutter route is still up.
  ///
  /// On **iOS** the route this helper pushes is an ordinary
  /// [MaterialPageRoute], so the swipe-from-left-edge gesture that route
  /// enables is a Flutter-level pop and never emits `backRequested`; the
  /// native SDK drives its own `NavigationStack` for its internal screens, so
  /// which of the two a swipe reaches on a deeper screen is not something the
  /// plugin decides. Either way, the returned [Future] — not the gesture — is
  /// the contract: it completes if and only if this route is popped.
  ///
  /// [navBarLeadingAction] is forwarded verbatim to
  /// [OctopusHomeScreen.navBarLeadingAction] and keeps that contract: it
  /// replaces the SDK's **root** leading icon with a close (X) or back (‹)
  /// affordance on both platforms, taking precedence over the
  /// `showBackButton: true` this helper passes, and its tap fires [onBack]
  /// before the route pops like any other root leading tap. Left `null`
  /// (the default) the behaviour is exactly what it was before this
  /// parameter existed: a back chevron on Android, and the iOS bridge's
  /// backfilled `.back` chevron.
  ///
  /// [bottomSafeAreaInset] controls the bottom padding the embedded native
  /// screen reserves for its floating "Write a post" button. Leave it `null`
  /// (default) and the helper auto-reserves the launching view's bottom safe
  /// area, keeping the button clear of the Android system navigation bar on
  /// edge-to-edge devices (API 35+), where it would otherwise be occluded.
  /// Pass `0` to opt back into the previous edge-to-edge look, or a larger
  /// value to clear additional host bottom chrome. See
  /// [OctopusHomeScreen.bottomSafeAreaInset] for the underlying contract.
  Future<void> showOctopusHomeScreen(
    BuildContext context, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    UrlOpeningStrategy Function(String)? onNavigateToUrl,
    void Function(String clientUserId)? onNavigateToProfile,
    Widget? closeWidget,
    OctopusNotification? notification,
    double? bottomSafeAreaInset,
    VoidCallback? onBack,
    OctopusNavBarLeadingAction? navBarLeadingAction,
  }) {
    // Edge-to-edge Android (API 35+): the embedded PlatformView consumes the
    // system-bar insets internally, and this route's `SafeArea(bottom: false)`
    // deliberately does not pad the bottom, so the SDK's floating "Write a
    // post" button would otherwise sit behind the system navigation bar.
    // Reserve that inset by default. Read the raw View (not `MediaQuery.of`)
    // so an ancestor `SafeArea` that already consumed `padding.bottom` can't
    // zero it out. Callers can override: pass `0` to opt back into the
    // edge-to-edge look, or a larger value to clear their own bottom chrome.
    //
    // This value is a *total* bottom padding: the Android bridge consumes the
    // system insets before mounting, and the iOS bridge subtracts the safe area
    // the embedded view sits in before handing it to the native SDK
    // (`SafeHostingContainerView.updateNormalizedBottomInset`). Reserved
    // band per platform, for a requested value R and a system inset S:
    // Android `R`, iOS `max(R, S)` — identical whenever `R >= S`, which is the
    // case here since R *is* the device inset. iOS never reserves less than the
    // safe area it already sits in, and on iOS 14 the native SDK ignores the
    // value entirely (its inset modifier needs iOS 15+).
    // (Before that normalization landed, iOS added this value *on top of* its
    // own safe area and rendered roughly twice the intended band.)
    final effectiveBottomInset = bottomSafeAreaInset ??
        MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    // A `0` here — passed explicitly ("pass `0` to opt back into the previous
    // edge-to-edge look", a contract shipped in 1.12.3) or resolved on a device
    // with no bottom inset — must reach the native side as "no preference".
    // `embeddedView` resolves a `0` from the ambient padding, and this route's
    // `SafeArea(bottom: false)` deliberately leaves that padding intact, so the
    // resolution would otherwise re-add the very inset the caller waived: strip
    // it here instead. The flag derives from a call argument, not from state, so
    // it is fixed for the whole life of the route — this wrapper never appears
    // or disappears between rebuilds, and the PlatformView is never reparented
    // (the failure mode described in `OctopusHomeScreen.build`).
    final optOutOfBottomInset = effectiveBottomInset == 0;
    // Held in a local so the notify-then-close handler below can ask whether
    // THIS route is still the current one before popping (see `onBack`). It is
    // assigned on the very next statement and only ever read from a callback
    // that cannot run before the route is pushed, so the `late` is resolved
    // long before anything reads it.
    late final MaterialPageRoute<void> sdkRoute;
    sdkRoute = MaterialPageRoute<void>(
      builder: (routeContext) {
        Widget content = Scaffold(
          body: SafeArea(
            bottom: false,
            child: OctopusHomeScreen(
              theme: theme,
              navBarTitle: navBarTitle,
              navBarPrimaryColor: navBarPrimaryColor,
              showBackButton: true,
              bottomSafeAreaInset: effectiveBottomInset,
              navBarLeadingAction: navBarLeadingAction,
              // Notify-then-close, guarded on this route still being the
              // current one. The helper owns the route it pushed, so a host
              // that registered no callback — or one whose handler throws —
              // must never be able to strand the user inside the community:
              // the host is notified first, then the route pops, exactly as
              // it did before `onBack` existed. What the pop must not do is
              // fire blind at whatever happens to be on top afterwards. A
              // callback that navigates by itself — pushes a dialog, or pops
              // this route already — would otherwise get its own route
              // closed, or this one popped twice. Testing `sdkRoute.isCurrent`
              // costs nothing in the intended case (a bookkeeping callback,
              // no callback at all, or a throwing one: the route is still
              // current, so the pop happens as before) and makes the
              // navigating case a no-op instead of a wrong pop. It also
              // closes the double-tap window on the native icon during the
              // exit animation, where the route is no longer present.
              // (Same contract, and the same reason, as the React Native
              // wrapper's `openUI({ onBackRequested })`.)
              onBack: () {
                if (onBack != null) {
                  try {
                    onBack();
                  } catch (error, stack) {
                    // Surfaced through the framework's error reporter
                    // rather than swallowed: a broken host callback stays
                    // visible in the console and in `FlutterError.onError`,
                    // without taking the dismissal down with it.
                    FlutterError.reportError(
                      FlutterErrorDetails(
                        exception: error,
                        stack: stack,
                        library: 'octopus_sdk_flutter',
                        context: ErrorDescription(
                          'while notifying the showOctopusHomeScreen '
                          'onBack callback',
                        ),
                      ),
                    );
                  }
                }
                if (sdkRoute.isCurrent) {
                  Navigator.of(routeContext).pop();
                }
              },
              onNavigateToLogin: onNavigateToLogin,
              onModifyUser: onModifyUser,
              onNavigateToProfile: onNavigateToProfile,
              onNavigateToUrl: onNavigateToUrl,
              notification: notification,
            ),
          ),
        );
        if (optOutOfBottomInset) {
          // Wrapped ABOVE the `Scaffold` and paired with the route's own
          // context. `removePadding` rebuilds the data from the context it is
          // handed, so what matters is that the two match — not the depth.
          // Keeping `context: routeContext` while moving the wrapper BELOW the
          // `SafeArea` would re-inject the top inset that `SafeArea` had just
          // consumed, double-padding the widget's own top overlays. (Pairing a
          // lower wrapper with a local context would be correct as well: it is
          // the mismatch that breaks, not the position.)
          content = MediaQuery.removePadding(
            context: routeContext,
            removeBottom: true,
            child: content,
          );
        }
        return content;
      },
    );
    return Navigator.of(context).push<void>(sdkRoute);
  }

  /// Opens the Octopus UI navigated to the content referenced by [notification].
  ///
  /// Convenience wrapper around [showOctopusHomeScreen]. Typically called from
  /// a push-notification tap handler:
  ///
  /// ```dart
  /// FirebaseMessaging.onMessageOpenedApp.listen((message) {
  ///   final data = message.data.map((k, v) => MapEntry(k, v.toString()));
  ///   if (OctopusSDK.isOctopusNotification(data)) {
  ///     final notification = OctopusSDK.getOctopusNotification(data);
  ///     if (notification != null) {
  ///       OctopusSDK().openNotification(
  ///         context,
  ///         notification,
  ///         onNavigateToLogin: () => Navigator.pushNamed(context, '/login'),
  ///       );
  ///     }
  ///   }
  /// });
  /// ```
  ///
  /// See the **History note** on [showOctopusHomeScreen] — this wrapper was
  /// briefly `@Deprecated` alongside it during 1.12.0 development over a
  /// sub-navigation report whose root cause (overlay gating recreating the
  /// PlatformView) was found and fixed in 1.12.0; tracked internally.
  ///
  /// [onBack] and [navBarLeadingAction] are forwarded unchanged to
  /// [showOctopusHomeScreen] — including the notify-then-close contract and
  /// the per-platform list of which dismissal paths reach [onBack]. Read that
  /// helper's documentation for both.
  Future<void> openNotification(
    BuildContext context,
    OctopusNotification notification, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    UrlOpeningStrategy Function(String)? onNavigateToUrl,
    void Function(String clientUserId)? onNavigateToProfile,
    double? bottomSafeAreaInset,
    VoidCallback? onBack,
    OctopusNavBarLeadingAction? navBarLeadingAction,
  }) {
    return showOctopusHomeScreen(
      context,
      navBarTitle: navBarTitle,
      navBarPrimaryColor: navBarPrimaryColor,
      theme: theme,
      onNavigateToLogin: onNavigateToLogin,
      onModifyUser: onModifyUser,
      onNavigateToUrl: onNavigateToUrl,
      onNavigateToProfile: onNavigateToProfile,
      notification: notification,
      bottomSafeAreaInset: bottomSafeAreaInset,
      onBack: onBack,
      navBarLeadingAction: navBarLeadingAction,
    );
  }

  /// Presents the native Octopus post editor (Bridge Share) as a full
  /// platform-owned screen — a dedicated Activity on Android, a full-screen
  /// modal on iOS. The native editor owns its chrome (nav bar, X / Post
  /// buttons, group picker, CGU links, publish flow) so the host doesn't have
  /// to wrap it in any Flutter scaffold.
  ///
  /// Supply [info] to prefill the editor (text / image bytes / target group /
  /// invisible CTA); omit it to open an empty editor.
  ///
  /// **Future completion (platform note).** On iOS the returned [Future]
  /// completes when the modal is actually dismissed (publish or cancel). On
  /// Android it completes as soon as the Activity has been launched — the
  /// dedicated Activity drives its own lifecycle and the host learns about
  /// dismissal through the events / callbacks below, not through this Future.
  /// Do not `await` this call expecting it to mean "the user finished editing
  /// on Android".
  ///
  /// Publishing requires a connected user. The SDK uses the same global
  /// routing as [showOctopusHomeScreen]: a `loginRequired` event on
  /// [events], an `editUser` event for app-managed profile fields, and
  /// [setNavigateToClientObjectCallback] for the "view object" button on
  /// bridge posts. The Android Activity finishes itself the moment any of
  /// these intents fire so the host can re-present the editor with the
  /// freshly-connected user; the iOS modal stays presented under the host's
  /// pushed login route — pick the dismiss timing that fits your UX.
  ///
  /// **Signing prefilled image shares.** Set
  /// [CreatePostScreenInfo.bridgeShareTokenProvider] when opening the editor in
  /// a community that forbids member pictures: at publish time the SDK invokes
  /// it with the content fingerprint and the host backend returns a signing
  /// JWT (it reuses the same native→Dart round-trip as
  /// [fetchOrCreateClientObjectRelatedPost]). The provider is scoped to this
  /// editor session — opening another editor supersedes it. Supported on both
  /// platforms (iOS via plugin pods `1.12.4`+); see
  /// [CreatePostScreenInfo.bridgeShareTokenProvider] for the small
  /// platform difference when the provider replies `null`.
  Future<void> showOctopusCreatePostScreen({
    CreatePostScreenInfo? info,
    OctopusTheme? theme,
  }) {
    _initializeEventChannel();
    // Supersede any previous editor's bridge-share provider: the native editor
    // holds a single one (last-write-wins) and clears it when it closes, so the
    // prior Dart entry is stale once a new editor opens. Drop it to keep
    // [_bridgeTokenProviders] bounded.
    final previousRequestId = _createPostBridgeTokenRequestId;
    if (previousRequestId != null) {
      _bridgeTokenProviders.remove(previousRequestId);
      _createPostBridgeTokenRequestId = null;
    }
    String? requestId;
    final provider = info?.bridgeShareTokenProvider;
    if (provider != null) {
      requestId = 'bridgeToken_${_bridgeTokenRequestCounter++}';
      _bridgeTokenProviders[requestId] = provider;
      _createPostBridgeTokenRequestId = requestId;
    }
    return OctopusSDKPlatform.instance.showCreatePostScreen(
      OctopusSDK.createPostScreenArgs(
        info: info,
        theme: theme,
        bridgeTokenRequestId: requestId,
      ),
    );
  }
}
