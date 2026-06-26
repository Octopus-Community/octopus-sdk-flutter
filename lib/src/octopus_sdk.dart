import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'api_server.dart';
import 'client_post.dart';
import 'client_post_error.dart';
import 'create_post_screen_info.dart';
import 'group_follow_unfollow_error.dart';
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
import 'octopus_sdk_platform.dart';
import 'octopus_theme.dart';
import 'octopus_home_screen.dart';
import 'sync_follow_group.dart';
import 'url_opening_strategy.dart';

export 'api_server.dart';
export 'client_post.dart';
export 'client_post_error.dart';
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
export 'octopus_home_screen.dart';
export 'sync_follow_group.dart';
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

// Persistent client-user tokenProviders, keyed by a stable providerId per
// connected user. Registered by [OctopusSDK.connectUserWithTokenProvider] and
// cleared on [OctopusSDK.disconnectUser]. The native SDK invokes the provider
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
  /// provider registered by [connectUserWithTokenProvider] under the request's
  /// `providerId`, awaits the freshly-signed JWT, and replies via
  /// [OctopusSDKPlatform.provideClientUserToken]. An empty token reply tells
  /// the native SDK "no token available — fail the refresh" (mirrors the
  /// bridge-token null-reply contract; see `_handleBridgeTokenRequest`).
  ///
  /// A missing provider (e.g. the user disconnected mid-refresh) and a
  /// throwing provider both reply with an empty token — the native SDK then
  /// surfaces the failure through its own typed error.
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
        await OctopusSDKPlatform.instance
            .provideClientUserToken(requestId, token);
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
  ///   null (an explicit [navBarLeadingAction] wins). The tap is surfaced as
  ///   `backRequested` (routed to [OctopusHomeScreen.onBack]) on both
  ///   platforms.
  /// [titleCentered] - If true, centers the title in the native top app bar.
  ///   Supported on both platforms: Android maps it to the native
  ///   `OctopusHomeScreen(titleCentered:)` composable param, iOS to
  ///   `OctopusMainFeedTitle.Placement.center` on the main feed.
  /// [theme] - Custom theme for the interface
  /// [interceptUrls] - If true, urls opened inside the community are surfaced through the event stream
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
  ///   **iOS-only** (wrapped iOS SDK 1.12.2+); a no-op on Android, where the
  ///   leading back arrow is controlled by [showBackButton]. See
  ///   [OctopusNavBarLeadingAction].
  ///
  /// **Gesture handling (Android)** — pointer events landing inside the
  /// embedded view are dispatched directly to the native side via an
  /// `EagerGestureRecognizer`, so the SDK's internal scroll (the feed) wins
  /// vertical drags and the embedded UI's own taps / long-press / swipe-to-
  /// react work as designed. As a consequence, ancestor Flutter gesture
  /// recognizers — a parent `ListView`/`PageView`/`TabBarView`, a draggable
  /// modal without an explicit drag-handle, an `InteractiveViewer` — will
  /// NOT see pointers whose finger lands inside the embedded view's bounds
  /// (horizontal swipes included). Hosts that need the parent to win must
  /// expose the affordance OUTSIDE the embedded view: Material 3's
  /// `showDragHandle: true` on `showModalBottomSheet`, an explicit close
  /// button, the back chevron via [showBackButton], or a layout where the
  /// parent's gesture area doesn't overlap the SDK. On iOS, `UiKitView`
  /// defers to UIKit's gesture-recognizer delegation chain and ancestor
  /// recognizers can still win where UIKit's delegate allows — a
  /// platform asymmetry documented in flutter/flutter#26425 and #66270.
  static Widget embeddedView({
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    bool showBackButton = true,
    bool titleCentered = false,
    OctopusTheme? theme,
    bool interceptUrls = false,
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
      if (bottomSafeAreaInset > 0) 'bottomSafeAreaInset': bottomSafeAreaInset,
      if (!showNavBar) 'showNavBar': false,
      // Emit only the non-default values; the native bridges default to
      // `.automatic` / no leading action when the key is absent (matching the
      // `titleCentered` / `showNavBar` "emit only non-default" wire pattern).
      // Both keys are consumed by the iOS bridge only — Android ignores them.
      // Always emit so the bridge sees the host's explicit choice (the Flutter
      // wrapper's default differs from the native iOS `.automatic` default —
      // the bridge needs the wire value to know which one the host picked).
      'navigationMode': navigationMode.name,
      if (navBarLeadingAction != null)
        'navBarLeadingAction': navBarLeadingAction.name,
      if (theme != null) ...theme.toMap(),
      ...creationParamsFor(
        notification: notification,
        initialScreen: initialScreen,
      ),
    };

    return defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          )
        : defaultTargetPlatform == TargetPlatform.android
            ? AndroidView(
                viewType: viewType,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                // Eagerly claim every pointer that lands on the AndroidView so
                // the SDK's internal LazyColumn wins vertical drags over any
                // ancestor Flutter recognizer (typically a
                // `showModalBottomSheet`'s drag-to-dismiss, or a parent
                // `ListView`). Without this, the AndroidView only sees
                // pointers no Flutter ancestor has claimed, and a bottom-sheet
                // parent steals every vertical drag — the native feed is
                // unscrollable inside the sheet. iOS `UiKitView` doesn't need
                // an equivalent: UIKit's gesture recognizer delegation lets
                // the inner `UIScrollView` win automatically (the documented
                // platform asymmetry — flutter/flutter#26425, #66270).
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              )
            : const SizedBox.shrink();
  }

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
  @visibleForTesting
  static Map<String, dynamic> createPostScreenArgs({
    CreatePostScreenInfo? info,
    OctopusTheme? theme,
  }) {
    return <String, dynamic>{
      if (theme != null) ...theme.toMap(),
      ...(info ?? const CreatePostScreenInfo()).toMap(),
    };
  }

  /// Connect a user to the Octopus SDK
  ///
  /// Note: You must call initialize() before connecting a user
  ///
  /// [userId] - Unique identifier for the user
  /// [token] - JWT token for user authentication (get from your backend)
  /// [nickname] - User's display name (optional)
  /// [bio] - User's bio (optional)
  /// [picture] - User's profile picture URL or base64 (optional)
  Future<void> connectUser({
    required String userId,
    required String token,
    String? nickname,
    String? bio,
    String? picture,
  }) {
    return OctopusSDKPlatform.instance.connectUser(
      userId: userId,
      token: token,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
  }

  /// Connect a user with a **persistent** token provider — the native SDK
  /// invokes [tokenProvider] initially (on connect) AND on every subsequent
  /// refresh (e.g. [refreshEntitlements] minting a fresh JWT with the host's
  /// current entitlement set). Mirrors the native Android/iOS
  /// `OctopusSDK.connectUser(user, tokenProvider:)` contract.
  ///
  /// Use [connectUser] (static `token`) when the JWT is pre-minted and
  /// doesn't need to change for the connection's lifetime. Use this method
  /// when [tokenProvider] can re-mint with updated claims — required for
  /// [refreshEntitlements] to succeed (without a persistent provider, the
  /// SDK returns `RefreshEntitlementsNoClientTokenProviderError`).
  ///
  /// The provider is unregistered automatically by [disconnectUser]; calling
  /// this method again with the same [userId] replaces the previous
  /// provider (last-write-wins).
  Future<void> connectUserWithTokenProvider({
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
      await OctopusSDKPlatform.instance.connectUserWithTokenProvider(
        userId: userId,
        providerId: providerId,
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
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
  /// (and, on Android, whenever the guest flag flips). Consecutive duplicate
  /// values are collapsed, so it emits only on an actual change. The latest
  /// snapshot is replayed to late subscribers. Mirrors the native Android
  /// `OctopusSDK.connectionState`; on iOS, the value is derived from the
  /// `profile` publisher (see [OctopusConnected.isGuest] for the guest-flag
  /// asymmetry).
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
  /// **Platform asymmetry.** On Android, `true` iff the connection is
  /// non-guest. On iOS, `true` whenever a user is connected — the iOS public
  /// SDK does not distinguish guest sessions. Consecutive duplicate values are
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
  /// **Breaking change in 1.12.0**: previously returned `Future<void>`. Callers
  /// that only need fire-and-forget behaviour can ignore the result.
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
  /// A subscription does **not** survive [stop] or a community switch
  /// ([switchCommunity] / [switchCommunityOctopusAuth]): the native observation
  /// is torn down and is not automatically re-bound. Re-subscribe after
  /// re-initializing. If the native side cannot start the observation (e.g. it
  /// is called before [initialize]), the stream forwards the error to its
  /// listener rather than hanging.
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
  /// need to customize the route beyond the exposed parameters (e.g. the
  /// bottom safe-area inset, a `fullscreenDialog` modal presentation — see
  /// `example/lib/scenarios/modal_scenario.dart` — or a custom transition).
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
  /// The returned [Future] completes when the route is popped (the SDK's
  /// own back chevron on Android, system back, iOS swipe-from-left-edge,
  /// or programmatic dismissal). [closeWidget] is accepted for backward
  /// compatibility with 1.11.0's API but is **not currently wired** —
  /// the full-screen route already exposes back/dismiss affordances on
  /// both platforms, so an extra overlay close button is redundant here.
  Future<void> showOctopusHomeScreen(
    BuildContext context, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    UrlOpeningStrategy Function(String)? onNavigateToUrl,
    Widget? closeWidget,
    OctopusNotification? notification,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: OctopusHomeScreen(
              theme: theme,
              navBarTitle: navBarTitle,
              navBarPrimaryColor: navBarPrimaryColor,
              showBackButton: true,
              onBack: () => Navigator.of(routeContext).pop(),
              onNavigateToLogin: onNavigateToLogin,
              onModifyUser: onModifyUser,
              onNavigateToUrl: onNavigateToUrl,
              notification: notification,
            ),
          ),
        ),
      ),
    );
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
  Future<void> openNotification(
    BuildContext context,
    OctopusNotification notification, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    UrlOpeningStrategy Function(String)? onNavigateToUrl,
  }) {
    return showOctopusHomeScreen(
      context,
      navBarTitle: navBarTitle,
      navBarPrimaryColor: navBarPrimaryColor,
      theme: theme,
      onNavigateToLogin: onNavigateToLogin,
      onModifyUser: onModifyUser,
      onNavigateToUrl: onNavigateToUrl,
      notification: notification,
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
  Future<void> showOctopusCreatePostScreen({
    CreatePostScreenInfo? info,
    OctopusTheme? theme,
  }) {
    _initializeEventChannel();
    return OctopusSDKPlatform.instance.showCreatePostScreen(
      OctopusSDK.createPostScreenArgs(info: info, theme: theme),
    );
  }
}
