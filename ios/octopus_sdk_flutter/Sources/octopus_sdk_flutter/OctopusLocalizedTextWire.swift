import Flutter
import Foundation
import Octopus

/// The platform-channel code both bridges answer with when the native SDK refuses a per-language
/// text. Dart maps it back onto `OctopusLocalizedTextValidationError`.
let invalidLocalizedTextErrorCode = "INVALID_LOCALIZED_TEXT"

enum OctopusLocalizedTextWire {
  /// Decodes the wire form of a Dart `OctopusLocalizedText` (`toMap()`), or `nil` when `raw` is
  /// not one:
  /// - `{type: "autoTranslated", text}`
  /// - `{type: "perLanguage", texts: [{language, text}, …], defaultLanguage}`
  ///
  /// The tags arrive as the app wrote them. The only conversion is `locale(forTag:)`, the same
  /// on Android; the native `perLanguage` then validates the texts and its verdict is final.
  ///
  /// - Throws: `OctopusLocalizedText.ValidationError` when the native SDK refuses a per-language
  ///   text, or `.duplicateLanguage` when two tags give the same `Locale`, which a
  ///   `[Locale: String]` cannot hold apart (`.emptyLanguage` when that locale has no language).
  static func decode(_ raw: Any?) throws -> OctopusLocalizedText? {
    guard let map = raw as? [String: Any] else { return nil }
    switch map["type"] as? String {
    case "autoTranslated":
      return (map["text"] as? String).map { .autoTranslated($0) }
    case "perLanguage":
      var texts: [Locale: String] = [:]
      for entry in map["texts"] as? [Any] ?? [] {
        guard let pair = entry as? [String: Any],
              let language = pair["language"] as? String,
              let text = pair["text"] as? String
        else { continue }
        let parsed = Self.locale(forTag: language)
        guard texts.updateValue(text, forKey: parsed) == nil else {
          // Tags without a language ("und", "UND"…) can give equal locales: report what the
          // native SDK reports for any of them, not a duplicate.
          let code = languageCode(of: parsed)
          let language = code.split(separator: "-").first.map(String.init)?.lowercased() ?? ""
          if language.isEmpty || language == "und" {
            throw OctopusLocalizedText.ValidationError(kind: .emptyLanguage)
          }
          throw OctopusLocalizedText.ValidationError(kind: .duplicateLanguage, languageCode: code)
        }
      }
      let defaultLanguage = Self.locale(forTag: map["defaultLanguage"] as? String ?? "")
      return try .perLanguage(texts, defaultLanguage: defaultLanguage)
    default:
      return nil
    }
  }

  /// The locale of a BCP-47 tag as the app wrote it: an underscore is read as a hyphen, then
  /// `Locale(identifier:)` reads the hyphenated identifier, which keeps a script (`zh-Hant-TW`).
  /// Android does the same with `Locale.forLanguageTag`.
  static func locale(forTag tag: String) -> Locale {
    Locale(identifier: tag.replacingOccurrences(of: "_", with: "-"))
  }

  /// The code the native SDK builds for `locale` (`language[-Script][-REGION]`), used to name a
  /// duplicate the bridge catches before the native check can see it.
  static func languageCode(of locale: Locale) -> String {
    let components = Locale.components(fromIdentifier: locale.identifier)
    return [NSLocale.Key.languageCode, .scriptCode, .countryCode]
      .compactMap { components[$0.rawValue] }
      .filter { !$0.isEmpty }
      .joined(separator: "-")
  }

  /// The `FlutterError` for a refused per-language text. `details.kind` is the native kind's case
  /// name, which is the Dart `OctopusLocalizedTextValidationErrorKind` name; a kind a later native
  /// SDK adds reaches Dart as an unknown name, and the `PlatformException` is then kept as it is.
  static func flutterError(_ error: OctopusLocalizedText.ValidationError) -> FlutterError {
    FlutterError(
      code: invalidLocalizedTextErrorCode,
      message: error.debugDescription,
      details: ["kind": "\(error.kind)", "languageCode": error.languageCode as Any]
    )
  }

  /// The prefilled-post CTA of the wire `cta` map, or `nil` when there is none or the native SDK
  /// refuses it (logged). `localizedLabel` wins over the plain `label`, which means an
  /// auto-translated label.
  static func decodeCTA(_ raw: Any?) -> OctopusPrefilledPost.CTA? {
    guard let ctaMap = raw as? [String: Any],
          let urlString = ctaMap["url"] as? String,
          let url = URL(string: urlString)
    else { return nil }
    do {
      let label: OctopusLocalizedText
      if let localized = try decode(ctaMap["localizedLabel"]) {
        label = localized
      } else if let plain = ctaMap["label"] as? String {
        label = .autoTranslated(plain)
      } else {
        return nil
      }
      return try OctopusPrefilledPost.CTA(url: url, localizedLabel: label)
    } catch {
      NSLog("[OctopusSdkFlutter] prefilled post CTA rejected (\(error)) — opening without it")
      return nil
    }
  }
}
