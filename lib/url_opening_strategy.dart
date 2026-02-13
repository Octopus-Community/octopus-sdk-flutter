/// Strategy for handling URLs tapped inside the Octopus Community UI.
///
/// Mirrors the native SDK's URL opening strategy enum.
enum UrlOpeningStrategy {
  /// The URL has been handled by the app. The SDK will not open it.
  handledByApp,

  /// The URL should be handled by the Octopus SDK (opened in the default browser).
  handledByOctopus,
}