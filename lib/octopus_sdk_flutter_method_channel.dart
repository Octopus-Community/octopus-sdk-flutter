import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'octopus_sdk_flutter_platform_interface.dart';

/// An implementation of [OctopusSdkFlutterPlatform] that uses method channels.
class MethodChannelOctopusSdkFlutter extends OctopusSdkFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('octopus_sdk_flutter');
  static const String viewType = 'octopus_sdk_flutter/native_view';

  @override
  Future<void> initializeOctopusSDK({
    required String apiKey,
    List<String>? appManagedFields,
  }) async {
    await methodChannel.invokeMethod('initializeOctopusSDK', {
      'apiKey': apiKey,
      'appManagedFields': appManagedFields,
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
  Future<void> showNativeUI({
    String navBarLeading = 'logo',
    String? navBarTitle,
    bool navBarPrimaryColor = false,
    int? primaryMain,
    int? primaryLowContrast,
    int? primaryHighContrast,
    int? onPrimary,
    String? logoBase64,
    int? fontSizeTitle1,
    int? fontSizeTitle2,
    int? fontSizeBody1,
    int? fontSizeBody2,
    int? fontSizeCaption1,
    int? fontSizeCaption2,
    String? themeMode,
    String? onNavigateToLoginCallbackId,
    String? onModifyUserCallbackId,
  }) async {
    await methodChannel.invokeMethod('showNativeUI', {
      'navBarLeading': navBarLeading,
      'navBarTitle': navBarTitle,
      'navBarPrimaryColor': navBarPrimaryColor,
      'primaryMain': primaryMain,
      'primaryLowContrast': primaryLowContrast,
      'primaryHighContrast': primaryHighContrast,
      'onPrimary': onPrimary,
      'logoBase64': logoBase64,
      'fontSizeTitle1': fontSizeTitle1,
      'fontSizeTitle2': fontSizeTitle2,
      'fontSizeBody1': fontSizeBody1,
      'fontSizeBody2': fontSizeBody2,
      'fontSizeCaption1': fontSizeCaption1,
      'fontSizeCaption2': fontSizeCaption2,
      'themeMode': themeMode,
      'onNavigateToLoginCallbackId': onNavigateToLoginCallbackId,
      'onModifyUserCallbackId': onModifyUserCallbackId,
    });
  }

  @override
  Future<void> closeNativeUI() async {
    await methodChannel.invokeMethod('closeNativeUI');
  }
}
