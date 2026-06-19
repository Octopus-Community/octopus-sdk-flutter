import 'package:flutter/foundation.dart' show immutable;

/// A call-to-action button attached to a post published through the Bridge
/// create-post flow (e.g. a prefilled post — see [OctopusPrefilledPost]).
///
/// The CTA is supplied by the host app at post-creation time and is
/// **invisible inside the editor** — the user cannot view, edit, or remove it
/// before publishing. When the published post's button is tapped, the host
/// app decides how to open [url] (in-app, external browser, …).
///
/// Mirrors the native `OctopusPostCTA` (a top-level type on Android; the
/// `OctopusPrefilledPost.CTA` nested type on iOS).
///
/// Constructing an [OctopusPostCTA] on its own performs **no** validation,
/// matching the **Android** contract: the `label` / `url` are only checked when
/// the CTA is attached to an [OctopusPrefilledPost] (which rejects a blank label
/// or a blank-string url). iOS instead validates eagerly inside its CTA
/// initializer; the end state is identical — a blank CTA on a prefilled post is
/// rejected on every platform.
@immutable
class OctopusPostCTA {
  /// URL opened when the user taps the button. May be a custom scheme
  /// registered by the host (deeplink), an `https://` URL, or any other URL
  /// the platform knows how to route.
  final Uri url;

  /// Text shown on the button.
  final String label;

  /// Creates a call-to-action with the given [url] and [label].
  const OctopusPostCTA({required this.url, required this.label});

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'url': url.toString(),
        'label': label,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPostCTA && other.url == url && other.label == label;

  @override
  int get hashCode => Object.hash(url, label);

  @override
  String toString() => 'OctopusPostCTA(url: $url, label: $label)';
}
