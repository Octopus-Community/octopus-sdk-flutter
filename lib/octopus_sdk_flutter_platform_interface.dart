import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'octopus_sdk_flutter_method_channel.dart';

abstract class OctopusSdkFlutterPlatform extends PlatformInterface {
  /// Constructs a OctopusSdkFlutterPlatform.
  OctopusSdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static OctopusSdkFlutterPlatform _instance = MethodChannelOctopusSdkFlutter();

  /// The default instance of [OctopusSdkFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelOctopusSdkFlutter].
  static OctopusSdkFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OctopusSdkFlutterPlatform] when
  /// they register themselves.
  static set instance(OctopusSdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initializeOctopusSDK({
    required String apiKey,
    List<String>? appManagedFields,
  }) {
    throw UnimplementedError(
      'initializeOctopusSDK() has not been implemented.',
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
}
