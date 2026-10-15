import 'package:flutter/foundation.dart' show immutable;

/// The three native consent wording variants, independent of acceptance mode.
enum OctopusConsentTextsMode {
  /// Notice below the editors.
  implicit,

  /// One label per legal document.
  multiCheckbox,

  /// One checkbox label and a text below it.
  singleCheckbox,
}

/// Community consent wordings forwarded unchanged to native SDK 1.15.
///
/// Debug-only model. Native code handles empty-field fallback, markdown, links,
/// layout and variants that do not match the active terms-acceptance mode.
@immutable
class OctopusConsentTexts {
  /// Which wording variant this value contains.
  final OctopusConsentTextsMode mode;

  /// Implicit notice below the editors, or `null` for the native wording.
  final String? notice;

  /// Terms checkbox label, or `null` for the native wording.
  final String? termsLabel;

  /// Privacy checkbox label, or `null` for the native wording.
  final String? privacyLabel;

  /// Community rules checkbox label, or `null` for the native wording.
  final String? rulesLabel;

  /// Single checkbox label, or `null` for the native wording.
  final String? label;

  /// Text below the single checkbox, or `null` for the native wording.
  final String? belowText;

  /// Wordings for implicit consent. Null fields keep the native wording.
  const OctopusConsentTexts.implicit({this.notice})
    : mode = OctopusConsentTextsMode.implicit,
      termsLabel = null,
      privacyLabel = null,
      rulesLabel = null,
      label = null,
      belowText = null;

  /// Wordings for one checkbox per legal document.
  const OctopusConsentTexts.multiCheckbox({
    this.termsLabel,
    this.privacyLabel,
    this.rulesLabel,
  }) : mode = OctopusConsentTextsMode.multiCheckbox,
       notice = null,
       label = null,
       belowText = null;

  /// Wordings for a single checkbox and its passive text below.
  const OctopusConsentTexts.singleCheckbox({this.label, this.belowText})
    : mode = OctopusConsentTextsMode.singleCheckbox,
      notice = null,
      termsLabel = null,
      privacyLabel = null,
      rulesLabel = null;

  /// Platform-channel map. Empty, whitespace and multiline strings are preserved.
  Map<String, dynamic> toMap() => switch (mode) {
    OctopusConsentTextsMode.implicit => {'mode': 'implicit', 'notice': notice},
    OctopusConsentTextsMode.multiCheckbox => {
      'mode': 'multiCheckbox',
      'termsLabel': termsLabel,
      'privacyLabel': privacyLabel,
      'rulesLabel': rulesLabel,
    },
    OctopusConsentTextsMode.singleCheckbox => {
      'mode': 'singleCheckbox',
      'label': label,
      'belowText': belowText,
    },
  };

  /// Decodes a snapshot. Unknown variants or absent maps read as `null`;
  /// absent and wrong-typed fields read as `null` without changing valid strings.
  static OctopusConsentTexts? fromWire(Object? value) {
    if (value is! Map) return null;
    String? text(String key) =>
        value[key] is String ? value[key] as String : null;
    return switch (value['mode']) {
      'implicit' => OctopusConsentTexts.implicit(notice: text('notice')),
      'multiCheckbox' => OctopusConsentTexts.multiCheckbox(
        termsLabel: text('termsLabel'),
        privacyLabel: text('privacyLabel'),
        rulesLabel: text('rulesLabel'),
      ),
      'singleCheckbox' => OctopusConsentTexts.singleCheckbox(
        label: text('label'),
        belowText: text('belowText'),
      ),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusConsentTexts &&
      other.mode == mode &&
      other.notice == notice &&
      other.termsLabel == termsLabel &&
      other.privacyLabel == privacyLabel &&
      other.rulesLabel == rulesLabel &&
      other.label == label &&
      other.belowText == belowText;

  @override
  int get hashCode => Object.hash(
    mode,
    notice,
    termsLabel,
    privacyLabel,
    rulesLabel,
    label,
    belowText,
  );

  @override
  String toString() => 'OctopusConsentTexts(${toMap()})';
}
