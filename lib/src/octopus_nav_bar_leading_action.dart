/// A host-driven leading nav-bar item the SDK renders on its **root** screen
/// — the screen selected by [OctopusHomeScreen.initialScreen] (the main feed,
/// or a bridge post / group).
///
/// Use this when you host [OctopusHomeScreen] somewhere the SDK cannot dismiss
/// itself — typically a Flutter modal route — so it needs a host-controlled
/// close / back button. When set, the SDK paints the matching native button;
/// tapping it fires [OctopusHomeScreen.onBack] (it does **not** dismiss
/// anything on its own — your `onBack` is responsible for popping the route).
/// On deeper SDK screens the SDK paints its own back chevron instead, so this
/// item only appears at the root.
///
/// **Platform support — both platforms.**
/// - **iOS** → maps to the native `OctopusHomeScreen(navBarLeadingAction:)`
///   (`.close(onTap:)` / `.back(onTap:)`), available in the wrapped iOS SDK
///   **1.12.2+**. This is the native replacement for the
///   [OctopusHomeScreen.leadingWidget] / [OctopusHomeScreen.trailingWidget]
///   Flutter overlays on iOS: the iOS SDK only paints its own close button
///   when presented natively (`.sheet` / `.fullScreenCover`), which never
///   happens for a Flutter-hosted `UiKitView`, so before 1.12.2 a
///   Flutter-hosted modal had no native dismiss affordance.
/// - **Android** → maps to the native
///   `OctopusHomeScreen(leadingNavigationIcon:)` (`NavigationIconType.Close` /
///   `.Back`), available in the wrapped native Android SDK **1.12.1+**. The
///   root leading icon is overridden with the requested affordance regardless
///   of [OctopusHomeScreen.showBackButton]; tapping it fires the same `onBack`
///   callback. Leaving it `null` keeps the existing Android behaviour — a back
///   arrow gated by [OctopusHomeScreen.showBackButton]. Use [close] when you
///   host the SDK somewhere it cannot dismiss itself (e.g. a modal route) and
///   need a Close (X) affordance the back arrow can't express.
enum OctopusNavBarLeadingAction {
  /// A close button rendered with the SDK's "close" icon — typically for a
  /// modally-presented host (e.g. a `fullscreenDialog` route).
  close,

  /// A back button rendered with a back chevron — typically for a host
  /// navigation route the SDK was pushed onto.
  back,
}
