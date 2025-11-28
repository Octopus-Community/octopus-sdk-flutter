import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'octopus_sdk_flutter_platform_interface.dart';
import 'octopus_theme.dart';
import 'octopus_view.dart';

// Export the new OctopusView widgets
export 'octopus_view.dart';

// Global callback registry for handling platform view callbacks
final Map<String, VoidCallback> _callbackRegistry = {};
final Map<String, Function(String?)> _modifyUserCallbackRegistry = {};

// Event stream controller for native events
StreamController<Map<String, dynamic>>? _eventStreamController;
EventChannel? _eventChannel;

class OctopusSdkFlutter {
  static const MethodChannel _methodChannel = MethodChannel(
    'octopus_sdk_flutter',
  );

  static void _initializeMethodChannel() {
    _methodChannel.setMethodCallHandler((call) async {
      print('Flutter: Method call received: ${call.method}');
      if (call.method == 'onNavigateToLogin') {
        final callbackId = call.arguments as String?;
        print('Flutter: onNavigateToLogin callback ID: $callbackId');
        if (callbackId != null) {
          final callback = _callbackRegistry[callbackId];
          print('Flutter: Found callback: ${callback != null}');
          callback?.call();
          print('Flutter: Callback executed');
        }
      } else if (call.method == 'onModifyUser') {
        final args = call.arguments as Map<String, dynamic>?;
        final callbackId = args?['callbackId'] as String?;
        final fieldToEdit = args?['fieldToEdit'] as String?;
        print(
          'Flutter: onModifyUser callback ID: $callbackId, fieldToEdit: $fieldToEdit',
        );
        print(
          'Flutter: Available callbacks in registry: ${_modifyUserCallbackRegistry.keys}',
        );
        if (callbackId != null) {
          final callback = _modifyUserCallbackRegistry[callbackId];
          print('Flutter: Found callback: ${callback != null}');
          if (callback != null) {
            callback.call(fieldToEdit);
            print('Flutter: Callback executed successfully');
          } else {
            print('Flutter: Callback not found for ID: $callbackId');
          }
        } else {
          print('Flutter: No callback ID provided');
        }
      }
    });
  }

  static void _initializeEventChannel() {
    if (_eventChannel == null) {
      _eventChannel = const EventChannel('octopus_sdk_flutter/events');
      _eventStreamController =
          StreamController<Map<String, dynamic>>.broadcast();

      _eventChannel!.receiveBroadcastStream().listen((event) {
        print('Flutter: Event received: $event');
        _eventStreamController?.add(Map<String, dynamic>.from(event));
      });
    }
  }

  static Stream<Map<String, dynamic>> get eventStream {
    _initializeEventChannel();
    return _eventStreamController!.stream;
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
  /// Valid field names (only these 3 values are supported):
  /// - 'NICKNAME': User's display name
  /// - 'AVATAR': User's profile picture
  /// - 'BIO': User's biography/description
  ///
  /// Example:
  /// ```dart
  /// await OctopusSdkFlutter().initializeOctopusSDK(
  ///   apiKey: 'your-api-key',
  ///   appManagedFields: ['NICKNAME', 'AVATAR', 'BIO'],
  /// );
  /// ```
  ///
  /// If empty or null, all fields will be managed by Octopus Community (default behavior).
  Future<void> initializeOctopusSDK({
    required String apiKey,
    List<String>? appManagedFields,
  }) {
    return OctopusSdkFlutterPlatform.instance.initializeOctopusSDK(
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
    return OctopusSdkFlutterPlatform.instance.initializeOctopusAuth(
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
  /// [onNavigateToLogin] - Callback function called when the user navigates to login
  /// [onModifyUser] - Callback function called when the user wants to modify their profile
  static Widget embeddedView({
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    bool showBackButton = true,
    OctopusTheme? theme,
    VoidCallback? onNavigateToLogin,
    Function(String?)? onModifyUser,
    VoidCallback? onBack,
  }) {
    const viewType = 'octopus_sdk_flutter/native_view';

    // Initialize event channel if not already done
    _initializeEventChannel();
    // Initialize method channel handler if not already done
    _initializeMethodChannel();

    final themeMap = theme?.toMap() ?? <String, dynamic>{};

    // Generate unique callback IDs and register callbacks
    String? onNavigateToLoginCallbackId;
    String? onModifyUserCallbackId;
    String? onBackCallbackId;

    if (onNavigateToLogin != null) {
      onNavigateToLoginCallbackId =
          DateTime.now().millisecondsSinceEpoch.toString() + '_login';
      _callbackRegistry[onNavigateToLoginCallbackId] = onNavigateToLogin;
    }

    if (onModifyUser != null) {
      onModifyUserCallbackId =
          DateTime.now().millisecondsSinceEpoch.toString() + '_modify';
      _modifyUserCallbackRegistry[onModifyUserCallbackId] = onModifyUser;
    }

    if (onBack != null) {
      onBackCallbackId =
          DateTime.now().millisecondsSinceEpoch.toString() + '_back';
      _callbackRegistry[onBackCallbackId] = onBack;
    }

    final creationParams = <String, dynamic>{
      if (navBarTitle != null) 'navBarTitle': navBarTitle,
      'navBarPrimaryColor': navBarPrimaryColor,
      'showBackButton': showBackButton,
      if (theme != null) ...themeMap,
      if (onNavigateToLoginCallbackId != null)
        'onNavigateToLoginCallbackId': onNavigateToLoginCallbackId,
      if (onModifyUserCallbackId != null)
        'onModifyUserCallbackId': onModifyUserCallbackId,
      if (onBackCallbackId != null) 'onBackCallbackId': onBackCallbackId,
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
  /// Note: You must call initializeOctopusSDK() before connecting a user
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
    return OctopusSdkFlutterPlatform.instance.connectUser(
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
  /// Note: You must call initializeOctopusSDK() before connecting a user
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
    return OctopusSdkFlutterPlatform.instance.disconnectUser();
  }

  Future<void> showOctopusView(
    BuildContext context, {
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    OctopusTheme? theme,
    required VoidCallback onNavigateToLogin,
    Function(String?)? onModifyUser,
    Widget? closeWidget,
  }) async {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      enableDrag: false,
      useSafeArea: false,
      builder: (bottomSheetContext) {
        return OctopusView(
          navBarTitle: navBarTitle,
          showBackButton: true,
          navBarPrimaryColor: navBarPrimaryColor,
          theme: theme,
          onNavigateToLogin: onNavigateToLogin,
          onModifyUser: onModifyUser,
          onBack: () => Navigator.of(bottomSheetContext).pop(),
        );
      },
    );
  }
}
