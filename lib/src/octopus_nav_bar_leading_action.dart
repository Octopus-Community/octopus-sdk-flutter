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
/// **Platform support.**
/// - **iOS** → maps to the native `OctopusHomeScreen(navBarLeadingAction:)`
///   (`.close(onTap:)` / `.back(onTap:)`), available in the wrapped iOS SDK
///   **1.12.2+**. This is the native replacement for the
///   [OctopusHomeScreen.leadingWidget] / [OctopusHomeScreen.trailingWidget]
///   Flutter overlays on iOS: the iOS SDK only paints its own close button
///   when presented natively (`.sheet` / `.fullScreenCover`), which never
///   happens for a Flutter-hosted `UiKitView`, so before 1.12.2 a
///   Flutter-hosted modal had no native dismiss affordance.
/// - **Android** → **no-op.** The Android SDK already renders its own leading
///   back arrow on the root screen — controlled by
///   [OctopusHomeScreen.showBackButton] and routed to the same `onBack`
///   callback — so the wire key is ignored. On a cross-platform host, pair
///   `navBarLeadingAction` (iOS) with `showBackButton: true` (Android) to get a
///   native dismiss affordance on both platforms; both fire `onBack`.
enum OctopusNavBarLeadingAction {
  /// A close button rendered with the SDK's "close" icon — typically for a
  /// modally-presented host (e.g. a `fullscreenDialog` route).
  close,

  /// A back button rendered with a back chevron — typically for a host
  /// navigation route the SDK was pushed onto.
  back,
}
