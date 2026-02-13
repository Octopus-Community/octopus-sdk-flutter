/// Profile fields that can be managed by your app instead of Octopus Community.
///
/// When a field is in the [appManagedFields] list during initialization,
/// users will not be able to edit it directly in the Octopus Community interface.
/// Instead, your app should handle editing through the [onModifyUser] callback.
enum ProfileField {
  /// User's display name
  nickname,

  /// User's profile picture
  picture,

  /// User's biography/description
  bio;

  /// Converts to the string value expected by the native SDKs.
  String toNativeValue() {
    switch (this) {
      case ProfileField.nickname:
        return 'NICKNAME';
      case ProfileField.picture:
        return 'AVATAR';
      case ProfileField.bio:
        return 'BIO';
    }
  }
}