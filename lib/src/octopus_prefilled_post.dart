import 'package:flutter/foundation.dart' show Uint8List, immutable, listEquals;

import 'octopus_localized_text.dart';
import 'octopus_post_cta.dart';

/// A payload that prefills the Octopus post editor when the host opens the
/// SDK on the create-post screen (Bridge Share).
///
/// The host supplies any combination of [text], [images], [topicId] and
/// [cta]; the user can freely edit the text, images, and target group in the
/// editor before publishing. The [cta] travels invisibly through the editor
/// and is attached to the published post — the user cannot view, edit, or
/// remove it.
///
/// Mirrors the native `OctopusPrefilledPost`.
///
/// ## Validation
///
/// [text] and [images] are both optional: a payload carrying only a [topicId]
/// and/or a [cta] opens the editor on the preselected group with empty,
/// user-editable fields.
///
/// The constructor validates whatever *is* provided and throws an
/// [OctopusPrefilledPostValidationError] on failure. Empty [text] and blank
/// [topicId] are normalised to `null` first, and empty entries of [images] are
/// dropped. When [text] is present its length must be within
/// [textMinLength]..[textMaxLength]; when [cta] is present its `url` string
/// must be non-blank, and so must its `label` unless it is given per language
/// (the native SDK checks a per-language label when the editor opens). More
/// than [maxImageCount] images throw an
/// [OctopusPrefilledPostTooManyImagesError] instead, a separate type (see its
/// docs).
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
/// [images] are **not** decoded or dimension-checked at construction (decoding
/// is asynchronous and needs a platform image codec). Image errors — undecodable
/// bytes, too small, aspect-ratio too large — surface inside the editor through
/// the same media-validation pipeline as a user-picked image. This matches the
/// native Android contract; iOS hosts get those image errors eagerly at
/// construction time, so document the difference if you migrate a cross-platform
/// host that relies on early image failure. On iOS the plugin then keeps the
/// images that pass on their own and opens the editor without the others.
@immutable
class OctopusPrefilledPost {
  /// Minimum length of [text] (inclusive). Mirrors the native post editor's
  /// publish-time minimum: one character, so a short text such as "Bravo !"
  /// is accepted. A blank text opens the editor, which keeps publishing
  /// disabled until the member types something visible.
  static const int textMinLength = 1;

  /// Maximum length of [text] (inclusive). Mirrors the native post editor's
  /// publish-time maximum.
  static const int textMaxLength = 5000;

  /// Maximum number of [images] a prefilled post carries. Mirrors the native
  /// post editor, which accepts up to this many photos per post.
  static const int maxImageCount = 10;

  /// Text the editor opens with. `null` when the host provided text-less
  /// prefill (an empty string passed to the constructor is normalised to
  /// `null`).
  final String? text;

  /// Local image bytes (e.g. JPEG/PNG bytes) the editor opens with, in display
  /// order, at most [maxImageCount]. Empty when the host provided image-less
  /// prefill; empty entries passed to the constructor are dropped, so this list
  /// never holds empty bytes. Unmodifiable.
  ///
  /// The host is responsible for image acquisition — the SDK does not fetch
  /// remote URLs; download or load the bytes before constructing this payload.
  final List<Uint8List> images;

  /// The first of [images], or `null` when there is none.
  @Deprecated('Use images.')
  Uint8List? get image => images.firstOrNull;

  /// Identifier of the group the post should land in. If `null` or
  /// inaccessible to the current user, the editor forces the user to pick a
  /// group manually before publishing. A blank string is normalised to `null`.
  final String? topicId;

  /// Optional call-to-action attached to the published post. Not displayed in
  /// the editor (invisible passthrough).
  final OctopusPostCTA? cta;

  /// Creates a prefilled-post payload, validating it eagerly.
  ///
  /// [images] are the photos the editor opens with, in display order. [image]
  /// is the deprecated single photo: alone it behaves as `images: [image]`.
  ///
  /// Throws an [ArgumentError] when a non-empty [image] is passed together with
  /// a non-empty [images] list, an [OctopusPrefilledPostTooManyImagesError] when
  /// more than [maxImageCount] non-empty images are passed, and an
  /// [OctopusPrefilledPostValidationError] when [text] is out of bounds or
  /// [cta] is malformed — see the class docs. An empty payload does **not**
  /// throw: [text] and [images] are both optional.
  factory OctopusPrefilledPost({
    String? text,
    @Deprecated('Use images.') Uint8List? image,
    String? topicId,
    OctopusPostCTA? cta,
    List<Uint8List> images = const [],
  }) {
    final hasLegacyImage = image != null && image.isNotEmpty;
    if (hasLegacyImage && images.isNotEmpty) {
      throw ArgumentError('Set images only: image is deprecated.');
    }
    final normalizedText = (text == null || text.isEmpty) ? null : text;
    final normalizedImages = List<Uint8List>.unmodifiable(
      (hasLegacyImage ? [image] : images).where((bytes) => bytes.isNotEmpty),
    );
    final normalizedTopicId = (topicId == null || topicId.trim().isEmpty)
        ? null
        : topicId;

    // No content-empty check: text and images are both optional (native 1.13).
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
    if (normalizedImages.length > maxImageCount) {
      throw OctopusPrefilledPostTooManyImagesError(
        max: maxImageCount,
        count: normalizedImages.length,
      );
    }
    if (cta != null) {
      // A per-language label is the native SDK's to check, when the editor
      // opens: its default text is only known once the native SDK reads the
      // tags.
      if (cta.localizedLabel is! OctopusPerLanguageText &&
          cta.label.trim().isEmpty) {
        throw OctopusPrefilledPostCtaLabelEmptyError();
      }
      if (cta.url.toString().trim().isEmpty) {
        throw OctopusPrefilledPostCtaUrlEmptyError();
      }
    }

    return OctopusPrefilledPost._(
      text: normalizedText,
      images: normalizedImages,
      topicId: normalizedTopicId,
      cta: cta,
    );
  }

  const OctopusPrefilledPost._({
    required this.text,
    required this.images,
    required this.topicId,
    required this.cta,
  });

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'text': text,
    'images': images,
    'topicId': topicId,
    'cta': cta?.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPrefilledPost &&
          other.text == text &&
          _imagesEqual(other.images, images) &&
          other.topicId == topicId &&
          other.cta == cta;

  static bool _imagesEqual(List<Uint8List> a, List<Uint8List> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    text,
    // Uint8List has no value-based hashCode; fold each image's length + a
    // content sample so equal payloads hash equally without scanning huge
    // buffers.
    Object.hashAll(images.map(_imageHashSample)),
    topicId,
    cta,
  );

  static int _imageHashSample(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    // Sample first/middle/last bytes — cheap and stable for equal buffers.
    return Object.hash(
      bytes.length,
      bytes.first,
      bytes[bytes.length ~/ 2],
      bytes.last,
    );
  }

  @override
  String toString() =>
      'OctopusPrefilledPost(text: $text, '
      'images: ${images.map((bytes) => '${bytes.length} bytes').toList()}, '
      'topicId: $topicId, cta: $cta)';
}

/// Thrown by the [OctopusPrefilledPost] constructor when more than [max]
/// images are provided (empty entries are not counted).
///
/// It subclasses [ArgumentError] like [OctopusPrefilledPostValidationError], so
/// a generic `on ArgumentError` still covers it, but it is **not** an
/// [OctopusPrefilledPostValidationError]: adding a subclass to that sealed
/// hierarchy would break the exhaustive `switch` statements hosts wrote over
/// it. Mirrors the native `OctopusPrefilledPost.TooManyImagesError`, kept apart
/// from the native `ValidationError` for the same reason.
final class OctopusPrefilledPostTooManyImagesError extends ArgumentError {
  /// The maximum number of images a post carries
  /// ([OctopusPrefilledPost.maxImageCount]).
  final int max;

  /// The number of (non-empty) images that were provided.
  final int count;

  /// Creates the error for [count] images provided where at most [max] are
  /// accepted.
  OctopusPrefilledPostTooManyImagesError({
    required this.max,
    required this.count,
  }) : super('$count images provided, at most $max are accepted.');

  @override
  String toString() => 'OctopusPrefilledPostTooManyImagesError: $message';
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
/// Android behaviour. Too many images is reported by
/// [OctopusPrefilledPostTooManyImagesError] instead, which is not part of this
/// hierarchy.
sealed class OctopusPrefilledPostValidationError extends ArgumentError {
  OctopusPrefilledPostValidationError(super.message);
}

/// Retained for backward compatibility, and **never thrown**: `text` and
/// `images` are both optional, so an empty payload no longer fails. Kept only so
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
///
/// That minimum is one character and an empty text is normalised to `null`, so
/// this is no longer thrown; it is kept so exhaustive switches over
/// [OctopusPrefilledPostValidationError] keep compiling.
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
