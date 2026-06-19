import 'package:flutter/foundation.dart' show immutable;

/// Reactive snapshot of the SDK's user-connection state.
///
/// Exposed via [OctopusSDK.connectionState]. Mirrors the native Android
/// `ConnectionState` sealed interface (`NotConnected` / `Connected`). On iOS,
/// only the connected/not-connected distinction is observable through the
/// public surface — see [OctopusConnected.isGuest] for the guest-flag platform
/// asymmetry.
@immutable
sealed class OctopusConnectionState {
  const OctopusConnectionState();
}

/// No user is currently connected to the Octopus platform.
class OctopusNotConnected extends OctopusConnectionState {
  const OctopusNotConnected();

  @override
  bool operator ==(Object other) => other is OctopusNotConnected;

  @override
  int get hashCode => (OctopusNotConnected).hashCode;

  @override
  String toString() => 'OctopusNotConnected()';
}

/// A user is connected. The connection may be a regular authenticated user or
/// (on Android only) an anonymous guest — see [isGuest].
class OctopusConnected extends OctopusConnectionState {
  /// Whether the connected user is a guest (anonymous) session.
  ///
  /// **Platform asymmetry.** Only Android distinguishes guest connections in
  /// the public SDK surface. On iOS, the SDK does not expose guest status, so
  /// this field is always `false` even if the underlying session is a guest
  /// one. Code that needs to gate features on non-guest status should rely on
  /// [OctopusSDK.isUserConnected], which already encodes this asymmetry:
  /// `true` only for non-guest connections on Android, and `true` for any
  /// connection on iOS.
  final bool isGuest;

  const OctopusConnected({this.isGuest = false});

  @override
  bool operator ==(Object other) =>
      other is OctopusConnected && other.isGuest == isGuest;

  @override
  int get hashCode => Object.hash(OctopusConnected, isGuest);

  @override
  String toString() => 'OctopusConnected(isGuest: $isGuest)';
}
