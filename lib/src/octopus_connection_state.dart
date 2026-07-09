import 'package:flutter/foundation.dart' show immutable;

/// Reactive snapshot of the SDK's user-connection state.
///
/// Exposed via [OctopusSDK.connectionState]. Mirrors the native Android
/// `ConnectionState` sealed interface (`NotConnected` / `Connected`). On iOS it
/// is derived from the native `profile` publisher, and the guest flag is read
/// from the profile (native iOS 1.12.6+) — see [OctopusConnected.isGuest].
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
/// an anonymous guest — see [isGuest].
class OctopusConnected extends OctopusConnectionState {
  /// Whether the connected user is a guest (anonymous) session.
  ///
  /// Reported on both platforms: Android exposes it natively; iOS exposes it via
  /// `OctopusProfile.isGuest` since native SDK 1.12.6 (older iOS SDKs always
  /// reported `false`). To gate features on a fully authenticated user, prefer
  /// [OctopusSDK.isUserConnected] (`true` only for a connected, non-guest user).
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
