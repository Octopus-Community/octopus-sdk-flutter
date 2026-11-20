import 'package:flutter/foundation.dart' show immutable, mapEquals;

/// A text the host app gives either for automatic translation or per language.
///
/// It is the label of a call-to-action button: the button of a bridge post
/// (`ClientPost.viewObjectButton`) and the button of a Bridge Share post
/// (`OctopusPostCTA.localized`).
///
/// - [OctopusLocalizedText.autoTranslated]: one text, which Octopus translates
///   automatically for every reader. This is what a plain `String` label means.
/// - [OctopusLocalizedText.perLanguage]: one text per language your app has,
///   plus the default language. A reader whose language is in the list sees
///   that text as is; any other reader sees an automatic translation of the
///   default language's text.
///
/// Keep each text under 28 characters so that it fits on one line: a longer
/// text is accepted, and the button can then take several lines.
///
/// Mirrors the native `OctopusLocalizedText` (Android and iOS). Languages are
/// BCP-47 language tags written as strings (`"en"`, `"pt-BR"`, `"zh-Hant-TW"`).
@immutable
sealed class OctopusLocalizedText {
  const OctopusLocalizedText._();

  /// One [text], translated automatically by Octopus for every reader.
  const factory OctopusLocalizedText.autoTranslated(String text) =
      OctopusAutoTranslatedText;

  /// One text per language, with the language to start from for the readers
  /// whose language is not listed.
  ///
  /// [texts] maps a BCP-47 language tag to the text of that language: a
  /// language, then the script when needed, then the region when needed, joined
  /// with hyphens (`"fr"`, `"pt-BR"`, `"zh-Hant-TW"`). [defaultLanguage] is the
  /// language of the text shown, and translated, when none matches the reader;
  /// it must be one of the languages of [texts].
  ///
  /// Nothing is checked here: the tags and texts are kept as given and the
  /// native SDK validates them when the text is used — when
  /// `OctopusSDK.fetchOrCreateClientObjectRelatedPost` sends the post, or when
  /// `OctopusSDK.showOctopusCreatePostScreen` opens the editor. It refuses, with
  /// an [OctopusLocalizedTextValidationError]: no text, a tag without a
  /// language, a blank text, two tags of the same language, or a default
  /// language that is none of the languages given. The bridges only read an
  /// underscore as a hyphen (`"pt_BR"` is `"pt-BR"`); the native SDK reads the
  /// rest of the tag. Octopus groups the regions of one language, except for
  /// Chinese: give `"zh-Hans"` and `"zh-Hant"` (or a region) apart.
  factory OctopusLocalizedText.perLanguage(
    Map<String, String> texts, {
    required String defaultLanguage,
  }) = OctopusPerLanguageText;

  /// The text to start from: the text itself when auto-translated, the text of
  /// the default language when given per language.
  String get defaultText;

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap();
}

/// An [OctopusLocalizedText] translated automatically by Octopus for every
/// reader. Build it with [OctopusLocalizedText.autoTranslated].
final class OctopusAutoTranslatedText extends OctopusLocalizedText {
  /// The text, in any language.
  final String text;

  /// Creates an auto-translated text. No validation: an empty text is refused
  /// where the text is used, as a plain `String` label is.
  const OctopusAutoTranslatedText(this.text) : super._();

  @override
  String get defaultText => text;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'autoTranslated',
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusAutoTranslatedText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'OctopusLocalizedText.autoTranslated($text)';
}

/// An [OctopusLocalizedText] given per language. Build it with
/// [OctopusLocalizedText.perLanguage].
final class OctopusPerLanguageText extends OctopusLocalizedText {
  /// The text of each language, keyed by language tag as given. Unmodifiable.
  final Map<String, String> texts;

  /// The language of [defaultText], as given.
  final String defaultLanguage;

  /// Creates a per-language text from unmodifiable copies of [texts] and
  /// [defaultLanguage], unchecked: see [OctopusLocalizedText.perLanguage].
  factory OctopusPerLanguageText(
    Map<String, String> texts, {
    required String defaultLanguage,
  }) => OctopusPerLanguageText._(
    Map<String, String>.unmodifiable(texts),
    defaultLanguage,
  );

  const OctopusPerLanguageText._(this.texts, this.defaultLanguage) : super._();

  /// The text of [defaultLanguage], or an empty string when it is not exactly
  /// one of the tags of [texts] (the native SDK may still match it, or refuse
  /// the text).
  @override
  String get defaultText => texts[defaultLanguage] ?? '';

  /// The tags are sent as given, in the order given.
  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'perLanguage',
    'texts': [
      for (final entry in texts.entries)
        <String, dynamic>{'language': entry.key, 'text': entry.value},
    ],
    'defaultLanguage': defaultLanguage,
  };

  /// Two per-language texts are equal when they hold the same texts for the
  /// same tags, as given, and the same default language.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPerLanguageText &&
          other.defaultLanguage == defaultLanguage &&
          mapEquals(other.texts, texts);

  @override
  int get hashCode => Object.hash(
    defaultLanguage,
    Object.hashAllUnordered(
      texts.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'OctopusLocalizedText.perLanguage($texts, '
      'defaultLanguage: $defaultLanguage)';
}

/// Why the native SDK refused an [OctopusLocalizedText.perLanguage] text.
///
/// Mirrors the native `OctopusLocalizedText.ValidationError` kinds.
enum OctopusLocalizedTextValidationErrorKind {
  /// No text was given.
  emptyTexts,

  /// The text of a language is empty or whitespace-only.
  blankText,

  /// A language tag, or the default language, has no language (such as the
  /// undetermined `und`).
  emptyLanguage,

  /// Two tags name the same language.
  duplicateLanguage,

  /// The default language is not exactly one of the languages given (`en-US`
  /// when only `en` is).
  defaultLanguageMissing,
}

/// Thrown when the native SDK refuses an [OctopusLocalizedText.perLanguage]
/// text, at call time: by `OctopusSDK.fetchOrCreateClientObjectRelatedPost`
/// and `OctopusSDK.showOctopusCreatePostScreen`. Building the text never throws
/// it.
///
/// Subclasses [ArgumentError], so a caller that does not need the reason can
/// catch that. It is not an `OctopusPrefilledPostValidationError`: a new
/// subclass of that sealed hierarchy would break the exhaustive `switch`
/// statements hosts wrote over it, which is why the native SDKs keep it apart
/// too.
final class OctopusLocalizedTextValidationError extends ArgumentError {
  /// Why the text was refused.
  final OctopusLocalizedTextValidationErrorKind kind;

  /// The code the native SDK built for the language concerned
  /// (`language[-Script][-REGION]`, such as `pt-BR`), for
  /// [OctopusLocalizedTextValidationErrorKind.blankText],
  /// [OctopusLocalizedTextValidationErrorKind.duplicateLanguage] and
  /// [OctopusLocalizedTextValidationErrorKind.defaultLanguageMissing]; `null`
  /// otherwise.
  final String? languageCode;

  /// Creates the error for [kind], about [languageCode] when it names one.
  OctopusLocalizedTextValidationError(this.kind, {this.languageCode})
    : super(_describe(kind, languageCode));

  static String _describe(
    OctopusLocalizedTextValidationErrorKind kind,
    String? code,
  ) => switch (kind) {
    OctopusLocalizedTextValidationErrorKind.emptyTexts =>
      'at least one text must be provided.',
    OctopusLocalizedTextValidationErrorKind.blankText =>
      'the text of `$code` must not be empty or blank.',
    OctopusLocalizedTextValidationErrorKind.emptyLanguage =>
      'every language tag must have a language.',
    OctopusLocalizedTextValidationErrorKind.duplicateLanguage =>
      'two texts are given for `$code`.',
    OctopusLocalizedTextValidationErrorKind.defaultLanguageMissing =>
      'no text is given for the default language `$code`.',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusLocalizedTextValidationError &&
          other.kind == kind &&
          other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(kind, languageCode);

  @override
  String toString() =>
      'OctopusLocalizedTextValidationError(${kind.name}): $message';
}
