import 'package:flutter/foundation.dart' show Uint8List, immutable, listEquals;

import 'octopus_localized_text.dart';

/// An image attachment for a [ClientPost].
///
/// Mirrors the intersection of the native attachment types — Android
/// `Resource` (`Local`/`Remote`) and iOS `ClientPost.Attachment`
/// (`localImage`/`distantImage`). Use [OctopusLocalImageAttachment] for bytes
/// you already hold, or [OctopusRemoteImageAttachment] for an image the backend
/// can fetch from a URL.
@immutable
sealed class OctopusClientPostAttachment {
  const OctopusClientPostAttachment();

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap();
}

/// A local image attachment carrying the raw image [bytes] (e.g. JPEG/PNG).
@immutable
final class OctopusLocalImageAttachment extends OctopusClientPostAttachment {
  /// The raw image bytes.
  final Uint8List bytes;

  /// Creates a local-image attachment from [bytes].
  const OctopusLocalImageAttachment(this.bytes);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'localImage',
    'bytes': bytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusLocalImageAttachment && listEquals(other.bytes, bytes);

  @override
  int get hashCode {
    if (bytes.isEmpty) return 0;
    // Sample first/middle/last bytes — cheap, stable for equal buffers.
    return Object.hash(
      bytes.length,
      bytes.first,
      bytes[bytes.length ~/ 2],
      bytes.last,
    );
  }

  @override
  String toString() => 'OctopusLocalImageAttachment(${bytes.length} bytes)';
}

/// A remote image attachment pointing at a [url] the backend fetches directly.
/// The URL must point to the image file itself.
@immutable
final class OctopusRemoteImageAttachment extends OctopusClientPostAttachment {
  /// URL of the image file.
  final Uri url;

  /// Creates a remote-image attachment from [url].
  const OctopusRemoteImageAttachment(this.url);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'remoteImage',
    'url': url.toString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusRemoteImageAttachment && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'OctopusRemoteImageAttachment(url: $url)';
}

/// A client object (article, product, recipe, event, …) to link to an Octopus
/// post.
///
/// `ClientPost` describes the post the SDK should fetch — or create, if it does
/// not exist yet — for an external object from your app. It is the input to
/// `OctopusSDK.fetchOrCreateClientObjectRelatedPost`.
///
/// Mirrors the native `ClientPost` public surface. Field names follow Android
/// (the reference SDK). Like Android, this model carries **no** signature/token
/// field: authorization for creating a new post is supplied lazily through the
/// token-provider callback on the fetch-or-create method, not on the model
/// itself.
@immutable
class ClientPost {
  /// Stable identifier of the external object this post is linked to. Used to
  /// retrieve the post if it already exists and to drive the host's
  /// "open client object" navigation callback.
  final String objectId;

  /// Main post text. Must be 1–5000 characters (validated by the native editor
  /// at creation time).
  final String text;

  /// The deprecated single image attachment — local bytes or a remote URL.
  ///
  /// Use [medias] instead. Setting both a non-null [attachment] and a non-empty
  /// [medias] is refused by `OctopusSDK.fetchOrCreateClientObjectRelatedPost`
  /// before any native call.
  @Deprecated('Use medias.')
  final OctopusClientPostAttachment? attachment;

  /// The images of the post, in display order — each one local bytes or a
  /// remote URL. Empty by default.
  ///
  /// A post accepts at most 10 images (`OctopusPrefilledPost.maxImageCount`):
  /// `OctopusSDK.fetchOrCreateClientObjectRelatedPost` refuses more, before any
  /// network call, with an `OctopusInvalidArguments` failure carrying a
  /// `ClientPostOtherError` on both platforms (the native SDKs report it as a
  /// file error that has no dedicated case). Do not set it together with the
  /// deprecated [attachment].
  final List<OctopusClientPostAttachment> medias;

  /// Optional catch phrase displayed in bold below the text (e.g. "What do you
  /// think about this?"). Keep it short. When `null`, none is shown.
  final String? catchPhrase;

  final String? _viewObjectButtonText;

  final OctopusLocalizedText? _viewObjectButton;

  /// Optional label for the button that opens the linked client object,
  /// auto-translated or given per language. When tapped, the host's "open
  /// client object" navigation callback fires with [objectId]. When `null`, the
  /// button is not shown.
  ///
  /// Use [OctopusLocalizedText.perLanguage] to give the label in each language
  /// of your app, [OctopusLocalizedText.autoTranslated] to let Octopus translate
  /// it. Keep each text under 28 characters so that it fits on one line: a
  /// longer one is accepted, and the button can then take several lines.
  ///
  /// It is taken when the bridge post is created: a post that already exists
  /// for [objectId] keeps its button as it was.
  ///
  /// When the post was built with the deprecated `viewObjectButtonText`, this
  /// is that text, auto-translated.
  OctopusLocalizedText? get viewObjectButton =>
      _viewObjectButton ??
      switch (viewObjectButtonText) {
        final text? => OctopusLocalizedText.autoTranslated(text),
        null => null,
      };

  /// The label of the button that opens the linked client object: the text
  /// itself when auto-translated, the text of the default language when given
  /// per language.
  @Deprecated('Use viewObjectButton.')
  String? get viewObjectButtonText =>
      _viewObjectButtonText ?? _viewObjectButton?.defaultText;

  /// Optional group the post is categorised under. When `null`, a default group
  /// (configured with the Octopus backend team) is used.
  final String? groupId;

  /// Creates a client-object post payload.
  ///
  /// Pass the images in [medias]; [attachment] is the deprecated single image,
  /// and must not be combined with a non-empty [medias].
  ///
  /// Pass the button label in [viewObjectButton]; `viewObjectButtonText` is the
  /// deprecated auto-translated label. Do not set both: a debug build asserts,
  /// and [viewObjectButton] wins otherwise.
  const ClientPost({
    required this.objectId,
    required this.text,
    @Deprecated('Use medias.') this.attachment,
    this.catchPhrase,
    @Deprecated(
      'Use viewObjectButton: OctopusLocalizedText.autoTranslated(text) to keep '
      'the automatic translation, or OctopusLocalizedText.perLanguage to give '
      'the label per language.',
    )
    String? viewObjectButtonText,
    this.groupId,
    this.medias = const [],
    OctopusLocalizedText? viewObjectButton,
  }) : assert(
         viewObjectButtonText == null || viewObjectButton == null,
         'Set viewObjectButton only: viewObjectButtonText is deprecated.',
       ),
       _viewObjectButtonText = viewObjectButtonText,
       _viewObjectButton = viewObjectButton;

  /// The platform-channel representation handed to the native bridges.
  ///
  /// Carries both `attachment` and `medias`: the bridges hand them to the
  /// native SDKs as they are.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'objectId': objectId,
    'text': text,
    'attachment': attachment?.toMap(),
    'medias': [for (final media in medias) media.toMap()],
    'catchPhrase': catchPhrase,
    'viewObjectButton': viewObjectButton?.toMap(),
    'groupId': groupId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientPost &&
          other.objectId == objectId &&
          other.text == text &&
          other.attachment == attachment &&
          listEquals(other.medias, medias) &&
          other.catchPhrase == catchPhrase &&
          other.viewObjectButton == viewObjectButton &&
          other.groupId == groupId;

  @override
  int get hashCode => Object.hash(
    objectId,
    text,
    attachment,
    Object.hashAll(medias),
    catchPhrase,
    viewObjectButton,
    groupId,
  );

  @override
  String toString() =>
      'ClientPost(objectId: $objectId, text: $text, '
      'attachment: $attachment, medias: $medias, catchPhrase: $catchPhrase, '
      'viewObjectButton: $viewObjectButton, groupId: $groupId)';
}
