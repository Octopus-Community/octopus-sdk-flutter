import 'package:flutter/foundation.dart' show Uint8List, immutable, listEquals;

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
/// not exist yet — for an external object from your app. It is the input to the
/// upcoming Bridge `fetchOrCreateClientObjectRelatedPost` API; this release
/// adds the model so hosts can start preparing payloads.
///
/// Mirrors the native `ClientPost` public surface. Field names follow Android
/// (the reference SDK). Like Android, this model carries **no** signature/token
/// field: authorization for creating a new post is supplied lazily through the
/// token-provider callback on the fetch-or-create method (added in a later
/// release), not on the model itself.
@immutable
class ClientPost {
  /// Stable identifier of the external object this post is linked to. Used to
  /// retrieve the post if it already exists and to drive the host's
  /// "open client object" navigation callback.
  final String objectId;

  /// Main post text. Must be 10–5000 characters (validated by the native editor
  /// at creation time).
  final String text;

  /// Optional image attachment — local bytes or a remote URL.
  final OctopusClientPostAttachment? attachment;

  /// Optional catch phrase displayed in bold below the text (e.g. "What do you
  /// think about this?"). Keep it short. When `null`, none is shown.
  final String? catchPhrase;

  /// Optional label for the button that opens the linked client object. When
  /// tapped, the host's "open client object" navigation callback fires with
  /// [objectId]. When `null`, the button is not shown.
  final String? viewObjectButtonText;

  /// Optional group the post is categorised under. When `null`, a default group
  /// (configured with the Octopus backend team) is used.
  final String? groupId;

  /// Creates a client-object post payload.
  const ClientPost({
    required this.objectId,
    required this.text,
    this.attachment,
    this.catchPhrase,
    this.viewObjectButtonText,
    this.groupId,
  });

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'objectId': objectId,
        'text': text,
        'attachment': attachment?.toMap(),
        'catchPhrase': catchPhrase,
        'viewObjectButtonText': viewObjectButtonText,
        'groupId': groupId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientPost &&
          other.objectId == objectId &&
          other.text == text &&
          other.attachment == attachment &&
          other.catchPhrase == catchPhrase &&
          other.viewObjectButtonText == viewObjectButtonText &&
          other.groupId == groupId;

  @override
  int get hashCode => Object.hash(
        objectId,
        text,
        attachment,
        catchPhrase,
        viewObjectButtonText,
        groupId,
      );

  @override
  String toString() => 'ClientPost(objectId: $objectId, text: $text, '
      'attachment: $attachment, catchPhrase: $catchPhrase, '
      'viewObjectButtonText: $viewObjectButtonText, groupId: $groupId)';
}
