import Flutter
import Octopus
import UIKit
import XCTest


@testable import octopus_sdk_flutter

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  private func perLanguage(_ texts: [(String, String)], defaultLanguage: String) -> [String: Any] {
    [
      "type": "perLanguage",
      "texts": texts.map { ["language": $0.0, "text": $0.1] },
      "defaultLanguage": defaultLanguage,
    ]
  }

  /// The bridge reads an underscore as a hyphen and keeps a script, as the Android bridge does.
  func testLocalizedTextReadsAnUnderscoreAsAHyphen() throws {
    let label = try XCTUnwrap(OctopusLocalizedTextWire.decode(
      perLanguage([("pt_BR", "Ler"), ("zh_Hant_TW", "閱讀")], defaultLanguage: "pt_BR")))
    XCTAssertEqual(label.defaultLanguageCode, "pt-BR")
    XCTAssertEqual(label.textsByLanguageCode, ["pt-BR": "Ler", "zh-Hant-TW": "閱讀"])
  }

  /// Two tags giving the same locale are a duplicate, never a crash nor a dropped text.
  func testLocalizedTextTwoTagsOfOneLocaleAreADuplicate() {
    XCTAssertThrowsError(try OctopusLocalizedTextWire.decode(
      perLanguage([("en-US", "Read"), ("en_US", "Read it")], defaultLanguage: "en-US"))
    ) { error in
      let validation = error as? OctopusLocalizedText.ValidationError
      XCTAssertEqual(validation?.kind, .duplicateLanguage)
      XCTAssertEqual(validation?.languageCode, "en-US")
    }
  }

  /// The undetermined language `und` names no language: the native SDK refuses it, as Android's
  /// `Locale.forLanguageTag` does.
  func testLocalizedTextUndIsEmptyLanguage() {
    for tag in ["und", "und_FR"] {
      XCTAssertThrowsError(try OctopusLocalizedTextWire.decode(
        perLanguage([(tag, "Read"), ("en", "Read")], defaultLanguage: "en")), tag
      ) { error in
        XCTAssertEqual((error as? OctopusLocalizedText.ValidationError)?.kind, .emptyLanguage, tag)
      }
    }
  }

  /// Tags without a language that give equal locales are reported as the native SDK reports
  /// them, not as a duplicate.
  func testLocalizedTextTagsWithoutALanguageAreEmptyLanguage() {
    XCTAssertThrowsError(try OctopusLocalizedTextWire.decode(
      perLanguage([("und", "a"), ("UND", "b"), ("en", "c")], defaultLanguage: "en"))
    ) { error in
      let validation = error as? OctopusLocalizedText.ValidationError
      XCTAssertEqual(validation?.kind, .emptyLanguage)
      XCTAssertNil(validation?.languageCode)
    }
  }

  /// A native refusal reaches Dart as INVALID_LOCALIZED_TEXT with the Dart kind name.
  func testLocalizedTextRefusalIsEncodedForDart() {
    XCTAssertThrowsError(try OctopusLocalizedTextWire.decode(
      perLanguage([("en", "Read")], defaultLanguage: "fr"))
    ) { error in
      guard let validation = error as? OctopusLocalizedText.ValidationError else {
        return XCTFail("unexpected \(error)")
      }
      let flutterError = OctopusLocalizedTextWire.flutterError(validation)
      XCTAssertEqual(flutterError.code, "INVALID_LOCALIZED_TEXT")
      let details = flutterError.details as? [String: Any]
      XCTAssertEqual(details?["kind"] as? String, "defaultLanguageMissing")
      XCTAssertEqual(details?["languageCode"] as? String, "fr")
    }
  }
}
