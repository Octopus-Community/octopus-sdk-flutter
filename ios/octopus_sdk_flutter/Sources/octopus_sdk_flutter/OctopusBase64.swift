import Foundation

/// Base64 decoding that mirrors Android's `Base64.decode(_, Base64.DEFAULT)`
/// for the two behaviours Foundation does not share: unknown characters and
/// missing padding.
///
/// This file deliberately imports Foundation only, so it can be compiled and
/// checked on its own — see `scripts/check_ios_base64_padding.sh`.
enum OctopusBase64 {
  /// Decodes `encoded`, ignoring every character outside the base64 alphabet
  /// and tolerating padding that is *entirely absent*.
  ///
  /// `Data(base64Encoded:options: .ignoreUnknownCharacters)` covers the first
  /// half (Android's decode table maps every other byte to "skip"), but it still
  /// requires the alphabet characters to come in a multiple of 4, whereas
  /// AOSP's decoder emits the trailing bytes when the input ends mid-quantum
  /// (#404). So the padding is completed here, counting *alphabet* characters
  /// only: counting raw characters would mis-pad a line-wrapped payload.
  ///
  /// Padding is synthesized only when the input contains no `=` at all. AOSP
  /// throws on *incomplete* padding (`"YWJjZA="`), so an input that carries any
  /// `=` is handed to Foundation as-is and yields nil on the same inputs.
  static func decode(_ encoded: String) -> Data? {
    var alphabetCount = 0
    for scalar in encoded.unicodeScalars {
      switch scalar {
      case "=":
        // Explicit padding: Android accepts it only when complete.
        return Data(base64Encoded: encoded, options: .ignoreUnknownCharacters)
      case "A"..."Z", "a"..."z", "0"..."9", "+", "/":
        alphabetCount += 1
      default:
        break
      }
    }
    let remainder = alphabetCount % 4
    // A single leftover character is not a valid quantum: leave it, Foundation
    // returns nil like Android's decoder.
    let missing = remainder == 0 ? 0 : 4 - remainder
    let padded = encoded + String(repeating: "=", count: missing)
    return Data(base64Encoded: padded, options: .ignoreUnknownCharacters)
  }
}
