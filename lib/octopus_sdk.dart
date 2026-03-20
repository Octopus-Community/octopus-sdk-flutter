import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'octopus_event.dart';
import 'profile_field.dart';
import 'octopus_sdk_platform.dart';
import 'octopus_theme.dart';
import 'octopus_home_screen.dart';
import 'url_opening_strategy.dart';

export 'profile_field.dart';
export 'octopus_home_screen.dart';
export 'url_opening_strategy.dart';

// Event stream controller for native events
StreamController<Map<String, dynamic>>? _eventStreamController;
EventChannel? _eventChannel;
bool _isEventChannelInitialized = false;

// Cached last values so late subscribers don't miss the initial emission.
// The native side emits these during initialize(), but the Dart consumer
// may not be listening yet.
int? _lastNotSeenNotificationsCount;
bool? _lastHasAccessToCommunity;

class OctopusSDK {
  static void _initializeEventChannel() {
    if (!_isEventChannelInitialized) {
      _isEventChannelInitialized = true;
      _eventChannel = const EventChannel('octopus_sdk_flutter/events');
      _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

      _eventChannel!.receiveBroadcastStream().listen((event) {
        final map = Map<String, dynamic>.from(event);
        // Cache the latest values so late subscribers can get them
        if (map['event'] == 'notSeenNotificationsCountChanged') {
          _lastNotSeenNotificationsCount = map['count'] as int;
        } else if (map['event'] == 'hasAccessToCommunityChanged') {
          _lastHasAccessToCommunity = map['hasAccess'] as bool;
        }
        _eventStreamController?.add(map);
      });
    }
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
  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
  }) {
    return OctopusSDKPlatform.instance.initialize(
      apiKey: apiKey,
      appManagedFields: appManagedFields,
    );
  }

  /// Initialize the Octopus SDK with Octopus Auth mode (Octopus manages user authentication)
  ///
  /// [apiKey] - Your Octopus Community API key
  /// [deepLink] - Optional deep link to reopen your app after magic link authentication
  /// Example: "com.yourapp.scheme://magic-link"
  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
  }) {
    return OctopusSDKPlatform.instance.initializeOctopusAuth(
      apiKey: apiKey,
      deepLink: deepLink,
    );
  }

  /// Embedded PlatformView widget to display native Octopus UI inside Flutter
  ///
  /// [navBarTitle] - Title displayed in the navigation bar
  ///                 iOS: When provided, replaces the logo completely
  ///                 Android: Can be displayed alongside the logo
  /// [navBarPrimaryColor] - If true, uses the primary color for the navigation bar background
  /// [showBackButton] - If true, shows the back button in the navigation bar (Android only)
  /// [theme] - Custom theme for the interface (colors, font sizes, logo)
  /// [interceptUrls] - If true, urls opened inside the community will be sent through onNavigateToUrl event stream for you to catch it and use it as you wish
  ///
  /// Note: Callbacks (onNavigateToLogin, onModifyUser, onBack) are handled via
  /// the event stream in OctopusHomeScreen widget.
  static Widget embeddedView({
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    bool showBackButton = true,
    OctopusTheme? theme,
    bool interceptUrls = false,
  }) {
    const viewType = 'octopus_sdk_flutter/native_view';

    // Initialize event channel for callbacks
    _initializeEventChannel();

    final creationParams = <String, dynamic>{
      if (navBarTitle != null) 'navBarTitle': navBarTitle,
      'navBarPrimaryColor': navBarPrimaryColor,
      'showBackButton': showBackButton,
      'interceptUrls': interceptUrls,
      if (theme != null) ...theme.toMap(),
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
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          )
        : const SizedBox.shrink();
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

  /// Connect a user to the Octopus SDK with a token provider function
  ///
  /// This is useful when you need to fetch the token asynchronously
  /// Note: You must call initialize() before connecting a user
  ///
  /// [userId] - Unique identifier for the user
  /// [tokenProvider] - Function that returns a JWT token for user authentication
  /// [nickname] - User's display name (optional)
  /// [bio] - User's bio (optional)
  /// [picture] - User's profile picture URL or base64 (optional)
  Future<void> connectUserWithTokenProvider({
    required String userId,
    required Future<String> Function() tokenProvider,
    String? nickname,
    String? bio,
    String? picture,
  }) async {
    final token = await tokenProvider();
    if (token.isEmpty) {
      throw ArgumentError('tokenProvider returned an empty token');
    }
    await connectUser(
      userId: userId,
      token: token,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
  }

  /// Disconnect the current user from the Octopus SDK
  Future<void> disconnectUser() {
    return OctopusSDKPlatform.instance.disconnectUser();
  }

  /// Reactive stream of unseen notification count
  ///
  /// Emits the current count whenever it changes on the native side.
  /// If a value was already received before subscribing, it is replayed
  /// immediately so that late subscribers don't miss the initial count.
  /// Listen to this stream to update a badge indicator in your UI.
  static Stream<int> get notSeenNotificationsCount async* {
    _initializeEventChannel();
    if (_lastNotSeenNotificationsCount != null) {
      yield _lastNotSeenNotificationsCount!;
    }
    yield* eventStream
        .where((event) => event['event'] == 'notSeenNotificationsCountChanged')
        .map((event) => event['count'] as int);
  }

  /// Force refresh the unseen notification count from the server
  Future<void> updateNotSeenNotificationsCount() {
    return OctopusSDKPlatform.instance.updateNotSeenNotificationsCount();
  }

  /// Reactive stream indicating whether the current user has access to the community
  ///
  /// Useful for A/B testing or gating community features.
  /// If a value was already received before subscribing, it is replayed
  /// immediately so that late subscribers don't miss the initial value.
  static Stream<bool> get hasAccessToCommunity async* {
    _initializeEventChannel();
    if (_lastHasAccessToCommunity != null) {
      yield _lastHasAccessToCommunity!;
    }
    yield* eventStream
        .where((event) => event['event'] == 'hasAccessToCommunityChanged')
        .map((event) => event['hasAccess'] as bool);
  }

  /// Override the community access cohort attribution
  ///
  /// [hasAccess] - Whether the user should have access to the community
  Future<void> overrideCommunityAccess(bool hasAccess) {
    return OctopusSDKPlatform.instance.overrideCommunityAccess(hasAccess);
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
  Future<void> trackCustomEvent(String name, [Map<String, String> properties = const {}]) {
    return OctopusSDKPlatform.instance.trackCustomEvent(name, properties);
  }

  Future<void> showOctopusHomeScreen(
    BuildContext context, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    UrlOpeningStrategy Function(String)? onNavigateToUrl,
    Widget? closeWidget,
  }) async {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      enableDrag: false,
      useSafeArea: false,
      builder: (bottomSheetContext) {
        return OctopusHomeScreen(
          navBarTitle: navBarTitle,
          showBackButton: true,
          navBarPrimaryColor: navBarPrimaryColor,
          theme: theme,
          onNavigateToLogin: onNavigateToLogin,
          onModifyUser: onModifyUser,
          onNavigateToUrl: onNavigateToUrl,
          onBack: () => Navigator.of(bottomSheetContext).pop(),
        );
      },
    );
  }
}
