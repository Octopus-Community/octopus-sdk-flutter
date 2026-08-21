import 'package:flutter/foundation.dart' show immutable;

/// Per-field editability status of a profile field, driven by the community
/// configuration.
///
/// [disabled] is only meaningful for [ProfileFieldsLock.bio] (the field
/// disappears entirely); [ProfileFieldsLock.nickname] and
/// [ProfileFieldsLock.avatar] can only be [editable] or [readOnly].
enum ProfileFieldLockState {
  /// Default behaviour: the field is displayed and modifiable.
  editable,

  /// The value is displayed but no longer modifiable (edit stays inside
  /// Octopus, no redirect).
  readOnly,

  /// The field disappears entirely (bio only): no display even of an
  /// existing value, no "Add a bio".
  disabled;

  /// Converts to the string value expected by the native SDKs.
  ///
  /// Wire format mirrors the native enum names: `EDITABLE`, `READ_ONLY`,
  /// `DISABLED`. These strings must match the keys handled by the Android
  /// Kotlin bridge: if any of the three fields carries a value it does not
  /// recognize, the bridge fails closed and drops the *whole*
  /// `ProfileFieldsLock` override (no lock is applied), rather than
  /// defaulting the unrecognized field to the most permissive state.
  String toNativeValue() {
    switch (this) {
      case ProfileFieldLockState.editable:
        return 'EDITABLE';
      case ProfileFieldLockState.readOnly:
        return 'READ_ONLY';
      case ProfileFieldLockState.disabled:
        return 'DISABLED';
    }
  }
}

/// Per-field profile lock for the current community.
///
/// Internal test affordance mirroring the native SDKs' debug-only
/// `debugOverrideProfileFieldsLock` (Android `@InternalOctopusApi`, iOS
/// `@_spi(OctopusInternalTesting)`): it locally overrides the per-field
/// profile lock without a backend-driven config, for exercising the locked
/// profile-edit UI in development builds and the sample app. **Not part of
/// the supported public API** — it may change or be removed at any time.
///
/// Absent config — or every field [ProfileFieldLockState.editable] — is a
/// strict no-op: the profile and edit screens behave exactly as if no lock
/// were set.
@immutable
class ProfileFieldsLock {
  /// Status of the username. Only [ProfileFieldLockState.editable] /
  /// [ProfileFieldLockState.readOnly].
  final ProfileFieldLockState nickname;

  /// Status of the profile picture. Only [ProfileFieldLockState.editable] /
  /// [ProfileFieldLockState.readOnly].
  final ProfileFieldLockState avatar;

  /// Status of the bio. May additionally be [ProfileFieldLockState.disabled].
  final ProfileFieldLockState bio;

  /// Creates a [ProfileFieldsLock]. Every field defaults to
  /// [ProfileFieldLockState.editable] (today's behaviour).
  const ProfileFieldsLock({
    this.nickname = ProfileFieldLockState.editable,
    this.avatar = ProfileFieldLockState.editable,
    this.bio = ProfileFieldLockState.editable,
  });

  /// Every field [ProfileFieldLockState.editable] — the native SDKs' default
  /// when no lock is set.
  static const allEditable = ProfileFieldsLock();

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'nickname': nickname.toNativeValue(),
        'avatar': avatar.toNativeValue(),
        'bio': bio.toNativeValue(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileFieldsLock &&
          other.nickname == nickname &&
          other.avatar == avatar &&
          other.bio == bio;

  @override
  int get hashCode => Object.hash(nickname, avatar, bio);

  @override
  String toString() =>
      'ProfileFieldsLock(nickname: $nickname, avatar: $avatar, bio: $bio)';
}
