import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'profile_field.dart';
import 'octopus_sdk_platform.dart';

/// An implementation of [OctopusSDKPlatform] that uses method channels.
class OctopusSDKMethodChannel extends OctopusSDKPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('octopus_sdk_flutter');
  static const String viewType = 'octopus_sdk_flutter/native_view';

  @override
  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
  }) async {
    await methodChannel.invokeMethod('initialize', {
      'apiKey': apiKey,
      'appManagedFields': appManagedFields?.map((f) => f.toNativeValue()).toList(),
    });
  }

  @override
  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
  }) async {
    await methodChannel.invokeMethod('initializeOctopusAuth', {
      'apiKey': apiKey,
      'deepLink': deepLink,
    });
  }

  @override
  Future<void> connectUser({
    required String userId,
    required String token,
    String? nickname,
    String? bio,
    String? picture
  }) async {
    await methodChannel.invokeMethod('connectUser', {
      'userId': userId,
      'token': token,
      'nickname': nickname,
      'bio': bio,
      'picture': picture
    });
  }

  @override
  Future<void> disconnectUser() async {
    await methodChannel.invokeMethod('disconnectUser');
  }

  @override
  Future<void> updateNotSeenNotificationsCount() async {
    await methodChannel.invokeMethod('updateNotSeenNotificationsCount');
  }

  @override
  Future<void> overrideCommunityAccess(bool hasAccess) async {
    await methodChannel.invokeMethod('overrideCommunityAccess', {
      'hasAccess': hasAccess,
    });
  }

  @override
  Future<void> trackCommunityAccess(bool hasAccess) async {
    await methodChannel.invokeMethod('trackCommunityAccess', {
      'hasAccess': hasAccess,
    });
  }

  @override
  Future<void> overrideDefaultLocale(Locale? locale) async {
    await methodChannel.invokeMethod('overrideDefaultLocale', {
      'languageCode': locale?.languageCode,
      'countryCode': locale?.countryCode,
    });
  }

  @override
  Future<void> trackCustomEvent(String name, Map<String, String> properties) async {
    await methodChannel.invokeMethod('trackCustomEvent', {
      'name': name,
      'properties': properties,
    });
  }

}