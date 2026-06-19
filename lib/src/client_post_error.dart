import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.fetchOrCreateClientObjectRelatedPost]
/// inside an [OctopusInvalidArguments].
///
/// Mirrors the native `ClientPostError`. Modelled as a **flat** sealed class
/// (matching the existing Flutter convention — `SetReactionError`,
/// `RefreshEntitlementsError`), not the nested Android hierarchy
/// (`ClientPostError.TextError.Missing`, …): the leaf type carries the same
/// information without the extra nesting.
///
/// Platform contract: connection/auth failures (no network, user not connected)
/// are **not** modelled here — they surface through the orthogonal
/// [OctopusConnectionFailure] branch of the [OctopusResult] ([OctopusNoNetwork],
/// …), matching the native Android SDK. Only content/validation errors flow
/// through [OctopusInvalidArguments].
///
/// **Platform note**: on Android the specific typed errors below are produced.
/// On iOS the native SDK does **not** expose the validation error kind
/// publicly (`ClientPostError.ValidationError`'s fields are internal), so
/// validation failures surface as [ClientPostOtherError] carrying the native
/// description. Both platforms route no-network through [OctopusNoNetwork].
@immutable
sealed class ClientPostError implements OctopusServerError {
  const ClientPostError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: an unrecognized/missing `type` folds to
  /// [ClientPostOtherError], and a missing/non-String `message` falls back to a
  /// placeholder.
  factory ClientPostError.fromWire(Map<String, dynamic> wire) {
    final message = wire['message'] is String
        ? wire['message'] as String
        : 'Client post error';
    switch (wire['type']) {
      case 'textMissing':
        return const ClientPostTextMissingError();
      case 'textTooLong':
        return const ClientPostTextTooLongError();
      case 'fileEmpty':
        return const ClientPostFileEmptyError();
      case 'fileTooLarge':
        return const ClientPostFileTooLargeError();
      case 'fileBadFormat':
        return const ClientPostFileBadFormatError();
      case 'fileUpload':
        return const ClientPostFileUploadError();
      case 'fileDownload':
        return const ClientPostFileDownloadError();
      case 'missingObjectId':
        return const ClientPostMissingObjectIdError();
      case 'missingCta':
        return const ClientPostMissingCtaError();
      case 'postUnavailable':
        return const ClientPostUnavailableError();
      case 'postNotFound':
        return const ClientPostNotFoundError();
      case 'postAlreadyExists':
        return const ClientPostAlreadyExistsError();
      case 'invalidGroupId':
        return const ClientPostInvalidGroupIdError();
      case 'invalidAuthor':
        return const ClientPostInvalidAuthorError();
      case 'tokenInvalid':
        return const ClientPostTokenInvalidError();
      case 'tokenExpired':
        return const ClientPostTokenExpiredError();
      case 'other':
      default:
        return ClientPostOtherError(message);
    }
  }
}

/// Base for the const-message typed leaves. Each fixed-message error is a
/// singleton, mirroring how `SetReactionError`'s typed cases work.
@immutable
abstract base class _FixedMessageClientPostError extends ClientPostError {
  const _FixedMessageClientPostError();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => '$runtimeType()';
}

/// The post text is missing or empty.
@immutable
final class ClientPostTextMissingError extends _FixedMessageClientPostError {
  const ClientPostTextMissingError();
  @override
  String get errorMessage => 'Post text is required';
}

/// The post text exceeds the maximum character limit.
@immutable
final class ClientPostTextTooLongError extends _FixedMessageClientPostError {
  const ClientPostTextTooLongError();
  @override
  String get errorMessage => 'Post text is too long';
}

/// The provided image file is empty.
@immutable
final class ClientPostFileEmptyError extends _FixedMessageClientPostError {
  const ClientPostFileEmptyError();
  @override
  String get errorMessage => 'The image file is empty';
}

/// The provided image exceeds the maximum allowed size.
@immutable
final class ClientPostFileTooLargeError extends _FixedMessageClientPostError {
  const ClientPostFileTooLargeError();
  @override
  String get errorMessage => 'The image file is too large';
}

/// The provided image format is unsupported or corrupted.
@immutable
final class ClientPostFileBadFormatError extends _FixedMessageClientPostError {
  const ClientPostFileBadFormatError();
  @override
  String get errorMessage => 'The image format is not supported';
}

/// Uploading the image failed.
@immutable
final class ClientPostFileUploadError extends _FixedMessageClientPostError {
  const ClientPostFileUploadError();
  @override
  String get errorMessage => 'The image could not be uploaded';
}

/// Downloading the remote image failed.
@immutable
final class ClientPostFileDownloadError extends _FixedMessageClientPostError {
  const ClientPostFileDownloadError();
  @override
  String get errorMessage => 'The remote image could not be downloaded';
}

/// The client object id is missing or empty.
@immutable
final class ClientPostMissingObjectIdError
    extends _FixedMessageClientPostError {
  const ClientPostMissingObjectIdError();
  @override
  String get errorMessage => 'The client object id is required';
}

/// The view-object button text (call to action) is missing when required.
@immutable
final class ClientPostMissingCtaError extends _FixedMessageClientPostError {
  const ClientPostMissingCtaError();
  @override
  String get errorMessage => 'The call-to-action text is required';
}

/// The bridge post exists but is unavailable (e.g. moderated or deleted).
@immutable
final class ClientPostUnavailableError extends _FixedMessageClientPostError {
  const ClientPostUnavailableError();
  @override
  String get errorMessage => 'The bridge post is unavailable';
}

/// No bridge post exists yet for this client object.
@immutable
final class ClientPostNotFoundError extends _FixedMessageClientPostError {
  const ClientPostNotFoundError();
  @override
  String get errorMessage => 'The bridge post was not found';
}

/// A bridge post already exists for this client object.
@immutable
final class ClientPostAlreadyExistsError extends _FixedMessageClientPostError {
  const ClientPostAlreadyExistsError();
  @override
  String get errorMessage => 'A bridge post already exists for this object';
}

/// The specified group id is invalid or unavailable.
@immutable
final class ClientPostInvalidGroupIdError extends _FixedMessageClientPostError {
  const ClientPostInvalidGroupIdError();
  @override
  String get errorMessage => 'The group id is invalid';
}

/// The author is not authorized to create posts for this object.
@immutable
final class ClientPostInvalidAuthorError extends _FixedMessageClientPostError {
  const ClientPostInvalidAuthorError();
  @override
  String get errorMessage => 'The author is not authorized';
}

/// The authentication token (bridge signature) is invalid or malformed.
@immutable
final class ClientPostTokenInvalidError extends _FixedMessageClientPostError {
  const ClientPostTokenInvalidError();
  @override
  String get errorMessage => 'The authentication token is invalid';
}

/// The authentication token (bridge signature) has expired.
@immutable
final class ClientPostTokenExpiredError extends _FixedMessageClientPostError {
  const ClientPostTokenExpiredError();
  @override
  String get errorMessage => 'The authentication token has expired';
}

/// An unspecified or unrecognized error. Carries the native-provided
/// [errorMessage]. On iOS, validation failures surface here.
@immutable
final class ClientPostOtherError extends ClientPostError {
  @override
  final String errorMessage;

  const ClientPostOtherError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientPostOtherError && other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'ClientPostOtherError($errorMessage)';
}
