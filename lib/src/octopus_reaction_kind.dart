import 'package:flutter/foundation.dart' show immutable;

/// A reaction kind that can be set on a post via [OctopusSDK.setReaction].
///
/// Mirrors the native `OctopusReactionKind` (a sealed type on both Android and
/// iOS). It is modelled as a **sealed class, not an enum**, so a future
/// server-side reaction surfaces as [OctopusUnknownReaction] without requiring
/// a new SDK release.
///
/// Use the const singletons for the six known kinds:
/// ```dart
/// await octopus.setReaction(OctopusReactionKind.heart, postId);
/// await octopus.setReaction(null, postId); // remove the current reaction
/// ```
///
/// Passing an [OctopusUnknownReaction] to [OctopusSDK.setReaction] is not
/// supported by the backend and fails with [SetReactionUnknownReactionError];
/// the case exists for forward-compatible *decoding* of reactions coming from a
/// newer backend.
@immutable
sealed class OctopusReactionKind {
  const OctopusReactionKind();

  /// The unicode emoji representing this reaction (e.g. `❤️`). For
  /// [OctopusUnknownReaction] this is the raw value sent by the backend.
  String get unicode;

  /// ❤️
  static const OctopusReactionKind heart = OctopusHeartReaction();

  /// 😂
  static const OctopusReactionKind joy = OctopusJoyReaction();

  /// 😮
  static const OctopusReactionKind mouthOpen = OctopusMouthOpenReaction();

  /// 👏
  static const OctopusReactionKind clap = OctopusClapReaction();

  /// 😢
  static const OctopusReactionKind cry = OctopusCryReaction();

  /// 😡
  static const OctopusReactionKind rage = OctopusRageReaction();

  /// The six known reaction kinds, in display order. Does not include
  /// [OctopusUnknownReaction].
  static const List<OctopusReactionKind> knownValues = <OctopusReactionKind>[
    heart,
    joy,
    mouthOpen,
    clap,
    cry,
    rage,
  ];

  /// Encodes this kind for the platform channel. Known kinds serialize as
  /// `{'kind': '<name>'}`; [OctopusUnknownReaction] adds its `serverValue`.
  Map<String, dynamic> toWire();

  /// Decodes a platform-channel reaction map (the inverse of [toWire]).
  ///
  /// An unrecognized or missing `kind` folds to [OctopusUnknownReaction],
  /// carrying the raw `serverValue` when present — so a reaction introduced by
  /// a newer backend round-trips instead of throwing.
  factory OctopusReactionKind.fromWire(Map<String, dynamic> wire) {
    switch (wire['kind']) {
      case 'heart':
        return heart;
      case 'joy':
        return joy;
      case 'mouthOpen':
        return mouthOpen;
      case 'clap':
        return clap;
      case 'cry':
        return cry;
      case 'rage':
        return rage;
      case 'unknown':
      default:
        final serverValue = wire['serverValue'];
        return OctopusUnknownReaction(serverValue is String ? serverValue : '');
    }
  }
}

/// ❤️ reaction.
@immutable
final class OctopusHeartReaction extends OctopusReactionKind {
  const OctopusHeartReaction();
  @override
  String get unicode => '❤️';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'heart'};
  @override
  bool operator ==(Object other) => other is OctopusHeartReaction;
  @override
  int get hashCode => (OctopusHeartReaction).hashCode;
  @override
  String toString() => 'OctopusHeartReaction()';
}

/// 😂 reaction.
@immutable
final class OctopusJoyReaction extends OctopusReactionKind {
  const OctopusJoyReaction();
  @override
  String get unicode => '😂';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'joy'};
  @override
  bool operator ==(Object other) => other is OctopusJoyReaction;
  @override
  int get hashCode => (OctopusJoyReaction).hashCode;
  @override
  String toString() => 'OctopusJoyReaction()';
}

/// 😮 reaction.
@immutable
final class OctopusMouthOpenReaction extends OctopusReactionKind {
  const OctopusMouthOpenReaction();
  @override
  String get unicode => '😮';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'mouthOpen'};
  @override
  bool operator ==(Object other) => other is OctopusMouthOpenReaction;
  @override
  int get hashCode => (OctopusMouthOpenReaction).hashCode;
  @override
  String toString() => 'OctopusMouthOpenReaction()';
}

/// 👏 reaction.
@immutable
final class OctopusClapReaction extends OctopusReactionKind {
  const OctopusClapReaction();
  @override
  String get unicode => '👏';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'clap'};
  @override
  bool operator ==(Object other) => other is OctopusClapReaction;
  @override
  int get hashCode => (OctopusClapReaction).hashCode;
  @override
  String toString() => 'OctopusClapReaction()';
}

/// 😢 reaction.
@immutable
final class OctopusCryReaction extends OctopusReactionKind {
  const OctopusCryReaction();
  @override
  String get unicode => '😢';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'cry'};
  @override
  bool operator ==(Object other) => other is OctopusCryReaction;
  @override
  int get hashCode => (OctopusCryReaction).hashCode;
  @override
  String toString() => 'OctopusCryReaction()';
}

/// 😡 reaction.
@immutable
final class OctopusRageReaction extends OctopusReactionKind {
  const OctopusRageReaction();
  @override
  String get unicode => '😡';
  @override
  Map<String, dynamic> toWire() => const {'kind': 'rage'};
  @override
  bool operator ==(Object other) => other is OctopusRageReaction;
  @override
  int get hashCode => (OctopusRageReaction).hashCode;
  @override
  String toString() => 'OctopusRageReaction()';
}

/// A reaction kind the SDK does not recognize, typically coming from a more
/// up-to-date backend. [serverValue] carries the raw identifier (the unicode
/// emoji string) so it can be displayed or round-tripped.
///
/// Setting this kind via [OctopusSDK.setReaction] is rejected by the backend
/// with [SetReactionUnknownReactionError].
@immutable
final class OctopusUnknownReaction extends OctopusReactionKind {
  /// The raw reaction identifier sent by the backend (the unicode/emoji string).
  final String serverValue;

  const OctopusUnknownReaction(this.serverValue);

  @override
  String get unicode => serverValue;

  @override
  Map<String, dynamic> toWire() =>
      {'kind': 'unknown', 'serverValue': serverValue};

  @override
  bool operator ==(Object other) =>
      other is OctopusUnknownReaction && other.serverValue == serverValue;

  @override
  int get hashCode => serverValue.hashCode;

  @override
  String toString() => 'OctopusUnknownReaction($serverValue)';
}
