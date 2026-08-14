import 'package:flutter/foundation.dart' show Uint8List, immutable, listEquals;

import 'octopus_post_cta.dart';

/// A payload that prefills the Octopus post editor when the host opens the
/// SDK on the create-post screen (Bridge Share).
///
/// The host supplies any combination of [text], [image], [topicId] and [cta];
/// the user can freely edit the text, image, and target group in the editor
/// before publishing. The [cta] travels invisibly through the editor and is
/// attached to the published post — the user cannot view, edit, or remove it.
///
/// Mirrors the native `OctopusPrefilledPost`.
///
/// ## Validation
///
/// [text] and [image] are both optional: a payload carrying only a [topicId]
/// and/or a [cta] opens the editor on the preselected group with empty,
/// user-editable fields.
///
/// The constructor validates whatever *is* provided and throws an
/// [OctopusPrefilledPostValidationError] on failure. Empty [text], empty
/// [image] bytes, and blank [topicId] are normalised to `null` first. When
/// [text] is present its length must be within [textMinLength]..[textMaxLength];
/// when [cta] is present its `label` and `url` string must be non-blank.
///
/// Wrap the call if you want a non-throwing result:
/// ```dart
/// OctopusPrefilledPost? prefill;
/// try {
///   prefill = OctopusPrefilledPost(text: text, cta: cta);
/// } on OctopusPrefilledPostValidationError catch (e) {
///   // surface e to the user
/// }
/// ```
///
/// ## Image bytes are not decoded here
///
/// [image] is **not** decoded or dimension-checked at construction (decoding
/// is asynchronous and needs a platform image codec). Image errors — undecodable
/// bytes, too small, aspect-ratio too large — surface inside the editor through
/// the same media-validation pipeline as a user-picked image. This matches the
/// native Android contract; iOS hosts get those image errors eagerly at
/// construction time, so document the difference if you migrate a cross-platform
/// host that relies on early image failure.
@immutable
class OctopusPrefilledPost {
  /// Minimum length of [text] (inclusive). Mirrors the native post editor's
  /// publish-time minimum.
  static const int textMinLength = 10;

  /// Maximum length of [text] (inclusive). Mirrors the native post editor's
  /// publish-time maximum.
  static const int textMaxLength = 5000;

  /// Text the editor opens with. `null` when the host provided text-less
  /// prefill (an empty string passed to the constructor is normalised to
  /// `null`).
  final String? text;

  /// Local image bytes the editor opens with (e.g. JPEG/PNG bytes). `null`
  /// when the host provided image-less prefill (empty bytes are normalised to
  /// `null`). The host is responsible for image acquisition — the SDK does not
  /// fetch remote URLs; download or load the bytes before constructing this
  /// payload.
  final Uint8List? image;

  /// Identifier of the group the post should land in. If `null` or
  /// inaccessible to the current user, the editor forces the user to pick a
  /// group manually before publishing. A blank string is normalised to `null`.
  final String? topicId;

  /// Optional call-to-action attached to the published post. Not displayed in
  /// the editor (invisible passthrough).
  final OctopusPostCTA? cta;

  /// Creates a prefilled-post payload, validating it eagerly.
  ///
  /// Throws an [OctopusPrefilledPostValidationError] when [text] is out of
  /// bounds or [cta] is malformed — see the class docs. An empty payload does
  /// **not** throw: [text] and [image] are both optional.
  factory OctopusPrefilledPost({
    String? text,
    Uint8List? image,
    String? topicId,
    OctopusPostCTA? cta,
  }) {
    final normalizedText = (text == null || text.isEmpty) ? null : text;
    final normalizedImage = (image == null || image.isEmpty) ? null : image;
    final normalizedTopicId =
        (topicId == null || topicId.trim().isEmpty) ? null : topicId;

    // No content-empty check: text and image are both optional (native 1.13).
    // A topicId-/CTA-only payload opens the editor on the preselected group with
    // empty, user-editable fields; the editor re-validates at publish time.
    if (normalizedText != null) {
      if (normalizedText.length < textMinLength) {
        throw OctopusPrefilledPostTextTooShortError(textMinLength);
      }
      if (normalizedText.length > textMaxLength) {
        throw OctopusPrefilledPostTextTooLongError(textMaxLength);
      }
    }
    if (cta != null) {
      if (cta.label.trim().isEmpty) {
        throw OctopusPrefilledPostCtaLabelEmptyError();
      }
      if (cta.url.toString().trim().isEmpty) {
        throw OctopusPrefilledPostCtaUrlEmptyError();
      }
    }

    return OctopusPrefilledPost._(
      text: normalizedText,
      image: normalizedImage,
      topicId: normalizedTopicId,
      cta: cta,
    );
  }

  const OctopusPrefilledPost._({
    required this.text,
    required this.image,
    required this.topicId,
    required this.cta,
  });

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'text': text,
        'image': image,
        'topicId': topicId,
        'cta': cta?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPrefilledPost &&
          other.text == text &&
          listEquals(other.image, image) &&
          other.topicId == topicId &&
          other.cta == cta;

  @override
  int get hashCode => Object.hash(
        text,
        // Uint8List has no value-based hashCode; fold its length + a content
        // sample so equal payloads hash equally without scanning huge buffers.
        image == null ? null : Object.hash(image!.length, _imageHashSample()),
        topicId,
        cta,
      );

  int _imageHashSample() {
    final bytes = image!;
    if (bytes.isEmpty) return 0;
    // Sample first/middle/last bytes — cheap and stable for equal buffers.
    return Object.hash(bytes.first, bytes[bytes.length ~/ 2], bytes.last);
  }

  @override
  String toString() => 'OctopusPrefilledPost(text: $text, '
      'image: ${image == null ? 'null' : '${image!.length} bytes'}, '
      'topicId: $topicId, cta: $cta)';
}

/// A validation failure thrown by the [OctopusPrefilledPost] constructor.
///
/// Mirrors the native `OctopusPrefilledPost.ValidationError` sealed hierarchy.
/// Subclasses [ArgumentError], so a caller that does not need to discriminate
/// can `catch (e) on ArgumentError`; switch over the sealed subclasses to react
/// to the specific reason.
///
/// Only the structurally-checkable reasons are surfaced here. Image-decoding
/// failures (undecodable bytes, too small, ratio too large) are **not** thrown
/// at construction on Flutter — they surface in the editor, matching the native
/// Android behaviour.
sealed class OctopusPrefilledPostValidationError extends ArgumentError {
  OctopusPrefilledPostValidationError(super.message);
}

/// Retained for backward compatibility, and **never thrown**: `text` and
/// `image` are both optional, so an empty payload no longer fails. Kept only so
/// existing `switch` statements over
/// [OctopusPrefilledPostValidationError] stay exhaustive — mirrors the native
/// SDKs, which kept their `ContentEmpty` case for the same reason.
final class OctopusPrefilledPostContentEmptyError
    extends OctopusPrefilledPostValidationError {
  OctopusPrefilledPostContentEmptyError()
      : super('at least one of `text` or `image` must be provided.');

  @override
  String toString() => 'OctopusPrefilledPostContentEmptyError: $message';
}

/// The text length is below [OctopusPrefilledPost.textMinLength].
final class OctopusPrefilledPostTextTooShortError
    extends OctopusPrefilledPostValidationError {
  /// The minimum allowed length.
  final int min;

  OctopusPrefilledPostTextTooShortError(this.min)
      : super('prefilled text is shorter than $min characters.');

  @override
  String toString() => 'OctopusPrefilledPostTextTooShortError: $message';
}

/// The text length exceeds [OctopusPrefilledPost.textMaxLength].
final class OctopusPrefilledPostTextTooLongError
    extends OctopusPrefilledPostValidationError {
  /// The maximum allowed length.
  final int max;

  OctopusPrefilledPostTextTooLongError(this.max)
      : super('prefilled text exceeds $max characters.');

  @override
  String toString() => 'OctopusPrefilledPostTextTooLongError: $message';
}

/// The attached [OctopusPostCTA] has an empty or whitespace-only `label`.
final class OctopusPrefilledPostCtaLabelEmptyError
    extends OctopusPrefilledPostValidationError {
  OctopusPrefilledPostCtaLabelEmptyError()
      : super('CTA `label` must not be empty or blank.');

  @override
  String toString() => 'OctopusPrefilledPostCtaLabelEmptyError: $message';
}

/// The attached [OctopusPostCTA] has an empty or whitespace-only `url` string.
final class OctopusPrefilledPostCtaUrlEmptyError
    extends OctopusPrefilledPostValidationError {
  OctopusPrefilledPostCtaUrlEmptyError()
      : super('CTA `url` must have a non-empty string representation.');

  @override
  String toString() => 'OctopusPrefilledPostCtaUrlEmptyError: $message';
}
