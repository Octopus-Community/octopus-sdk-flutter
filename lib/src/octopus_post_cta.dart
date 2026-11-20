import 'package:flutter/foundation.dart' show immutable;

import 'octopus_localized_text.dart';

/// A call-to-action button attached to a post published through the Bridge
/// create-post flow (e.g. a prefilled post — see [OctopusPrefilledPost]).
///
/// The CTA is supplied by the host app at post-creation time and is
/// **invisible inside the editor** — the user cannot view, edit, or remove it
/// before publishing. When the published post's button is tapped, the host
/// app decides how to open [url] (in-app, external browser, …).
///
/// Build it with [OctopusPostCTA.localized]: an
/// [OctopusLocalizedText.perLanguage] label gives the label in each language of
/// your app, an [OctopusLocalizedText.autoTranslated] one lets Octopus translate
/// one label. The deprecated unnamed constructor taking a `String` label means
/// `OctopusLocalizedText.autoTranslated(label)`.
///
/// Mirrors the native `OctopusPostCTA` (a top-level type on Android; the
/// `OctopusPrefilledPost.CTA` nested type on iOS).
///
/// Constructing an [OctopusPostCTA] on its own performs **no** validation of
/// [label] or [url], matching the **Android** contract: they are only checked
/// when the CTA is attached to an [OctopusPrefilledPost] (which rejects a blank
/// label or a blank-string url). iOS instead validates eagerly inside its CTA
/// initializer; the end state is identical — a blank CTA on a prefilled post is
/// rejected on every platform. A per-language label is validated by the native
/// SDK when the editor opens (`OctopusSDK.showOctopusCreatePostScreen` then
/// fails with an [OctopusLocalizedTextValidationError]).
@immutable
class OctopusPostCTA {
  /// URL opened when the user taps the button. May be a custom scheme
  /// registered by the host (deeplink), an `https://` URL, or any other URL
  /// the platform knows how to route.
  final Uri url;

  /// Text shown on the button: the label itself when auto-translated, the label
  /// of the default language when given per language
  /// ([OctopusLocalizedText.defaultText] of [localizedLabel]).
  final String label;

  final OctopusLocalizedText? _localizedLabel;

  /// Creates a call-to-action with the given [url] and an auto-translated
  /// [label].
  @Deprecated(
    'Use OctopusPostCTA.localized(url: url, localizedLabel: '
    'OctopusLocalizedText.autoTranslated(label)) to keep the automatic '
    'translation, or OctopusLocalizedText.perLanguage to give the label per '
    'language.',
  )
  const OctopusPostCTA({required this.url, required this.label})
    : _localizedLabel = null;

  /// Creates a call-to-action with the given [url] and [localizedLabel]: an
  /// [OctopusLocalizedText.perLanguage] label to give it in each language of
  /// your app, an [OctopusLocalizedText.autoTranslated] one to let Octopus
  /// translate it.
  OctopusPostCTA.localized({
    required this.url,
    required OctopusLocalizedText localizedLabel,
  }) : label = localizedLabel.defaultText,
       _localizedLabel = localizedLabel;

  /// The label of the button, auto-translated or per language. [label] is its
  /// [OctopusLocalizedText.defaultText].
  OctopusLocalizedText get localizedLabel =>
      _localizedLabel ?? OctopusLocalizedText.autoTranslated(label);

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'url': url.toString(),
    'label': label,
    'localizedLabel': localizedLabel.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPostCTA &&
          other.url == url &&
          other.label == label &&
          other.localizedLabel == localizedLabel;

  @override
  int get hashCode => Object.hash(url, label, localizedLabel);

  @override
  String toString() =>
      'OctopusPostCTA(url: $url, label: $label, '
      'localizedLabel: $localizedLabel)';
}
