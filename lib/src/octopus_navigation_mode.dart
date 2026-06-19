/// Selects which navigation container the **native iOS** [OctopusHomeScreen]
/// uses internally for its sub-navigation (opening a post, a group, a profile,
/// …).
///
/// **Why this matters — modal hosting.** When [OctopusHomeScreen] is hosted
/// inside a Flutter **modal route** (`MaterialPageRoute(fullscreenDialog:
/// true)`, `showModalBottomSheet`, …), iOS reparents the SDK's hosting
/// controller during the presentation. The iOS SDK's default (legacy
/// `NavigationView`) container can silently drop programmatic pushes across
/// that reparenting — e.g. tapping a post no longer opens its detail. Passing
/// [navigationStack] swaps in a `NavigationStack` (iOS 16+) whose path
/// survives the reparenting, so sub-navigation keeps working in a modal.
///
/// **Platform support.**
/// - **iOS** → maps to the native `OctopusHomeScreen(navigationMode:)`
///   (`.automatic` / `.navigationStack`), available in the wrapped iOS SDK
///   **1.12.2+**.
/// - **Android** → **no-op.** The Android bridge drives the SDK through a
///   Jetpack Compose `NavHost`, which keeps its back stack across modal
///   hosting, so there is no equivalent setting and the wire key is ignored.
///   The value only affects iOS; it is safe to pass on a cross-platform host.
enum OctopusNavigationMode {
  /// The native iOS SDK picks the navigation container (currently a legacy
  /// `NavigationView`). **Will** silently drop sub-navigation pushes from a
  /// Flutter host — every Flutter route is by definition a UIKit-hosted
  /// reparented presentation where the legacy `NavigationView` misbehaves
  /// (post-tap not opening detail, "Yes" on unsaved-changes alert not
  /// popping, …). Opt-in only — the Flutter wrapper's default is
  /// [navigationStack].
  automatic,

  /// Forces a `NavigationStack` (iOS 16+, with a `NavigationView` fallback
  /// below iOS 16). The navigation path survives the hosting-controller
  /// reparenting that Flutter routes perform, so this is the right default
  /// for [OctopusHomeScreen] hosted from Flutter — and the default this
  /// wrapper picks.
  navigationStack,
}
