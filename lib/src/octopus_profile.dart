import 'package:flutter/foundation.dart' show immutable, setEquals;

/// The public-facing profile of the connected user.
///
/// Exposed via [OctopusSDK.profile]. Mirrors the native Android
/// `OctopusProfile`; the iOS one additionally carries an `isGuest` flag, which
/// this SDK reads off [OctopusSDK.connectionState] instead (see
/// `OctopusConnected.isGuest`) — as Android does. Future profile fields will be
/// added here — **additive only; no breaking changes**.
@immutable
class OctopusProfile {
  /// Held entitlement identifiers (opaque tokens defined by the host app).
  ///
  /// Display only — the SDK never intersects this set against per-group
  /// requirements. Group access decisions are pre-resolved by the backend.
  final Set<String> entitlements;

  /// The connected user's id in **your** app's system, as passed to
  /// `connectUser` — the counterpart of the Octopus profile id.
  ///
  /// Populated in SSO mode for a non-guest user; `null` in
  /// Octopus-authentication mode (there is no host-side id) and for a guest.
  /// It is held locally by the native SDKs, **independent of the community's
  /// expose-client-user-ids setting** — that setting gates *other* members'
  /// client user ids, not the connected user's. Use it to correlate the Octopus
  /// profile with your own user record, e.g. when enriching your profile screen
  /// with [OctopusSDK.fetchCommunityData].
  final String? clientUserId;

  const OctopusProfile({
    this.entitlements = const <String>{},
    this.clientUserId,
  });

  /// Decodes the platform-channel representation. Reads defensively: a
  /// missing/malformed `entitlements` list yields an empty set rather than
  /// throwing into the host app.
  factory OctopusProfile.fromWire(Map<dynamic, dynamic> wire) {
    final raw = wire['entitlements'];
    return OctopusProfile(
      entitlements: raw is List ? raw.whereType<String>().toSet() : const {},
      clientUserId: wire['clientUserId'] is String
          ? wire['clientUserId'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusProfile &&
      setEquals(other.entitlements, entitlements) &&
      other.clientUserId == clientUserId;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(entitlements), clientUserId);

  @override
  String toString() => 'OctopusProfile(entitlements: $entitlements, '
      'clientUserId: $clientUserId)';
}
