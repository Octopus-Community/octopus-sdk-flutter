import 'package:flutter/foundation.dart' show immutable, setEquals;

/// The public-facing profile of the connected user.
///
/// Exposed via [OctopusSDK.profile]. Mirrors the native `OctopusProfile`
/// (Android + iOS). Future profile fields will be added here — **additive
/// only; no breaking changes**.
@immutable
class OctopusProfile {
  /// Held entitlement identifiers (opaque tokens defined by the host app).
  ///
  /// Display only — the SDK never intersects this set against per-group
  /// requirements. Group access decisions are pre-resolved by the backend.
  final Set<String> entitlements;

  const OctopusProfile({this.entitlements = const <String>{}});

  /// Decodes the platform-channel representation. Reads defensively: a
  /// missing/malformed `entitlements` list yields an empty set rather than
  /// throwing into the host app.
  factory OctopusProfile.fromWire(Map<dynamic, dynamic> wire) {
    final raw = wire['entitlements'];
    return OctopusProfile(
      entitlements: raw is List ? raw.whereType<String>().toSet() : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusProfile && setEquals(other.entitlements, entitlements);

  @override
  int get hashCode => Object.hashAllUnordered(entitlements);

  @override
  String toString() => 'OctopusProfile(entitlements: $entitlements)';
}
