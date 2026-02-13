import 'dart:ui' show Locale;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'profile_field.dart';
import 'octopus_sdk_method_channel.dart';

abstract class OctopusSDKPlatform extends PlatformInterface {
  /// Constructs a OctopusSDKPlatform.
  OctopusSDKPlatform() : super(token: _token);

  static final Object _token = Object();

  static OctopusSDKPlatform _instance = OctopusSDKMethodChannel();

  /// The default instance of [OctopusSDKPlatform] to use.
  ///
  /// Defaults to [OctopusSDKMethodChannel].
  static OctopusSDKPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OctopusSDKPlatform] when
  /// they register themselves.
  static set instance(OctopusSDKPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
  }) {
    throw UnimplementedError(
      'initialize() has not been implemented.',
    );
  }

  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
  }) {
    throw UnimplementedError(
      'initializeOctopusAuth() has not been implemented.',
    );
  }

  Future<void> connectUser({
    required String userId,
    required String token,
    String? nickname,
    String? bio,
    String? picture
  }) {
    throw UnimplementedError('connectUser() has not been implemented.');
  }

  Future<void> disconnectUser() {
    throw UnimplementedError('disconnectUser() has not been implemented.');
  }

  Future<void> updateNotSeenNotificationsCount() {
    throw UnimplementedError(
      'updateNotSeenNotificationsCount() has not been implemented.',
    );
  }

  Future<void> overrideCommunityAccess(bool hasAccess) {
    throw UnimplementedError(
      'overrideCommunityAccess() has not been implemented.',
    );
  }

  Future<void> trackCommunityAccess(bool hasAccess) {
    throw UnimplementedError(
      'trackCommunityAccess() has not been implemented.',
    );
  }

  Future<void> overrideDefaultLocale(Locale? locale) {
    throw UnimplementedError(
      'overrideDefaultLocale() has not been implemented.',
    );
  }

  Future<void> trackCustomEvent(String name, Map<String, String> properties) {
    throw UnimplementedError(
      'trackCustomEvent() has not been implemented.',
    );
  }
}