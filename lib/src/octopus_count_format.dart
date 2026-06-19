import 'dart:ui' show Locale;

/// Formats [count] as a compact, human-readable string in the same style as
/// the embedded community UI on both native platforms: `0`–`999` raw, then
/// `K` / `M` / `B` for thousands / millions / billions.
///
/// Use it to render the counts carried by [OctopusPost] (`commentCount`,
/// `viewCount`) and [OctopusReactionCount] (`count`) consistently with the
/// native Octopus feed.
///
/// ## Algorithm
/// - `0`–`999` → "`0`" … "`999`"
/// - `1_000`–`999_999` → "`1K`", "`1.2K`", "`9.9K`", "`12K`", … "`999K`"
/// - `1_000_000`–`999_999_999` → "`1M`", "`1.2M`", … "`999M`"
/// - `≥ 1_000_000_000` → "`1B`", "`1.2B`", …
///
/// Within a band, the value is divided by the band's divisor and **floored**
/// to one decimal (truncation, not rounding — `1999` → `1.9K`, never `2.0K`).
/// One decimal is shown only when the truncated value is `< 10`; otherwise the
/// integer form is used (`12K`, `999K`). A whole-number truncated value drops
/// the decimal (`2K`, not `2.0K`).
///
/// ## Locale
/// [locale] controls the decimal separator only: `1,2K` for languages that
/// use a comma decimal (French, German, Spanish, …) and `1.2K` for the rest
/// (English, …). The `K` / `M` / `B` suffixes themselves are not translated
/// — they match what the native SDKs render. When [locale] is `null` — or
/// its `languageCode` is not in the SDK's comma-decimal list — the separator
/// falls back to `.`.
///
/// Pass the active locale from `Localizations.localeOf(context)` or the
/// locale you handed to `OctopusSDK.overrideDefaultLocale(...)` so the
/// formatted counts match the embedded UI.
///
/// ## Negative values
/// Negative integers are returned unchanged via `count.toString()` — counts
/// are expected to be non-negative; the bug case is exposed rather than
/// silently rebanded.
String formatOctopusCompactCount(int count, {Locale? locale}) {
  if (count < 1000) return count.toString();
  if (count >= 1000000000) return _formatBand(count, 1000000000, 'B', locale);
  if (count >= 1000000) return _formatBand(count, 1000000, 'M', locale);
  return _formatBand(count, 1000, 'K', locale);
}

String _formatBand(int count, int divisor, String suffix, Locale? locale) {
  final value = count / divisor;
  if (value < 10) {
    // Truncate to one decimal (floor, not round) — matches the native SDKs.
    final truncated = (value * 10).floorToDouble() / 10;
    if (truncated == truncated.truncateToDouble()) {
      // Whole-number truncated value — drop the decimal (`2K`, not `2.0K`).
      return '${truncated.toInt()}$suffix';
    }
    return '${truncated.toStringAsFixed(1).replaceFirst('.', _decimalSeparator(locale))}$suffix';
  }
  return '${value.floor()}$suffix';
}

/// Returns `,` for languages whose locale uses a comma decimal separator,
/// otherwise `.`. Hardcoded to avoid pulling in `package:intl`. List drawn
/// from CLDR: continental European, Slavic, Baltic, Turkic, Nordic, …
String _decimalSeparator(Locale? locale) {
  final code = locale?.languageCode;
  if (code == null) return '.';
  return _commaDecimalLanguages.contains(code) ? ',' : '.';
}

const Set<String> _commaDecimalLanguages = <String>{
  // Romance (excl. Romanian dialects that vary)
  'fr', 'es', 'pt', 'it', 'ca', 'gl', 'oc', 'co', 'br', 'wa',
  // Germanic (excl. English)
  'de', 'nl', 'da', 'sv', 'no', 'nb', 'nn', 'fi', 'is', 'fy',
  // Slavic
  'pl', 'cs', 'sk', 'hr', 'sr', 'sl', 'bg', 'mk', 'ru', 'uk', 'be',
  // Baltic
  'lv', 'lt',
  // Other European
  'hu', 'ro', 'el', 'sq', 'mt', 'et', 'eu',
  // Turkic / Caucasian
  'tr', 'az', 'kk', 'ky',
  // Asian / other
  'vi', 'id', 'mn',
};
