import Foundation

/// Normalizes profile pictures before the bridge downloads or decodes them.
enum OctopusProfilePictureInput: Equatable {
  case url(String)
  case base64(String)

  static func parse(_ raw: String?) -> OctopusProfilePictureInput? {
    guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return nil }
    let lowercased = value.lowercased()
    if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
      return .url(value)
    }
    // Any base64 data URI, parameters included (RFC 2397); the decoded bytes
    // are still checked as an image by the caller.
    let payload = value.replacingOccurrences(
      of: "^data:[^,]*;base64,", with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    return .base64(payload)
  }
}
