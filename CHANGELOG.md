## 1.13.2

### New Features
- `OctopusSDK.showOctopusHomeScreen()` and `OctopusSDK.openNotification()` now
  accept **`onBack`** and **`navBarLeadingAction`**. `onBack` is a
  *notification*, not a delegation: the helper still pops the route it owns —
  before this change it popped and told the host nothing, so a host had no way
  to learn the user had left the community without dropping down to the
  `OctopusHomeScreen` widget and rebuilding the route itself. The callback runs
  **before** the pop, and a callback that throws is reported through
  `FlutterError.reportError` while the route pops anyway, so a host handler can
  never strand the user inside the SDK. The pop is guarded on the helper's own
  route still being the current one when the callback returns, so a callback
  that navigates by itself — pops the route, or pushes a dialog — is neither
  double-popped nor has its own route closed from under it; a callback that
  only does bookkeeping pops exactly as before. `navBarLeadingAction` is
  forwarded verbatim to the embedded view, so the full-screen helper can now
  show the close (X) icon instead of the back chevron. Both parameters are
  optional; omitting them leaves the previous behaviour unchanged, except that
  a leading-icon tap arriving while the route is already leaving is now a
  no-op instead of popping whatever sits under it.

  Only the tap on the SDK's **root** leading icon reaches `onBack`; no
  OS-level gesture does. While the SDK is on its **root** screen, Android
  system / predictive back pops the Flutter route directly, without a
  `backRequested` event. **Deeper inside the SDK** the native navigation stack
  consumes the gesture and navigates up inside itself, so neither `onBack` nor
  the returned `Future` fires and the Flutter route stays up. On iOS the helper
  pushes a plain `MaterialPageRoute`, so the swipe-from-left-edge gesture it
  enables is a Flutter-level pop that emits no `backRequested`, while the
  native SDK runs its own navigation stack for its internal screens. The
  returned `Future` — which completes on *every* path that actually dismisses
  the route — remains the way to observe those.

### Bug Fixes
- Android: fixed a crash (`UninitializedPropertyAccessException` in
  `OctopusSDK.getKoinApp`) when Android restores the native create-post
  editor in a process where the SDK was never initialised — after a process
  death (low memory, another crash, "Don't keep activities") while the editor
  was in the foreground. The editor activity now finishes itself instead of
  rendering, handing control back to the host app as the OS restored it. On
  Android, `showCreatePostScreen()` called before `initialize()` now fails
  with the same `NOT_INITIALIZED` error as on iOS instead of starting the
  editor.

### Dependencies
- Android Octopus SDK: 1.13.2 → 1.13.4. No API change. Fixes four crashes in
  the native Android layer:
  - two in the embedded UI when a host sets `overrideDefaultLocale` — the
    text-selection "process text" actions and the fullscreen image viewer
    (1.13.3);
  - the `UninitializedPropertyAccessException` on `koinApp` when Android
    restores an Octopus screen — including the embedded view — in a process
    where the SDK has not been initialised yet: the native UI now renders
    nothing and finishes cleanly instead of crashing (1.13.4);
  - a `NoClassDefFoundError` / `NoSuchMethodError` at `initialize()` in host
    apps that shrink their build with R8, because gRPC's Guava surface was
    stripped: the SDK now ships the consumer keep rules it needs (1.13.4).

### Example App
- New **Presentation modes → Embedded Back Button** scenario: pick the leading
  icon (`showBackButton`, `navBarLeadingAction`, and the case where both are set
  and disagree), pick the container (the embedded `OctopusHomeScreen` widget or
  the `showOctopusHomeScreen` helper), and watch a live counter of how many
  times `onBack` fired and from which container — the two callback contracts
  side by side.
- **Dark-theme nav accent, SDK brand theme and remaining `ColorScheme` teal
  values corrected to the shared sample tokens contract**, ported from the
  Android sample: the earlier navy pass had already retired teal/salmon but
  predated that later contrast fix, so dark theme still used the
  light-theme accent `#1D88FE` directly as a label, a selected-segment
  label and a selected-control fill, and the SDK theme's dark
  `primaryMain`/`onPrimary` were `#1D88FE`/black. `#1D88FE` is fill-only
  (3.50:1 on white — under the 4.5:1 label/text floor in either theme):
  dark theme now uses the dedicated `AccentDark #6FB2FF` for labels/icons
  and selected-control fills, with `AccentInk #142238` as the ink on any
  text drawn over an `AccentDark`/`#1D88FE` fill — including the selected
  segmented-button label, which previously read white-on-`#1D88FE` in
  light theme (3.50:1) — while the switch thumb, a graphical control
  rather than text, keeps the white/`AccentInk` split its 3:1 non-text
  floor allows. The SDK theme's dark block is now `primaryMain #6FB2FF ·
  primaryLow #142238 · primaryHigh #DCE9FC · onPrimary #142238`, the nav
  indicator is the accent at a posed 15% alpha instead of a hardcoded tint
  hex, and every remaining teal `ColorScheme` container/tertiary/surface
  value (both themes) is now a navy tint instead. No wording or layout
  change.
- **iOS sample: Release now signs against a `production` push entitlement.**
  All three build configurations shared `Runner.entitlements`, which declares
  `aps-environment = development`, while an App Store provisioning profile
  carries `production` — a mismatch on the configuration the TestFlight archive
  is built from. Release now points at a dedicated
  `Runner-Release.entitlements`; Debug and Profile keep the development value,
  the same per-configuration split the Swift and React Native samples use.
- **Sample visual identity aligned with the shared cross-platform design
  spec** (cadrage report 24): the host-app footer notice is gone from every
  screen (Home, Scenarios, each of the 21 scenario shells, Settings) — it
  duplicated identity already conveyed elsewhere and fell under the shared
  readability floor. The app label is now the attributive
  `Octopus Sample for Flutter` (`AndroidManifest.xml`, `Info.plist`,
  `MaterialApp.title`), matching Flutter's own brand guidelines instead of
  juxtaposing the SDK name with the platform's. A "Flutter" platform badge
  now sits on the Home tab (slot hue `#02569B`, and its lighter pair
  `#54C5F8` in dark mode where the brand hue falls under the contrast floor;
  tonal — never the Flutter logo, which the brand guidelines reserve for
  in-app use only), and
  Settings carries the required plain-text attribution ("Built with
  Flutter™" + Google's trademark line), since no local asset for the
  official "Build with Flutter" lockup exists in this repo.
- **Fixed embedded SDK surfaces rendering a near-black CTA by default.**
  `AppState.effectiveOctopusTheme()` returned `null` until the Theme
  scenario's presets were touched by hand, so every site embedding the
  SDK fell through to the SDK's own unthemed `#141414` primary — an omitted
  default, not a theming bug. It now falls back to `brandOctopusTheme()`,
  matching what the Android sample's `Default` branch already does. The
  Theme scenario's Preset 1 is renamed "Brand theme" to reflect that it's
  no longer the no-theme oracle, and a new Preset 5 ("SDK default (no
  theme)") passes an explicit empty `OctopusTheme` to keep that oracle
  reachable.
- **`buildAppTheme()` no longer derives its `ColorScheme` via
  `ColorScheme.fromSeed`.** A seeded scheme rendered a `primary` nobody
  chose, shifted with the Material/Flutter version, and left every role
  besides `secondary` unreviewed. It is now hand-built role-by-role, ported
  verbatim from the Android sample's `Theme.kt` — the one complete,
  Figma-annotated source for this palette — with an explicit nav-bar accent
  (teal in light mode, salmon in dark: salmon on white measures ~2.1:1,
  under the 4.5:1 contrast floor) instead of the Material default. The
  unified SDK brand theme handed to the embedded SDK
  (`primaryMain`/`primaryLow`/`primaryHigh`/`onPrimary`) now matches the
  values shared with the Android sample instead of Flutter's own ad hoc
  set. The bottom nav itself moves from `BottomNavigationBar` (Material 2)
  to `NavigationBar` (Material 3), same four tabs and order.
- **Sample shell reduced to 4 tabs** (Home / Scenarios / Community /
  Settings): the Debug tab is gone, replaced by a modal opened from Settings
  (`debug-open-button`), matching the native samples' navigation. Settings
  also gains a visually separated danger zone — "Back to Config"
  (non-destructive) in its own card, away from "Reset Configuration"
  (destructive, error-tinted icon and title, and which now fully stops the
  SDK session before clearing local state).
- The Server field on the Config and Settings screens is read-only and now
  shows the *resolved* host (e.g. `Resolved host: … (set by
  --dart-define=OCTOPUS_API_HOST)`) instead of an editable value.
- `settings-version-label` now reads the installed build's real version and
  build number via `package_info_plus`, replacing a hand-kept string
  constant that had no automated link to `pubspec.yaml` and could silently
  drift from it.
- The production-environment warning banner (`env-warning-banner`) is now
  visible to accessibility tooling, so on-device QA passes (uiautomator /
  XCUITest) can assert its presence. It always rendered correctly but never
  reached the accessibility tree at all: it was painted before the
  Navigator, whose route machinery blocks the semantics of everything
  painted before it. The app builder now paints it after the Navigator
  while keeping it visually on top, and the banner carries an accessibility
  label; a widget test locks the semantics node's presence.

## 1.13.1

### New Features
- Three internal test affordances bridged from the native SDKs, for QA
  scenarios only — not part of the supported public API and may change or be
  removed at any time: `OctopusSDK.debugOverrideProfileFieldsLock`,
  `debugOverrideContentOptions`, `debugOverrideTermsAcceptanceMode`, with new
  `ProfileFieldsLock`, `ContentOptions` (+ `PostOptions` / `CommentOptions` /
  `ReplyOptions`), and `TermsAcceptanceMode` Dart types mirroring the native
  models. Passing `null` clears the override and falls back to the
  backend-provided config, matching both natives.
  **Android, and iOS via CocoaPods; not yet on iOS via Swift Package
  Manager.** The three native `debugOverride*` entry points live on
  `OctopusSDK` in the `Octopus` module (reachable on both iOS integration
  paths), but the three parameter types they construct (`ProfileFieldsLock`,
  `ContentOptions`, `TermsAcceptanceMode`) live in `octopus-sdk-swift`'s
  `OctopusCore` target. CocoaPods has no concept of a package "product": this
  plugin declares `OctopusCommunityCore` as a pod dependency and imports
  `OctopusCore` directly, so the CocoaPods path is fully implemented. Swift
  Package Manager only exposes a dependency's declared `products`, and
  `OctopusCore` is not one of `octopus-sdk-swift`'s SPM products — so on the
  SPM path these three calls resolve with an `UNSUPPORTED_PLATFORM`
  `PlatformException` until upstream exposes the type another way.
- `OctopusTheme` gains two optional color overrides, `background` and `link`,
  wired end-to-end to the native Android and iOS color schemes (`background`:
  the community screens' background color; `link`: the color of clickable
  links in posts and comments). Both default to `null`, which keeps the
  native SDK's own default — no behavior change for existing hosts.
- `OctopusTheme` gains `fontFamily` and `fontWeight`, applied to every SDK text
  style (titles, body, captions) and to the top app bar / navigation bar title.
  `fontWeight` is a plain 100-900 Int (no native setup needed). `fontFamily` is
  **not** read from the Flutter asset bundle — it must additionally be
  registered natively with the exact same name: as a font resource under
  `android/app/src/main/res/font/` on Android, and as a PostScript name
  declared under `UIAppFonts` in `ios/Runner/Info.plist` on iOS. An
  unregistered name is logged as a warning on both platforms and falls back to
  the SDK's default font rather than being silently ignored. Both fields
  default to `null` — no behavior change for existing hosts. Note the
  navigation-bar scope differs slightly by platform: on Android it restyles
  only the top app bar's title text (back/close are icon-only, with no font to
  override); on iOS it also affects the navigation bar's icon buttons.
  `fontWeight` must be within 100-900 — the `OctopusTheme` constructor now
  asserts it, since an out-of-range value used to reach Android as a crash.
- `OctopusTheme.fontSizeNavBarItem` — font size for navigation-bar items.
  **iOS only**: the native iOS theme has a dedicated `navBarItem` font slot and
  the native Android typography has no counterpart, so the Android bridge
  documents the key as ignored rather than approximating it by resizing another
  slot. `null` keeps the previous behaviour (nav-bar items follow
  `fontSizeBody1`). Reaches both theme consumption paths — the embedded
  `PlatformView` and the standalone create-post screen — so it applies to
  `showOctopusCreatePostScreen` too, not only to the embedded community view.

- **Member-scoped entry points: open one member's posts or profile directly.**
  Two additive `OctopusInitialScreen` cases, plus a dedicated widget, all
  reaching the same native screens the SDK already opens when a user taps a
  member inside the community:
  - `OctopusInitialScreen.activity(ActivityScreenInfo.clientUserId(id))` /
    `.activity(ActivityScreenInfo.profileId(id))` — that member's posts-only
    activity screen. The two named constructors are mutually exclusive and take
    different paths natively: `clientUserId` is resolved through the
    client-user-id lookup, so it needs a community that **exposes client user
    ids**, while `profileId` is already resolved and opens with no lookup. An id
    that does not resolve shows the empty state; it never falls back to another
    member. Pointed at the connected user's own id, the natives open their
    two-tab activity screen instead.
  - `OctopusInitialScreen.profile({String? clientUserId})` — that member's
    read-only Octopus profile; omit the id (or pass `null`) for the connected
    user's **own, editable** profile, where `onModifyUser` fires your edit page.
  - `OctopusProfileScreen({String? clientUserId, …})` — the standalone
    shorthand for the case above, same shape as the existing
    `OctopusPostDetailsScreen` / `OctopusGroupDetailsScreen` widgets.

  These entry points open on the screen's own default tab; there is no way to
  preselect another one.

  Member ids are trimmed, so surrounding whitespace never reaches the lookup,
  and an id left blank or whitespace-only counts as no id at all:
  `OctopusInitialScreen.profile` then opens the connected user's own profile,
  exactly as omitting it does, while `.activity` — which has no own-user form —
  opens the main feed.

  This is the other half of Unified Profile: once your app intercepts every
  profile tap with `onNavigateToProfile` and renders its own page, these are the
  entry points that let it hand the user back to the SDK on purpose.

### Known Issues
- Setting `OctopusTheme.fontFamily` or `OctopusTheme.fontWeight` also sets the
  Android navigation bar title to the size of `fontSizeBody1`, which is smaller
  than the title size applied when no font override is set. `fontSizeBody1`
  controls the resulting size. Kept as-is in this release.

### Fixed
- **iOS: an unset theme slot no longer overrides the native default.** Both iOS
  theme builders substituted a value for anything the host left unset, so a
  partial `OctopusTheme` silently redefined the rest of the theme:
  - **Colors** were substituted with `systemBlue` / `white`, replacing the SDK's
    adaptive primary palette with a fixed blue.
  - **The six font sizes** were substituted with `26 / 20 / 17 / 14 / 12 / 10`
    points — numbers that were never the SDK's own defaults
    (`26 / 22 / 18 / 16 / 14 / 12`), and that are fixed sizes where the native
    defaults are `UIFontMetrics`-scaled. A host setting *any* theme key therefore
    got community text both mis-sized and frozen against the reader's Dynamic
    Type setting.

  An unset color or font size now keeps the SDK's own default instead of being
  substituted — the real default font sizes are `26 / 22 / 18 / 16 / 14 / 12`.

  This mattered immediately for the three keys above, since each of them alone
  now builds a theme. It also changes the pre-existing `themeMode`-only path: a
  theme carrying nothing but `themeMode` used to yield a blue primary and
  wrapper-invented type sizes, and now keeps the SDK's palette and type scale.

- **iOS: the same six wrong sizes were still reachable through `fontFamily` /
  `fontWeight`.** A custom family or weight needs a concrete point size even for a
  slot whose size the host left unset, and the sizes used for that were the same
  `26 / 20 / 17 / 14 / 12 / 10` — so a host setting only `fontFamily` still got
  five of six slots mis-sized. They now repeat the natives' own scale
  (`26 / 22 / 18 / 16 / 14 / 12`, plus 17 for `navBarItem`, the base size of the
  `.body` style its native default resolves to).

- **iOS: an explicit font size now follows the reader's text-size setting**, as
  the Android bridge's `<size>.sp` always did and as the iOS SDK's own defaults
  do. `Font.system(size:)` renders a fixed point size, so setting any size at all
  used to opt that slot out of Dynamic Type on iOS only — on the very keys a host
  reaches for to make text bigger. Every size the bridge resolves, explicit or
  reference, is now run through `UIFontMetrics(forTextStyle:).scaledValue(for:)`
  with the slot's own text style, and the custom-family path uses
  `Font.custom(_:fixedSize:)` so the value is scaled once rather than twice.
  A size set here is a base size on both platforms, not a frozen one.

### Example App
- The Initial-screen scenario gains four presets for the new entry points —
  member activity by `clientUserId` and by `profileId` (resolving one with
  `fetchCommunityData` when the field is left empty, so it runs in one tap),
  plus `OctopusProfileScreen` with and without an id. Both member id fields
  fall back to the connected user's own id.
- The host-rendered profile page (`ClientProfilePage`, the page
  `onNavigateToProfile` pushes) now ends with those same member entry points, so
  the round trip host page → back into the SDK is exercised from the place a
  real host actually needs it.
- **New "Create Post (Bridge Share)" scenario.** The Scenarios tab now has a
  dedicated screen for opening the post editor prefilled with a payload the host
  app builds: five one-tap presets cover text only, text + call-to-action, text +
  image, the full payload and image only, over an editable form (text, CTA label
  and url, target group picked from the live groups stream, bundled image). An
  invalid payload — text out of bounds, half-filled CTA — is reported in the
  result panel with the concrete rejection instead of opening the editor. The
  Initial Screen scenario still covers the editor mounted *inside* a host route;
  this one presents it as a full screen.
- **The reactions scenario walks the capability instead of the enum.** Its first
  three presets are now react, change the reaction, then unreact — the sequence
  a tester needs to see — with the remaining reaction kinds moved to presets 4
  through 7. Renamed from "Set Reaction" to "Reactions", and its automation
  identifiers now match the shared QA catalog verbatim.

### Documentation
- `PARITY_MATRIX.md` rewritten against native 1.13.2: 6 real gaps from 2 root
  causes, replacing a 2026-05-28 table whose 53 "missing" APIs were ~46 stale.
  It now carries its anchors, the genuinely-N/A and Android-only-by-design
  verdicts, and a section on how to regenerate it — a matrix nobody can
  regenerate is the defect being fixed. `PARITY_VERIFICATION_2026-05-29.md` and
  `REFACTOR_PLAN.md` §4bis are marked superseded instead of contradicting it.
- The install snippet in `README.md` was still `^1.12.3` after 1.13.0 was
  published, and the one in `doc/push-notifications-with-firebase.md` had been
  `^1.11.0` since that release. Both now read `^1.13.0`, and the coherence guard
  checks every doc's snippet against the package version so a release cannot
  ship a snippet naming an older version again.
- `example/README.md` now states the Android prerequisite up front: the sample
  applies the Google Services Gradle plugin for push, so every Android build
  fails without a `google-services.json`, which is per-project and gitignored.
  The step was only documented in a nested notifications README.

## 1.13.0

### Dependencies
- Android Octopus SDK: 1.12.1 → 1.13.2
- iOS Octopus SDK: 1.12.6 → 1.13.2
- New direct dependency: `meta: ^1.9.0`, for the `@useResult` annotation on the
  result-returning APIs (`package:flutter/foundation.dart` only re-exports a
  subset of `meta` and not that one). Already in every Flutter app's transitive
  graph, and pinned there: the `flutter` package itself depends on `meta` at an
  exact version (`1.17.0` on the toolchain this repo builds against), so
  declaring `^1.9.0` adds a name to `pubspec.yaml` without giving the solver
  anything new to choose — the SDK's pin still wins.

Both native pins move to the 1.13 line. Most of what 1.13 brings is inherited
with no wrapper change: **24 SDK languages** (15 new, including Arabic with
RTL), **large-screen content width** (content capped and centered on tablets
instead of stretching edge-to-edge), a **"View group" entry in the post
menu**, the community background color applied on every native screen
(iOS 1.13.2), design-system polish, and — on iOS — Xcode 27 compatibility
(1.13.1) plus a fix for a banned user being logged out under a non-English
locale (1.13.2). Android 1.13.2 additionally fixes **in-app browser theming**
(links the SDK opens no longer mix a toolbar from one color scheme with content
from the other, and a translucent color slot is dropped instead of rendering as
a see-through toolbar) and **text legibility on hosts that darken `background`
without redefining its content colors** — most visibly the profile overflow
menu, whose labels were invisible. It also makes the native public Flows safe to
collect before `initialize()`, re-binding them on every re-initialization:
inherited plumbing, no wrapper API change.

### Breaking
- **`SettingsAboutScreen` removed from the `Screen` hierarchy.** The native SDKs
  removed the "About the community" screen in 1.13.0 — its three legal links
  were already duplicated in the Activity and Profile overflow menus — so the
  `settingsAbout` screen-displayed event no longer exists on either platform and
  the wrapper can no longer receive it. Source-breaking only for hosts with an
  exhaustive `switch` over `Screen` that has no `default`/wildcard arm: delete
  the `SettingsAboutScreen()` arm. No runtime behavior change — the event was
  already unreachable once the native screen was gone. See
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x).

- **`connectUser` now returns an `OctopusResult`** — it used to report success on
  a refused connection (see *Fixed* below for the defect and the typed errors).
  Calls keep compiling (`void` is a top type); a host class that **overrides or
  implements** `connectUser` / `connectUserWithTokenProvider` with the old
  `Future<void>` return type does not. Compiling is not the same as analyzing
  clean: a bare statement that drops the result now raises `unused_result`, see
  the `@useResult` entry below. See
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x).

- **Behaviour change (not source-breaking) — on iOS, `await connectUser(...)` now
  waits for the connection attempt.** It could not report a refusal without
  waiting for one: the iOS bridge used to fire the reply *before* the native call
  had done anything, so the `Future` completed in a few milliseconds no matter
  what happened next. It now completes when the attempt does. Android already
  awaited, so this closes an asymmetry rather than opening one — but **read this
  if you `await connectUser(...)` on a blocking path** (a splash screen, a
  navigation guard): on iOS that `await` can now take as long as the network
  does, and up to the 60 s token-provider timeout if your `tokenProvider` never
  answers. Timing is unchanged for a call you never await — but dropping the
  result as a bare statement now raises an `unused_result` warning, where
  `unawaited(...)` does not, see the `@useResult` entry below. See
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x).

- **`connectUser` and `connectUserWithTokenProvider` are `@useResult`.** Ignoring
  their result raises an `unused_result` **warning**, and `flutter analyze` /
  `dart analyze --fatal-warnings` exit non-zero on warnings alone — so a host that
  upgrades without changing a line can see its own CI go red on those two call
  sites. Nothing breaks at runtime and no behaviour changes; handle the result, or
  discard it explicitly with `final _ = await …` (Dart 3.7+ for a non-binding `_`;
  below that, use `// ignore: unused_result` — see
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x)). The annotation is deliberately
  **not** extended to the other `OctopusResult`-returning methods here: that is a
  separate, separately-migratable break and belongs in its own change.

- **Behaviour change (not source-breaking) — `OctopusPrefilledPost` accepts a
  content-less payload.** Matching the native 1.13 relaxation, a payload carrying
  only a `topicId` and/or a `cta` is now accepted and opens the editor on the
  preselected group with empty, user-editable fields; it previously threw
  `OctopusPrefilledPostContentEmptyError`. **Read this if you relied on that
  throw** as your only empty-payload check: you now get an empty editor instead
  of an error, so validate host-side before constructing the payload. The error
  class is kept and still exported so existing `switch` statements over
  `OctopusPrefilledPostValidationError` stay exhaustive, but it is never thrown
  again — the natives kept their `ContentEmpty` case for the same reason.
  Whatever content *is* provided is still validated (text length, CTA
  label/url). The Android bridge's full-screen create-post entry point had the
  same pre-1.13 rule baked in and silently dropped a `topicId`/`cta`-only
  prefill; it now only drops a wholly empty one. See
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x).

- **Behaviour change (not source-breaking) — on Android, `bottomSafeAreaInset: 0`
  resolves the inset from the mount point.** On the four embedded widgets, `0` no
  longer means "reserve nothing" but "reserve whatever bottom padding the ambient
  `MediaQuery` still has left". That is what keeps the native floating "Write a
  post" pill clear of the system navigation bar on edge-to-edge Android (API 35+)
  with no host configuration — the full contract is under `### Fixed` below.
  **Read this if you pass a literal `0` (or any value ≤ 0) to mean "reserve
  nothing", or if you mount one of these widgets in a host that pads the layout
  without consuming the padding** — a `Column` above a fixed footer, a plain
  `Padding`, a `Stack` bottom overlay: those shapes now reserve the navigation-bar
  inset a second time inside the native view. Both are addressed by consuming the
  padding (`MediaQuery.removePadding(context: context, removeBottom: true,
  child: …)`) or by passing the total you want. No signature, type or default
  changed, and **iOS is unaffected** — it deliberately does not resolve. See
  [MIGRATING.md](MIGRATING.md#to-1130-from-112x).

### New Features
- **Two new screen-displayed events from the native Unified Profile work.** Both
  are additive members of the `Screen` hierarchy, delivered through the existing
  `OctopusSDK.events` stream:
  - `OtherUserPostsScreen(profileId:)` — another member's activity (their posts
    list), kept distinct from the profile summary reported by
    `OtherUserProfileScreen` so host analytics can tell the two apart. Emitted on
    **both** platforms.
  - `ActivityScreen` — the connected user's own activity, emitted instead of
    `ProfileScreen` when the community runs in Unified Profile mode.
    **Android only**; the iOS native SDK has no equivalent screen event.

  **When they fire.** Both come from the native activity screen, but they are not
  gated the same way, and only one of them needs Unified Profile:
  - `OtherUserPostsScreen` fires on the **ordinary** path — tap another member's
    avatar or name and the SDK opens that member's activity, with no Unified
    Profile involved. Verified on device: the event arrives with
    `onNavigateToProfile` unwired.
  - `ActivityScreen` is the connected user's own activity, which is what replaces
    `ProfileScreen` once the community runs in Unified Profile mode — so that one
    does depend on the gate below.

  Add both arms to keep your switch exhaustive.

- **Unified Profile: read a member's community data.** Enrich **your own**
  profile screen with a member's Octopus stats instead of sending the user to the
  SDK's native profile screen:
  - `OctopusSDK().fetchCommunityData(profileId: …)` /
    `fetchCommunityData(clientUserId: …)` — a one-shot refreshed snapshot,
    returning `OctopusCommunityData?`.
  - `OctopusSDK.communityDataFlow(profileId: …)` /
    `communityDataFlow(clientUserId: …)` — the reactive counterpart; emits the
    current value then again on every refresh. Each subscription drives its own
    native observation and is torn down on cancel.
  - New models `OctopusCommunityData` (`profileId`, `messageCount`,
    `gamification`) and `OctopusGamification` (`level`, `score`). Every field
    past `profileId` is nullable — `null` means "the community does not publish
    this", not zero. `gamification` is `null` when the community has no
    gamification configured. `score` is **always `null` through this API**, your
    own profile included: both natives resolve community data from a member's
    *public* profile, which never carries the score (back-office consumers only).
    It exists for forward-compatibility, matching the native models — use `level`
    to show a member's standing.
  - Identify the member by **exactly one** of `profileId` (their Octopus id, e.g.
    from `OtherUserProfileScreen`) or `clientUserId` (your app's own id, which
    requires the community to expose client user ids). Passing both, or neither,
    throws an `ArgumentError` in every build — thrown synchronously for
    `communityDataFlow`, when the stream is built. An unknown member yields
    `null` rather than an error, so a UI binding never breaks.
  - **Naming note:** the native Android SDK calls the Octopus id `userId` and
    splits the API in two (`fetchCommunityData` /
    `fetchCommunityDataByClientUserId`); this wrapper uses `profileId`
    everywhere — matching iOS and the id already reported by the screen events —
    and takes the id kind as a named parameter instead.
- **`OctopusProfile.clientUserId`** — the connected user's id in **your** system,
  as passed to `connectUser`. Populated in SSO mode for a non-guest user; `null`
  in Octopus-authentication mode and for a guest. The native SDKs hold it locally,
  independent of the community's expose-client-user-ids setting — that setting
  gates *other* members' client user ids, not the connected user's. Use it to
  correlate the Octopus profile with your own user record before calling
  `fetchCommunityData`.

- **Unified Profile: handle profile taps yourself** — new optional
  `onNavigateToProfile` on all six public entry points: the four widgets
  (`OctopusHomeScreen`, `OctopusHomeContent`, `OctopusPostDetailsScreen`,
  `OctopusGroupDetailsScreen`) and the two navigation helpers
  (`OctopusSDK.showOctopusHomeScreen`, `OctopusSDK.openNotification`). When you
  pass it, the SDK routes **every** profile tap to you — another member's and the
  connected user's own — with that member's `clientUserId`, and stops showing its
  native profile screens. Pair it with `fetchCommunityData` to render your own
  profile page.

  **Passing the callback is the activation switch**, so it is opt-in: leave it
  null (the default) and nothing changes — existing hosts keep the SDK's profile
  screens. Activation is an **AND gate**: wiring it alone is not enough, the
  community must also be configured to expose client user ids. A member with no
  client user id (a guest, or a back-office-created profile) opens the Octopus
  activity screen instead, so you never receive a tap you cannot resolve.

  It is **mount-time**: Android takes it as a parameter of the native composable,
  so changing it on an already-mounted view has no effect until the view is
  rebuilt. The iOS SDK exposes a runtime setter instead; the bridge absorbs that
  asymmetry — it sets the native callback when a view mounts opted in, and clears
  it when a view mounts opted out — so the *Dart-facing* contract reads the same
  on both platforms.

  One caveat that is **not** symmetric, because the iOS setter lives on the
  shared SDK instance: on iOS it is last-mount-wins. If you keep two embedded
  views alive at once (one behind a pushed route or a modal) and they disagree
  about opting in, the most recent mount decides for both — and popping back does
  not restore the first view's choice, since it does not remount. Keep a single
  embedded view alive, or opt every one of them in the same way. Android is
  per-view and unaffected.

  This is also what unlocks the `ActivityScreen` event above — the connected
  user's own activity only replaces the profile screen once Unified Profile is
  active. `OtherUserPostsScreen` does **not** depend on it and already fires
  without this callback; see the note on that entry.

  On iOS this additionally wires the native SDK's separate
  `onNavigateToProfileEditCallback`, which the activity screen uses to gate its
  "Edit my profile" item — it is routed to your existing `onModifyUser`, so you
  still get a single hook. Because the native SDK hides that item when the
  callback is nil, iOS only offers it to hosts that passed `onModifyUser`.
  **Known divergence:** Android wires its equivalent unconditionally (one native
  parameter serves both edit paths there), so on Android the item is shown even to
  a host with no `onModifyUser`, where tapping it does nothing. Gating it would
  take more than mirroring the iOS check — the native Android SDK *requires* that
  callback in SSO mode with app-managed profile fields — so it is left as-is for
  now. Pass `onModifyUser` alongside `onNavigateToProfile` and both platforms
  behave identically.

  Beneath those entry points, `OctopusSDK.embeddedView` — the low-level platform
  view, for hosts that mount it themselves — gains two matching flags:
  `interceptProfileTaps` (opt into the native callback) and
  `hasModifyUserHandler` (tells iOS whether to offer the activity screen's "Edit
  my profile" item, per the divergence above). The four widgets derive both from
  the callbacks you pass them, so you only set them yourself if you build directly
  on `embeddedView`.

Still **not exposed** from the native Unified Profile surface: the standalone
activity/profile screen entry points (Android's `navigateToOctopusActivity` /
`navigateToOctopusProfile`, iOS's `OctopusInitialScreen.activity` and
`OctopusProfileScreen`). They are additive on top of the callback above and left
to a follow-up.

### Fixed
- **`connectUser` no longer reports success when the connection was refused** — with one native iOS path that still resolves, described below. Both bridges called the native SDK's `connectUser` and discarded its result — Android threw away the returned `OctopusResult`, iOS bound the non-throwing overload that only debug-logs — so a banned user, a JWT the backend rejects, or a missing token resolved exactly like a successful connection. A host had nothing to display and no way to know: the typical symptom was a login screen that appeared to do nothing. `connectUser` and the deprecated `connectUserWithTokenProvider` now return `Future<OctopusResult<void, ClientUserError>>`, carrying the refusal.
  - **Call sites keep compiling; overrides do not.** `void` is a top type in Dart, so every existing *call* still compiles — `await octopus.connectUser(...)` as a statement, an assignment to a `Future<void>`, `unawaited(...)`, `Future.wait`, a tearoff stored in a `Future<void> Function({...})` typedef. Compiling is not analyzing clean, though: the first of those, the bare statement, now raises an `unused_result` warning — see the `@useResult` entry in *Breaking*. The others assign, pass or return the value, which counts as using it. What breaks is a class that **overrides or implements** `connectUser` (or `connectUserWithTokenProvider`) while still declaring the old `Future<void>` return type — a host wrapper around `OctopusSDK`, or a hand-written `OctopusSDKPlatform` fake in host tests: `invalid_override`. Widen the override's return type. Mocks that never redeclare the method (mocktail-style `noSuchMethod`) are unaffected. See [MIGRATING.md](MIGRATING.md#to-1130-from-112x).
  - **The typed leaves are deliberately not symmetric across platforms.** `ClientUserMissingTokenError` only ever comes from Android; `ClientUserInvalidTokenError` and `ClientUserCommunityAccessDeniedError` only from iOS; `ClientUserBannedError`, `ClientUserProfileError` and `ClientUserOtherError` from both. The per-platform table in the `ClientUserError` doc comment is the reference, and it is machine-checked against both bridges by `scripts/verify_connect_user_parity.dart` — a native bump that adds a variant on one side fails that guard until the table is updated. **Switch on these exhaustively, with no `default`/wildcard arm**: the hierarchy is sealed, so a catch-all raises `unreachable_switch_default` (or `unreachable_switch_case` for a `_` wildcard) and `flutter analyze` fails on warnings. Narrow with `errors.cast<ClientUserError>()` first — the result binds `List<OctopusServerError>`, which is not sealed. An unknown wire `type` folds into `ClientUserOtherError`, and a new leaf only ever arrives by upgrading this package — as a source-breaking change documented here and in `MIGRATING.md`.
  - **iOS: a refused token does not always surface, and the bridge cannot fix that.** When the token exchange fails while **nothing is connected yet** — the ordinary first login — the native `SSOConnectionRepository.connect()` falls back to `connectAsGuest()` and returns normally, so this bridge receives no error and `connectUser` returns `OctopusSuccess` while the user browses anonymously. The refusal *does* reach you when a connection already existed (reconnecting after a previous failure, for instance), because that path rethrows. The same `connect()` also opens with `guard !isConnecting else { return }`, so a concurrent guest connection can make the call return without ever requesting a token — a narrow window, since the caller first waits up to 3 s for that connection to end and throws if it does not. Android has no such fallback and reports every refusal. Consequence: on iOS an `OctopusSuccess` means "the SDK is usable", not "your SSO user is authenticated" — confirm that with the connection state, which does tell the two apart. Both are streams that emit independently of the `Future`, so subscribe rather than sample: `OctopusSDK.isUserConnected` emits `false` under the guest fallback, and `OctopusSDK.connectionState` emits `OctopusConnected(isGuest: true)`. What is actionable is the cause — sign a valid token, and answer the provider promptly.
  - **A token request that is never answered no longer parks forever.** With the outcome now awaited, a persistent `tokenProvider` that never replies would have left the returned `Future` pending indefinitely. Both bridges bound the wait at 60 s and fall back to an empty token, which Android reports as `ClientUserMissingTokenError`; on iOS the empty token still goes through the backend exchange, so it can come back as a connection-level failure instead — or, on a first connect, not come back as a failure at all (see the guest fallback above). The registered `tokenProvider` **survives a failed connect**, whatever the failure: both native SDKs assign their own reference to it before attempting the connection and clear it only on logout, and they re-invoke it on every later refresh (`refreshEntitlements()`) — so a Dart-side drop would make the next round-trip answer an empty token, permanently. It is released by `disconnectUser()`.
- **The four embedded widgets now reserve the Android bottom inset by default.** `OctopusHomeScreen`, `OctopusHomeContent`, `OctopusPostDetailsScreen` and `OctopusGroupDetailsScreen` — and `OctopusSDK.embeddedView` beneath them — resolve `bottomSafeAreaInset` from the ambient `MediaQuery` on Android when it is left at its `0` default. Mounted full-screen on edge-to-edge Android (API 35+), the SDK's floating "Write a post" button previously sat behind the system navigation bar unless the host computed and passed the inset itself; only the `showOctopusHomeScreen` / `openNotification` helpers did that (added in 1.12.3). A full-screen mount now clears the navigation bar on all six entry points, with no host configuration.
  - **`0` means "resolve it from the mount point", not "reserve nothing".** That was already its effective meaning on the wire: the Dart layer drops the key when the resolved value is `0`, so `0` and "not provided" were indistinguishable (the Android bridge additionally gates on `> 0`; the iOS bridge gates on the key being present at all). Nothing changes for a value the host passes above `0`. To reserve nothing, wrap the widget in an ancestor that *consumes* the bottom padding: `MediaQuery.removePadding(context: context, removeBottom: true, child: OctopusHomeScreen(...))`.
  - **No API change**: no signature, type or default was touched, and hosts already passing an explicit value above `0` keep their exact behaviour. The case that changes is an Android host passing `0` — or any value ≤ 0 — to mean "reserve nothing": it now resolves like the default, and should consume the padding as shown above instead.
  - **On these four widgets, iOS deliberately does not resolve, and its behaviour is unchanged.** There is nothing to fix there: the embedded view already sits inside the safe area, so the pill was never occluded. And resolving would actively cost height — since the iOS bridge reads this value as a *total* and subtracts the safe area the view occupies (see the entry below), an inferred 34 pt over a 34 pt inset yields `max(max(0, 34 − 34), 0.01)` = 0.01 pt, where an absent key yields the bridge's historical additive 10 pt. Inferring a preference the host never expressed must not override a native default that is already correct. Note this scopes to the widgets: the `showOctopusHomeScreen` / `openNotification` helpers have inferred an inset on **both** platforms since 1.12.3, and this release does not change that.
  - **Hosts whose ancestors consume the `MediaQuery` padding are unaffected** — a `SafeArea`, an explicit `MediaQuery.removePadding`, or a `Scaffold` `bottomNavigationBar` / `persistentFooterButtons` **without** `extendBody: true`: the value resolves to `0`, the key stays off the wire, and each platform keeps its own native default.
  - **A `Scaffold` with `extendBody: true` now reserves its bottom bar — which is the intent of the parameter.** Under `extendBody`, `Scaffold` re-injects `max(padding.bottom, bottomWidgetsHeight)` into `padding` for its body, so the resolved value is the bar's height. The embedded view runs *behind* the bar in that shape, so the pill previously sat behind it unless the host passed the height itself. It is still a change: such hosts now reserve the bar height where they reserved nothing before.
  - **Known Android case that now over-reserves.** Padding the layout is not the same as consuming the padding: a plain `Padding`, a `Column` above a fixed footer, or a `Stack` bottom overlay leaves the ambient `MediaQuery` untouched. A host of that shape — e.g. `Scaffold(body: Column(children: [Expanded(child: OctopusHomeScreen()), myFooter]))` — now reserves the navigation-bar inset *inside* the embedded view on top of its own gap: the SDK's default content padding is replaced by that inset (roughly 24 dp with gesture navigation, 48 dp with 3-button). Pass the total you want, or consume the padding as shown above.
  - The resolution reads `MediaQuery.padding` — what is *left* to reserve once ancestors consumed their share — because it is also the only field carrying a `bottomNavigationBar`'s height under `extendBody: true` (`viewPadding` is zeroed there). It sits in an **unconditional** `Builder`: a wrapper that came and went between rebuilds would reparent the embedded platform view, which disposes and recreates the native view and restarts the SDK on its main feed.
  - **Known limitation** (Android): a widget first built while a keyboard is up resolves `0` and keeps it, because the engine folds the bottom inset into `viewInsets` and creation params are read once. This holds for any host, a `Scaffold` body included: `resizeToAvoidBottomInset` zeroes `viewInsets` for the body, but `MediaQueryData.removeViewInsets` only zeroes `viewInsets` and lowers `viewPadding` — it never writes `padding`, so the `padding.bottom` the engine already folded to 0 stays 0. It is not decidable at that moment either: "an ancestor consumed the padding" and "the keyboard folded it away" look identical, so resolving from `viewPadding` instead would break the opt-out above. A host that may mount the SDK with the keyboard already up should pass the inset explicitly. This is a missed improvement rather than a regression — these widgets resolved nothing at all before, so such a mount behaves exactly as it did.
- **iOS: `bottomSafeAreaInset` no longer double-counts the system safe area.** The parameter is documented as a *total* bottom padding, and that is how Android behaves — its bridge consumes the system-bar insets before mounting the native view, so the host's value is the only bottom padding applied. iOS did not: the bridge forwarded the value untouched to the native `OctopusHomeScreen(bottomSafeAreaInset:)`, which applies it through SwiftUI's `.safeAreaInset(edge: .bottom)` — additively, **on top of** the safe area the embedded view already sat in. The same Dart value therefore reserved roughly twice the intended band on iOS. The iOS bridge now subtracts the safe area the embedded view sits in before handing the value to the native SDK. The native iOS SDK's own additive contract is unchanged; only the Flutter bridge is affected.
  - **What each platform reserves**, for a requested value `R` and `S` = the system safe area *the embedded view itself sits in* (not the device's — `S` is 0 for the common case of a `Scaffold` body above a bottom bar, and 34 pt on a notched iPhone only when the view runs to the bottom of the screen): Android `R`, iOS `max(R, S)`. The two agree whenever `R >= S` — the intended usage, since `R` is meant to cover the host's bottom chrome, which itself sits above the system inset. Below `S`, iOS still never reserves less than the safe area it already occupies. On **iOS 14** the native SDK ignores the value entirely (its inset modifier requires iOS 15+), so nothing extra is reserved there.
  - **Fixes a regression shipped in 1.12.3**: `showOctopusHomeScreen` / `openNotification` auto-reserve the launching view's raw bottom safe area, and 1.12.3 claimed iOS was unaffected because of the native 10 pt floor. It was not — the helper sends the device inset (34 pt on a notched iPhone), which overrides that floor and then gets added to the safe area again. Measured on iPhone 16 / iOS 18.6 *before* this fix: 34 pt sent, 34 pt of system inset, both applied. These two helpers now reserve the intended amount on iOS.
  - **Hosts that never passed the parameter are unaffected.** Normalization applies only to a value the host explicitly sent; with none, the bridge keeps its historical 10 pt *added on top of* the system safe area, so existing layouts do not shift. Note that Dart omits the key when the value is `0`, so `0` and "not provided" are the same thing on the wire.
  - **Rendering change to be aware of.** iOS hosts that *did* pass a value and worked around the old behaviour by sending only their bar's height (instead of the documented height + safe-area inset) will see the reserved band change from `H + S` to `max(H, S)`. They should now send the total padding they want — the same value they already send on Android.
  - The normalized value is recomputed whenever the embedded view's geometry changes, instead of being captured once at mount before the view had reached its final position. To make that safe, a host-provided inset is emitted with a 0.01 pt floor: the native SDK gates its inset on `bottomSafeAreaInset > 0`, and crossing that boundary would rebuild the displayed screen and discard its state, including text and image already entered in the create-post editor. The floor keeps the gate on a single branch and renders nothing.
  - **Verified on iPhone 16 / iOS 18.6** by logging the container's resolved safe area: a full-screen route, a `fullscreenDialog` push and a `showModalBottomSheet` all hold the correct value throughout their slide-up, and a portrait→landscape→portrait round-trip settles correctly (34 pt / 21 pt / 34 pt). One transient remains: on the *first* frame of the landscape→portrait restore, the container still reports its stale landscape geometry (bottom safe area 0) while the window already reports 34 pt, so that single frame over-reserves before the next layout corrects it — roughly 120 ms, mid-rotation. It is left uncorrected on purpose: every "is the geometry settled yet" heuristic tried here risked freezing a wrong value permanently, which is far worse than one frame. iPad multitasking was not exercised.
  - **Known divergence with a hardware keyboard.** The native SDK compares the reported keyboard height against the same value it uses as a reserved height, so normalizing the value also moves that threshold. The outcome changes for any reported keyboard height in `(R - S, R]` and is identical everywhere else, so a full-height software keyboard is never affected. The reachable case is a hardware keyboard (iPad, or a Bluetooth keyboard on iPhone), which reports only the accessory bar: a host passing e.g. `R = 70` over `S = 20` with 55 pt reported previously kept its band and now drops it, letting host bottom chrome overlap the composer while typing. One scalar cannot satisfy both meanings from the bridge side; a proper fix needs the native SDK to take the total and the threshold separately.
  - Also fixes a pre-existing memory leak on iOS: the embedded view's login callback was a bound method, forming a container → hosting controller → root view → container retain cycle that leaked the whole SwiftUI tree and the SDK's managers on every mount.

### Example App
- **The published example app compiles again.** From 1.12.0 to 1.12.3, the packaging step stripped `example/lib/debug/` wholesale, but two files under it are part of the running sample — the Debug tab and the recorder `main.dart` starts at launch. Their imports survived the strip, so the example shipped on pub.dev and on the public repository could not be built at all. The stripped boundary is now `example/lib/debug/internal/`, which holds only the Settings debug-console sheet; the Debug tab and its recorder ship. Nothing changes for the published SDK itself — this was a packaging defect, not a code one.
- **A key pasted into the Config screen is no longer stored, and no longer auto-starts the app.** The sample persists its config and auto-starts it on the next launch, and it reaches the **production** backend whenever the build injects no `OCTOPUS_API_HOST` (the published SDK exposes no host setter). Pasting a key into `Custom…` therefore used to write it verbatim to plaintext on-device preferences and re-enter a client-facing backend with it on every subsequent launch, without the Config screen — or its production banner — ever being shown again. No API key value is written to storage now (an injected named key was already stored by id only), a config that resolves to no key lands on the Config screen instead of auto-starting, and a key left behind by an older build is stripped from storage on first load. Every other choice — key slot, user id, theme — is still restored, and builds that inject a key via `--dart-define` (including the QA launcher) keep auto-starting exactly as before. Sample-only; the published package is unaffected.

### Documentation
- **What this package's version number means, written down.** `MAJOR.MINOR` is
  locked to the `MAJOR.MINOR` of the native SDKs inside it, on both platforms:
  `^1.13.0` means native 1.13 on Android *and* iOS. `PATCH` is each stream's own
  counter, so Android 1.13.1 with iOS 1.13.2 under package 1.13.0 is normal —
  the two badges in `README.md` give the exact pins. The practical consequence
  for you: a future release may bump this package's **minor** with no change to
  the Dart API at all, because the natives moved a minor. Nothing changes in
  1.13.0 itself; this only states the rule the repo already followed.

## 1.12.3

### Fixed
- **`showOctopusHomeScreen` / `openNotification` now reserve the Android system navigation-bar inset by default.** On edge-to-edge Android (API 35+), the full-screen helper previously let the SDK's floating "Write a post" button sit behind the system navigation bar: the route uses `SafeArea(bottom: false)` and the embedded native view consumes the system-bar insets, so nothing reserved the bottom. The helper now auto-reserves the launching view's bottom safe area. A new optional `double? bottomSafeAreaInset` on both methods overrides it — `null` (default) = auto, `0` = the previous edge-to-edge look, a larger value = clear extra host bottom chrome. Additive, no breaking change; iOS is unaffected (native 10pt floor). The `OctopusHomeScreen` widget's own contract is unchanged — hosts that mount it directly still pass `bottomSafeAreaInset` themselves (as the sample scenarios do).

## 1.12.2

### New Features
- **Sign prefilled image shares on the create-post editor**: new optional `bridgeShareTokenProvider` on `CreatePostScreenInfo` — `OctopusSDK().showOctopusCreatePostScreen(info: CreatePostScreenInfo(prefilledPost: ..., bridgeShareTokenProvider: (fingerprint) async => jwt))`. When a community is configured to forbid member pictures, the server rejects a prefilled (Bridge / Share-in-game) post that carries an image unless it's signed. At publish time the SDK computes a SHA-256 `fingerprint` of the final content and invokes this provider; your backend returns a JWT (HS256, the same shared secret as your SSO tokens) carrying that value in its `bridge_fingerprint` claim — or `null` to send the post unsigned. Reuses the same native→Dart token round-trip as `fetchOrCreateClientObjectRelatedPost`; the provider is scoped to the editor session (opening another editor supersedes it). Wired on **both platforms** — Android maps it to the native `CreatePostScreenInfo.bridgeShareTokenProvider`, iOS to `OctopusPrefilledPost.sign` (native iOS pods bumped to `1.12.4`, where the signer landed). Additive and non-breaking; communities that allow member pictures don't need it. **Platform note:** the iOS native signer returns a non-optional token, so when the provider replies `null` the iOS editor surfaces a signing error and stays open (a pictures-off community rejects the unsigned image anyway), whereas Android sends the attempt unsigned and lets the server reject it — the outcome is identical for the intended use case (return a real JWT). Register the provider only for communities that actually require signing.

### Deprecations
- **`connectUser` now accepts a `tokenProvider`** — connect with a `tokenProvider` callback the SDK invokes whenever it needs a freshly-signed JWT (initial connect **and** every refresh, e.g. `refreshEntitlements()`). This matches the single native `connectUser(user, tokenProvider:)` contract on Android and iOS.
  - New shape: `OctopusSDK().connectUser({required userId, Future<String> Function()? tokenProvider, nickname, bio, picture, @Deprecated token})`. Provide **exactly one** of `tokenProvider` or `token` — passing both (or neither) throws `ArgumentError` in every build. See [MIGRATING.md](MIGRATING.md) for the full before/after.
  - The `token` parameter (a pre-minted static JWT) is **deprecated**: a static token can't be re-minted when the SDK re-authenticates the user, so it fails once the JWT expires. Migrate by wrapping it in a provider — `tokenProvider: () async => token`.
  - **`connectUserWithTokenProvider(...)` is deprecated** — call `connectUser(tokenProvider:)` instead (identical behavior).
  - Backward compatible: existing `connectUser(token:)` and `connectUserWithTokenProvider(...)` calls keep working (with a deprecation hint). The native bridge is unchanged. The deprecated surface will be removed in a future major version.

### Changed
- **`navBarLeadingAction` on `OctopusHomeScreen` now works on Android too** (was iOS-only). The optional `OctopusNavBarLeadingAction? navBarLeadingAction` parameter (values `close` / `back`) now drives the root leading nav-bar icon on Android by mapping to the native `OctopusHomeScreen(leadingNavigationIcon:)` (wrapped native Android SDK `1.12.1+`, `NavigationIconType.Close` / `.Back`). When set, the requested icon overrides the root leading icon regardless of `showBackButton`, and tapping it fires the existing `onBack` callback — the same contract as iOS. When `null` (default), Android keeps its existing behaviour: a back arrow gated by `showBackButton`. This lets a Flutter-hosted modal show a Close (X) affordance on both platforms with a single parameter. No API change — `navBarLeadingAction` was already public; it is only newly functional on Android. (`OctopusHomeContent` / the `showNavBar: false` variant renders no top app bar, so it stays a no-op there, consistent with `titleCentered`.)
- **iOS: `connectionState` / `isUserConnected` now distinguish guest sessions.** `OctopusConnected.isGuest` is now populated on iOS from `OctopusProfile.isGuest` (native iOS SDK `1.12.6+`), so `OctopusSDK.isUserConnected` is `true` only for a fully authenticated (non-guest) user on iOS too — previously iOS reported every connection as non-guest. Behaviour now matches Android. No API change; gate community features (e.g. a "join the community" button) on `isUserConnected` rather than on "a profile exists".

### Bug Fixes
- **Android: `syncFollowGroups` now persists the requested follow state.** The wrapped native Android SDK had a bug where `syncFollowGroups` always sent `followed=false`, so following a group programmatically never persisted as followed. Fixed by bumping the native Android dependency to `1.12.1`. No Dart change — the Dart→Kotlin bridge already forwarded `followed` faithfully; the fix is entirely in the native SDK.
- **Android: spurious "Invalid token" on devices whose clock runs ahead.** The wrapped native Android SDK rejected valid bridge tokens as `Invalid token` when the device clock was ahead of the server; the `1.12.1` bump resolves it.
- **iOS: the embedded `OctopusHomeScreen` feed could not be scrolled inside a `showModalBottomSheet`.** When the SDK was hosted in a Flutter modal bottom sheet on iOS, the sheet's drag-to-dismiss recognizer claimed every vertical drag, so the native feed (and post detail) stayed unscrollable. The embedded `UiKitView` now attaches an `EagerGestureRecognizer` (matching Android), so the SDK's internal scroll wins body drags and scrolling works inside the sheet. As a result the gesture behaviour is now identical on both platforms: a drag on the body scrolls the feed rather than dismissing the sheet — dismiss via the Material drag handle, an explicit close button, or `navBarLeadingAction: close`. (flutter/flutter#26425 and flutter/flutter#66270.)
- **Android: embedded SDK sub-screens now respect the host's `bottomSafeAreaInset`.** The inset was applied only to the main feed, so when the host deep-linked into (or navigated to) a sub-screen — post/comment detail, create-post — its pinned bottom bar (e.g. the comment composer and its legal disclaimer) rendered inside the system gesture-navigation area and was clipped. Because the embedded platform view consumes the system-bar insets, the host-supplied `bottomSafeAreaInset` is now propagated to those sub-screens too, so their bottom content clears the gesture area.
- **Android: the standalone create-post editor (`showOctopusCreatePostScreen`) now actually closes.** The editor Activity hosted the native screen as the sole/start destination of its own `NavHost`, so the wrapped SDK's internal dismissal (`popBackStack()` — used both when the user taps the X and after a successful publish) had nothing to pop and silently no-opped: the screen stayed open, `showOctopusCreatePostScreen`'s returned `Future` never completed, and only a raw system back gesture happened to close it (by falling through to the OS default, since Navigation-Compose stops intercepting back at the root). A lightweight root destination now sits below the editor so the dismissal has something real to pop to; reaching it back finishes the Activity as originally intended. No API change. iOS was never affected (its dismissal is a `SwiftUI` environment action, not back-stack-dependent).
- **Android: the native back chevron now works at bridge-mode start destinations of `OctopusHomeScreen` / `OctopusPostDetailsScreen` / `OctopusGroupDetailsScreen`** (`OctopusInitialScreen.post` / `.group` / `.createPost`). Same root cause and fix shape as the create-post editor above: those screens dismiss themselves via the wrapped SDK's internal `navigateUp()`, which no-ops when they're the sole/start destination — so tapping the chevron did nothing even though the host's `onBack` was correctly wired, and only system back worked. A lightweight root destination now sits below the bridge-mode target; reaching it back invokes the host's `onBack` as originally documented. No API change.

### Example App
- **Refresh Entitlements scenario no longer shows a stale result.** The scenario read `app.profile?.entitlements` synchronously, in the same run-loop turn `refreshEntitlements()` resolved — but the refreshed profile arrives through an independent reactive channel (native DB-observation → the `profile` stream), so the synchronous read could race ahead of it and print the pre-refresh value even though the request actually succeeded. The Result text now points at the reactively-updated "Live state" card instead of taking its own snapshot. Sample-only; not an SDK bug.

### Dependencies
- **Android native Octopus SDK `1.12.0` → `1.12.1`** (`com.octopuscommunity:octopus-sdk` and `octopus-sdk-ui`). No public API change.
- **iOS native Octopus pods `1.12.2` → `1.12.6`** (`OctopusCommunity` / `OctopusCommunityUI` in the podspec, and the SPM pin in `Package.swift` — kept in lockstep). Brings the iOS bridge-share signer (`OctopusPrefilledPost.sign`, from `1.12.3`) that the new `bridgeShareTokenProvider` wires to, the public `OctopusProfile.isGuest` flag (`1.12.6`) behind the guest-session change above, plus backend-driven parity fixes the embedded UI inherits automatically (Android already had them from its `1.12.1` pin): per-field profile lock and per-content-type gating (both from iOS `1.12.3`), and an Xcode 27 / Swift 6.4 build fix (`1.12.4`). No public Dart API change from the bump itself.

### Build
- **iOS: Swift Package Manager (SPM) support — dual with CocoaPods.** The plugin now ships an `ios/octopus_sdk_flutter/Package.swift` alongside the existing podspec. Apps that use Flutter's Swift Package Manager integration (the default since Flutter 3.44) resolve the plugin — and the native `Octopus` / `OctopusUI` SDK from [`octopus-sdk-swift`](https://github.com/Octopus-Community/octopus-sdk-swift) — via SPM, while CocoaPods-based apps keep working unchanged. On the SPM path the native gRPC dependency resolves transitively via the Swift package, without the CocoaPods modular-headers handling the pod path needs for gRPC (`use_modular_headers!` / `pod 'gRPC-Swift', :modular_headers => true`). No public Dart/API change; minimum iOS is still 14.0. Both paths are exercised in CI.

## 1.12.1

### Documentation
- **README rewritten from scratch** — pub.dev landing page rebuilt around what a Flutter dev needs in the first 5 minutes: requirements table up top, three-step quick start (init → embed → connect), separate sections for theming, presentation modes, the Bridge pattern, push wiring, and a scannable streams table. Catalogs the rest of the public surface with depth-links to [doc.octopuscommunity.com](https://doc.octopuscommunity.com). All snippets verified against the public API.

No code changes — `octopus_sdk_flutter` 1.12.1 ships the exact same Dart, Android, and iOS surface as 1.12.0.

## 1.12.0

### New Features
- **Custom API server endpoint**: new `ApiServer(host, port)` model and an optional `apiServer` parameter on `initialize(...)` and `initializeOctopusAuth(...)`. Route the SDK's gRPC traffic to a custom host/port over TLS. Omitting `apiServer` (the default) keeps the Octopus default endpoint. The host is validated at construction (`ApiServerValidationError`); scheme, port, path, and whitespace are rejected, bracketed/unbracketed IPv6 literals are accepted.
- **Multi-community switching**: `OctopusSDK().switchCommunity(apiKey, appManagedFields, apiServer)` (SSO) and `switchCommunityOctopusAuth(apiKey, deepLink, apiServer)` (Octopus Auth) disconnect the current user, clear cached data, and reinitialize against another community at runtime. Give embedded UI a `key: ValueKey(apiKey)` so the native view is rebuilt for the new community.
- **SDK lifecycle**: `OctopusSDK().reset()` disconnects the user and returns the SDK to a clean state while staying initialized; `OctopusSDK().stop()` tears the SDK down to an uninitialized state.
- **Initialization state**: `OctopusSDK.isInitialised` synchronous getter and `OctopusSDK.isInitialisedFlow` `Stream<bool>` (replays the current value to late subscribers and collapses consecutive duplicates). On iOS — which has no native `reset`/`stop`/`isInitialised` — these are ported on top of the available native surface; `reset()` disconnects the user only (no public cache-clearing API on iOS).
- **`setGroupAccessDeniedCallback(...)`**: register a callback invoked with the `groupId` when the connected user taps a group they cannot access (locked group / follow button / detail CTA). The SDK never navigates on the user's behalf — your app decides (upsell, paywall, …). Returns a `VoidCallback` to unregister (call it in `dispose`); registering again replaces the previous callback (last-write-wins).
- **`refreshEntitlements()`**: new `OctopusSDK().refreshEntitlements()` returning `Future<OctopusResult<void, RefreshEntitlementsError>>`. Refreshes the connected user's community entitlements from the backend (SSO mode only). Typed errors: `RefreshEntitlementsNoClientTokenProviderError`, `RefreshEntitlementsUserNotConnectedError`, `RefreshEntitlementsNoNetworkError`, `RefreshEntitlementsUserBannedError` (backend message, displayable), `RefreshEntitlementsServerError`.
- **Community groups (`groups`)**: new `OctopusSDK.groups` `Stream<List<OctopusGroup>>` emitting the community's groups (content categories) and re-emitting on any change (follow/unfollow, admin updates), with the latest list replayed to late subscribers and consecutive duplicates collapsed. `OctopusGroup` is a lean model exposing `id`, `name`, `isFollowed`, `canChangeFollowStatus`, `canAccess` (false = visible-but-locked; route through `setGroupAccessDeniedCallback`), and `canCreateChildren`. Mirrors the native `OctopusSDK.groups` public surface.
- **Connected user profile (`profile`)**: new `OctopusSDK.profile` `Stream<OctopusProfile?>` emitting the connected user's `OctopusProfile` (or `null` when not connected). Emits on every profile change — including after `refreshEntitlements()` — and replays the latest value to late subscribers. `OctopusProfile` exposes the user's held `entitlements` (`Set<String>`, opaque tokens defined by the host app; display-only). Mirrors the native `OctopusSDK.profile`.
- **`setReaction(...)`**: new `OctopusSDK().setReaction(OctopusReactionKind? reaction, String postId)` returning `Future<OctopusResult<void, SetReactionError>>`. Sets (or removes, with `null`) the connected user's reaction on **any** post — bridge posts and community posts. `OctopusReactionKind` is a sealed class (not an enum) with the const singletons `OctopusReactionKind.heart`, `.joy`, `.mouthOpen`, `.clap`, `.cry`, `.rage`, and an `OctopusUnknownReaction(serverValue)` forward-compat fallback — so a reaction added by a newer backend decodes without an SDK release. Business failures are typed `SetReactionError`s (`SetReactionUnknownReactionError`, `SetReactionPostNotFoundError`, `SetReactionReactionError`) carried by `OctopusInvalidArguments`; transport/auth failures surface through the orthogonal `OctopusConnectionFailure` branch. **Platform note**: on iOS, removing a reaction with `null` when none is set currently reports a `SetReactionReactionError` rather than the Android silent no-op.
- **Typed results (`OctopusResult`)**: new `OctopusResult<D, E>` sealed hierarchy mirroring the native SDK — `OctopusSuccess`, connection failures (`OctopusNoNetwork`, `OctopusContentUnavailable`, `OctopusUserNotAuthenticated`, `OctopusPermissionDenied`, `OctopusStatusError`), and `OctopusInvalidArguments<E>` carrying typed `OctopusServerError`s — with helpers (`mapSuccess`, `mapErrors`, `onSuccess`, `onFailure`, `onError`, `getOrNull`, `getOrElse`). Use the helpers, or pattern-match (exhaustive switches must annotate `OctopusInvalidArguments<OctopusServerError>` — see [MIGRATING.md](MIGRATING.md#to-1120-from-111x)).
- **Bridge create-post models**: new immutable, value-equal input models for the upcoming Bridge create-post APIs (programmatic client-object posts and the prefilled post editor). `OctopusPrefilledPost({String? text, Uint8List? image, String? topicId, OctopusPostCTA? cta})` validates its payload eagerly and throws a sealed `OctopusPrefilledPostValidationError` (`...ContentEmptyError`, `...TextTooShortError`, `...TextTooLongError`, `...CtaLabelEmptyError`, `...CtaUrlEmptyError`); empty text/image and blank `topicId` are normalised to `null`, and text length is bounded to 10–5000. Image bytes are passed as `Uint8List` (the host materialises them — the SDK does not fetch remote URLs) and are dimension-checked later in the editor, matching the native Android behaviour. `OctopusPostCTA({Uri url, String label})` is the host-supplied call-to-action (invisible in the editor, attached to the published post). `CreatePostScreenInfo({OctopusPrefilledPost? prefilledPost})` describes the create-post entry point. `ClientPost({String objectId, String text, OctopusClientPostAttachment? attachment, String? catchPhrase, String? viewObjectButtonText, String? groupId})` describes a post linked to one of your app's objects; its image `attachment` is a sealed `OctopusClientPostAttachment` (`OctopusLocalImageAttachment(bytes)` / `OctopusRemoteImageAttachment(url)`). All four mirror the lean intersection of the native `ClientPost` / `OctopusPrefilledPost` / `OctopusPostCTA` / `CreatePostScreenInfo` public surfaces; the consuming methods and editor widget land in a later release.
- **Bridge post API (`fetchOrCreateClientObjectRelatedPost`)**: new `OctopusSDK().fetchOrCreateClientObjectRelatedPost(ClientPost clientPost, {Future<String?> Function(String fingerprint)? tokenProvider})` returning `Future<OctopusResult<OctopusPost, ClientPostError>>`. Fetches the Octopus post linked to one of your app's objects, creating it from `clientPost` if it doesn't exist yet (links community discussion to your content). The optional `tokenProvider` is invoked only when a new post must be created and your community requires a bridge signature: it receives the SHA-256 content fingerprint and returns a JWT signed by your backend (or `null`). `OctopusPost` is the lean read view (`id`, `reactions` as `OctopusReactionCount`s, `commentCount`, `viewCount`, `userReactionKind`). Content errors are typed `ClientPostError`s (`ClientPostTextMissingError`, `ClientPostTextTooLongError`, `ClientPostFileEmptyError`, `ClientPostFileTooLargeError`, `ClientPostFileBadFormatError`, `ClientPostFileUploadError`, `ClientPostFileDownloadError`, `ClientPostMissingObjectIdError`, `ClientPostMissingCtaError`, `ClientPostUnavailableError`, `ClientPostNotFoundError`, `ClientPostAlreadyExistsError`, `ClientPostInvalidGroupIdError`, `ClientPostInvalidAuthorError`, `ClientPostTokenInvalidError`, `ClientPostTokenExpiredError`, `ClientPostOtherError`) carried by `OctopusInvalidArguments`; transport/auth failures surface through the orthogonal `OctopusConnectionFailure` branch. **Platform note**: on iOS the native SDK does not expose the specific validation error kind publicly, so content errors there surface as `ClientPostOtherError`; Android produces the fine-grained subtypes.
- **`setNavigateToClientObjectCallback(...)`**: register a callback invoked with the `objectId` when the user taps the "view object" button on a bridge post (a post created via `fetchOrCreateClientObjectRelatedPost` with a `viewObjectButtonText`). The SDK never navigates on the user's behalf — your app opens its own article/product screen for that object. Returns a `VoidCallback` to unregister (call it in `dispose`); registering again replaces the previous callback (last-write-wins). Mirrors the native per-screen `onNavigateToClientObject` (Android) / global `displayClientObjectCallback` (iOS).
- **Bridge post observation (`getClientObjectRelatedPostFlow`)**: new `OctopusSDK.getClientObjectRelatedPostFlow(String clientObjectId)` returning `Stream<OctopusPost?>` — observe the Octopus post linked to one of your app's objects (`null` until it exists). The current value is replayed to a new subscriber, then the stream re-emits whenever the post changes — including right after `fetchOrCreateClientObjectRelatedPost` creates it, and on internal updates (reactions, comment count). Each subscription drives its own native observation, so observing the same `clientObjectId` from two places is safe; cancel the subscription to stop observing. Mirrors the native `getClientObjectRelatedPostFlow` (Android) / `getClientObjectRelatedPostPublisher` (iOS).
- **Create-post editor (`showOctopusCreatePostScreen`)**: new `OctopusSDK().showOctopusCreatePostScreen({CreatePostScreenInfo? info, OctopusTheme? theme})` method opens the native Octopus post editor (Bridge Share) presentation-style — a dedicated Activity on Android, a full-screen modal on iOS — so the editor's chrome (close button, post button, group picker) is owned by the SDK on both platforms with no inline-mount limitation. Pass a `CreatePostScreenInfo(prefilledPost: OctopusPrefilledPost(text, image, topicId, cta))` to preset the editor's text, image (raw `Uint8List` bytes — the SDK never fetches remote URLs), target group, and an invisible `OctopusPostCTA` attached to the published post; omit `info` to open an empty editor. Returns `Future<void>` that completes when the editor closes (publish or cancel). Login / profile-edit / view-object intents originating inside the editor are routed back to the host via the existing global events (`onNavigateToLogin`, `onModifyUser`, `setNavigateToClientObjectCallback`). Mirrors the native `OctopusCreatePostScreen` (Android) / `OctopusInitialScreen.createPost` on `OctopusHomeScreen` (iOS).
- **`bottomSafeAreaInset` on `OctopusHomeScreen`**: new optional `double bottomSafeAreaInset` parameter (default `0`) that pads the embedded view's bottom area so the floating "Write a post" button clears the host app's bottom chrome (Material `BottomNavigationBar`, custom shell, …). Plumbed end-to-end to native: Android `contentPadding`, iOS `bottomSafeAreaInset`. Pass `kBottomNavigationBarHeight + MediaQuery.viewPaddingOf(context).bottom` for a standard Material shell.
- **`titleCentered` on `OctopusHomeScreen`**: new optional `bool titleCentered` parameter (default `false`) that centers the title in the SDK's native top app bar. **Supported on both platforms** — Android maps it to the native `OctopusHomeScreen.titleCentered` composable param, iOS to `OctopusMainFeedTitle.Placement.center` (`.leading` when `false`) on the main feed. Not added to `OctopusHomeContent`: the native Android `OctopusHomeContent` renders no top app bar, so the flag would have no effect there.
- **`navigationMode` on `OctopusHomeScreen`** (iOS-only): new optional `OctopusNavigationMode navigationMode` parameter (default `OctopusNavigationMode.navigationStack`) selecting which navigation container the native iOS SDK uses internally. The Flutter wrapper's default deliberately differs from the native iOS default (`OctopusNavigationMode.automatic`, currently the legacy `NavigationView`): every Flutter route is by definition a UIKit-hosted reparented presentation, and the legacy `NavigationView` will silently drop sub-navigation pushes there (a post tap not opening its detail, a "Yes" confirmation on the unsaved-changes alert that leaves the New Post screen in place, …). `navigationStack` keeps them working (iOS 16+, with a `NavigationView` fallback below). Pass `OctopusNavigationMode.automatic` explicitly to opt back into the native iOS default. Maps to the native `OctopusHomeScreen(navigationMode:)` (wrapped iOS SDK 1.12.2+). **No-op on Android** — the bridge already drives the SDK through a Compose `NavHost` that keeps its back stack across modal hosting, so there is no equivalent setting. This is the supported fix for the modal/sheet sub-navigation limitation noted in earlier 1.12.0 development.
- **`navBarLeadingAction` on `OctopusHomeScreen`** (iOS-only): new optional `OctopusNavBarLeadingAction? navBarLeadingAction` parameter (default `null`, values `close` / `back`) that asks the native iOS SDK to render a host-driven leading nav-bar button (close icon or back chevron) on its **root** screen; tapping it fires the existing `onBack` callback. This is the native replacement for the `leadingWidget` / `trailingWidget` Flutter overlays on iOS — the iOS SDK only paints its own close button when presented natively (`.sheet` / `.fullScreenCover`), which never happens for a Flutter-hosted `UiKitView`, so before this a Flutter-hosted modal had no native dismiss affordance. The native button lives inside the SDK's own nav bar, so it never reparents the embedded `PlatformView` and is hidden automatically on deeper screens. Maps to the native `OctopusHomeScreen(navBarLeadingAction:)` (wrapped iOS SDK 1.12.2+). **No-op on Android** — the native Android `OctopusHomeScreen` already renders a leading back arrow on the root screen (controlled by `showBackButton`, also routed to `onBack`); pair `navBarLeadingAction` (iOS) with `showBackButton: true` (Android) for a native dismiss affordance on both platforms.
- **`formatOctopusCompactCount(int, {Locale? locale})`**: new top-level helper that formats post / reaction counts (`OctopusPost.commentCount`, `OctopusPost.viewCount`, `OctopusReactionCount.count`, or any host-side integer) in the same compact `K` / `M` / `B` style as the embedded community UI — `0`–`999` raw, then `1.2K` / `12K` / `999K` / `1.2M` / `1B` (band-floor, not round). The optional `locale` flips the decimal separator (`1,2K` for French / German / Spanish / …, `1.2K` for English and the default). Mirrors the native Android `Int.toCompactString(Locale)`; the iOS native helper renders the same shape with an English-only decimal point.
- **Screen entry points (`OctopusInitialScreen`)**: new sealed `OctopusInitialScreen` with four variants — `OctopusInitialScreen.mainFeed()` (default), `OctopusInitialScreen.post(PostScreenInfo(postId: ...))`, `OctopusInitialScreen.group(GroupScreenInfo(groupId: ...))`, and `OctopusInitialScreen.createPost(CreatePostScreenInfo)` — passed via the new optional `initialScreen:` parameter on `OctopusHomeScreen` and `OctopusHomeContent`. Bridge-mode entry points (`.post` / `.group`) open a single post or group feed with no main-feed back navigation. Also adds dedicated `OctopusPostDetailsScreen(postId:)` / `OctopusGroupDetailsScreen(groupId:)` widgets as ergonomic shorthands wrapping the same flow. **Precedence rule:** when a `notification` with a non-empty `linkPath` is supplied at the same mount, the deep link wins and `initialScreen` is ignored. **Platform note:** image bytes carried in `OctopusPrefilledPost.image` are dropped on the embedded `createPost` route on both platforms — use `showOctopusCreatePostScreen` for the image-share flow. **Back navigation note:** the SDK paints a back chevron at the bridge-mode start destination on both platforms (Android natively; iOS via the `showBackButton: true` → `navBarLeadingAction: .back` bridge wiring). To wire the tap, pass an `onBack:` callback to the wrapper (`OctopusPostDetailsScreen` / `OctopusGroupDetailsScreen` now forward `onBack` to the inner `OctopusHomeScreen`) that pops the host route or otherwise dismisses the screen. Hosts that don't pass `onBack` keep relying on the system back gesture / their own `AppBar` back button.

### Changed
- **BREAKING — `overrideCommunityAccess(bool)` now returns `Future<OctopusResult<void, OverrideCommunityAccessError>>`** (was `Future<void>`). It no longer throws on handled SDK failures; inspect the returned result instead. Fire-and-forget callers can ignore the result (`await octopus.overrideCommunityAccess(true);` still compiles). See [MIGRATING.md](MIGRATING.md#to-1120-from-111x). On iOS the native call surfaces all handled failures as `OctopusInvalidArguments([OverrideCommunityAccessUnknownError(...)])` (iOS has no typed error for this call).
- **`connectUserWithTokenProvider` is now persistent — `refreshEntitlements()` works**. The wrapper used to be a one-shot: it awaited the provider once at connect time and passed the resulting JWT string to the native SDK. The native SDK never received the closure, so `refreshEntitlements()` had no way to ask Dart for a fresh JWT and always returned `RefreshEntitlementsNoClientTokenProviderError`. The wrapper now stores the provider for the connection's lifetime; the native SDK re-invokes it on every refresh, exactly matching the Android (`OctopusSDK.connectUser(user, tokenProvider: suspend () -> String)`) and iOS (`octopus.connectUser(clientUser) { @Sendable in … }`) public contracts. Behavior change visible to existing callers: `connectUserWithTokenProvider` no longer discards the closure after the first invocation. The dartdoc never documented one-shot semantics — this is the documented behavior catching up to the documented intent. Cleared on `disconnectUser`.

### Bug Fixes
- **Android: embedded SDK feed now scrolls inside a `showModalBottomSheet` / any vertical-drag ancestor**: `OctopusSDK.embeddedView` configured the underlying `AndroidView` with an empty `gestureRecognizers` set — the Flutter default, which means the native view only receives pointer events no ancestor recognizer has claimed. A `showModalBottomSheet` ancestor installs a `VerticalDragGestureRecognizer` (drag-to-dismiss) and won the gesture arena on every vertical drag, so the SDK's native `LazyColumn` never saw the gesture and the feed was unscrollable inside the Sheet scenario. The Android branch now passes an `EagerGestureRecognizer`, so every pointer landing on the embedded view is dispatched straight to the native side — the feed scrolls, the sheet's drag-handle still dismisses the sheet (it lives outside the AndroidView bounds), and there is no behavioural change on iOS (`UiKitView` doesn't expose the same knob; UIKit's gesture recognizer delegation lets the inner `UIScrollView` win automatically — the documented platform asymmetry behind `flutter/flutter#26425` / `#66270`). The sample's Sheet scenario gains `showDragHandle: true` so drag-to-dismiss remains discoverable via the Material handle (rendered above the AndroidView), matching M3's recommended pattern for sheets with scrollable content.

- **Sub-navigation drop when `leadingWidget`/`trailingWidget` overlays are configured (the #63 report — root cause found and fixed)**: when a leading/trailing overlay was set on `OctopusHomeScreen`, the widget swapped its tree shape between `Stack(Positioned.fill(view), overlay)` (main feed) and the bare view (deeper screens). That reparenting disposed and recreated the native PlatformView on the very first sub-navigation: the tap registered (view count incremented, `screenDisplayed(postDetail)` fired) but the freshly-recreated view restarted on the main feed — the user never saw the detail screen. This is the mechanism behind the 1.12.0-dev "modal sub-navigation drop" report (#63): the 1.12.0-dev helper attached a default close-overlay (so it reproduced), while the later end-to-end validation exercised overlay-less shapes (so it could not reproduce). The tree shape is now stable — only the overlay children come and go — and post taps push detail in every route shape (modal / fullscreen / sheet), verified end-to-end on Android and iOS.

- **Android top app bar now tracks `themeMode`**: the bridge previously passed `Color.Unspecified` for the top app bar `containerColor` and let the native SDK fall back to `OctopusColorScheme.gray900` / `.background`. In the SDK's dark `OctopusColorScheme` those tokens are still dark, but the title-content fallback also resolved to `gray900` — producing dark-on-dark text that made the "Community" / "Post detail" titles invisible in dark mode (and, when `navBarPrimaryColor` was set, a brand-pink top app bar regardless of `themeMode`). `OctopusFlutterTheme.kt` now resolves the colour scheme first and passes the corresponding `background` as `containerColor`, plus an explicit foreground (`Color.White` in dark mode, default elsewhere) for title / nav-icon / action-icon. iOS is unaffected — its `UINavigationBar` already follows `traitCollection.userInterfaceStyle`.

- **iOS top app bar now shows a configured custom-theme logo over a text title**: when an `OctopusTheme` carrying a logo was supplied together with a `navBarTitle`, the iOS bridge always rendered the text title, so the brand logo never appeared (e.g. on the sample's Community tab). A configured logo now takes precedence over the text title — matching Android — and the main-feed title placement follows `titleCentered`. iOS only.

- **iOS now honours `showBackButton` on `OctopusHomeScreen` / `OctopusSDK.embeddedView`**: the iOS bridge previously read `navBarLeadingAction` but silently ignored `showBackButton`, so Flutter hosts that followed the documented cross-platform pattern (`showBackButton: true` with no explicit `navBarLeadingAction`) got a back chevron on Android and nothing on iOS — the SDK's `UINavigationBar` had no visible leading action. The bridge now backfills the missing leading action: when `showBackButton: true` is on the wire and no explicit `navBarLeadingAction` was provided, the iOS SDK renders a back chevron whose tap routes through the existing `backRequested` event → `OctopusHomeScreen.onBack`. An explicit `navBarLeadingAction` (`.close` / `.back`) still wins. Hosts that wired `showBackButton: true` thinking it was a no-op on iOS will now see a leading chevron in 1.12.0 — make sure `onBack` is wired (it is null-safe: a missing handler leaves the chevron rendered but inert).

- **`onBack` now forwarded by `OctopusPostDetailsScreen` / `OctopusGroupDetailsScreen` to the inner `OctopusHomeScreen`**: the two standalone bridge-mode wrappers added with the screen entry points didn't forward the `onBack` callback to the inner widget. Combined with the iOS `showBackButton` wiring above, this left the back chevron visible but inert on iOS for hosts using the wrapper widgets. Both wrappers now expose an optional `VoidCallback? onBack` parameter and forward it. Hosts that don't pass `onBack` keep the prior "host-owned back via system gesture / `AppBar`" behavior — additive, no breaking change.

### Known Issues
- **Modal-hosted sub-navigation drop — root cause identified and fixed in this release.** During 1.12.0 development, mounting `OctopusHomeScreen` inside a modal-style route was reported to silently drop the SDK's internal sub-navigation — taps on a post body incremented the view count but never pushed the post detail. The helpers were briefly `@Deprecated` over it, then later end-to-end validation could not reproduce the drop. The discrepancy is now explained: the drop required a `leadingWidget`/`trailingWidget` overlay to be configured (the 1.12.0-dev helper attached a default close overlay; the later validation exercised overlay-less shapes). See the Bug Fixes entry above for the mechanism and the fix; the route shapes themselves (`showModalBottomSheet`, `fullscreenDialog`, the helpers) were never at fault. Tracked internally; related native hardening tracked internally.
- **Host overlays don't reappear after a back-pop to the feed.** `leadingWidget`/`trailingWidget` are hidden while the SDK shows a deeper screen (they would collide with the SDK's own chrome). The native SDKs emit `screenDisplayed` on **forward** navigation only — no event fires when popping back to the main feed (verified on both platforms) — so the overlays cannot reappear until the widget remounts. **For a robust modal dismissal affordance on iOS, prefer the new native `navBarLeadingAction` over a `trailingWidget` close button**: it lives inside the SDK's own nav bar (no overlay gating, no `PlatformView` reparenting) and the SDK hides it automatically on deeper screens. The host-controllable nav-bar leading action on iOS (tracked internally) shipped in the wrapped iOS SDK 1.12.2 and is exposed here as `navBarLeadingAction`.

### Dependencies
- Android Octopus SDK: 1.11.0 → 1.12.0
- iOS Octopus SDK: 1.11.0 → 1.12.2 (1.12.1: gamification sheet now shown only while the Octopus screen is visible — relevant to the embedded `PlatformView`; 1.12.2: ships the `navigationMode` / `navBarLeadingAction` APIs wired below). The Android native SDK has no 1.12.1/1.12.2 release, so the wrapped versions intentionally diverge by patch (`Z`) per platform.

### Example App
- **Theme picker now drives the SDK content**: the sample's Light / Dark / System choice on the Config screen is now propagated to `OctopusTheme.themeMode` for every embedded SDK surface in the sample (Community tab and the Modal / Fullscreen / Sheet / Initial-screen / Not-seen-notifications scenarios). Previously only `MaterialApp.themeMode` flipped — the SDK kept observing the device, producing a visible mismatch (e.g. dark Flutter chrome with a light SDK feed). System mode still passes `null` so the SDK natively tracks the device. New `AppState.effectiveOctopusTheme()` is the single source of truth; the brand `OctopusTheme` from the Theme scenario no longer hardcodes `themeMode: light` — the Config choice wins.
- **Three distinct presentation-mode scenarios**: the sample demos the three non-embedded integration shapes side by side in the Scenarios tab — **Modal** (`MaterialPageRoute(fullscreenDialog: true)`, the `.fullScreenCover` equivalent: slide-up on iOS, native SDK close button via `navBarLeadingAction: close` + `navigationMode: navigationStack` so sub-navigation works in the modal), **Fullscreen** (standard `MaterialPageRoute` push, the `showOctopusHomeScreen` helper shape), and **Sheet** (`showModalBottomSheet` at 90% height, drag-to-dismiss, also `navigationMode: navigationStack`). The duplicate launcher cards on the Home tab were removed — the Home tab is now a pure read-only dashboard. All three scenarios forward the device's physical bottom inset (`MediaQueryData.fromView(View.of(context)).viewPadding.bottom`, immune to ancestor `SafeArea` consumption) as `bottomSafeAreaInset` so the SDK's floating "Write a post" pill clears the device gesture pill / home indicator.
- **Bundle id unified across platforms — `com.octopuscommunity.sdk.flutter.sample`**: the sample's iOS bundle (was `com.octopuscommunity.octopusSdkFlutterExample`) and Android `applicationId` + `namespace` + Kotlin package + `MainActivity.kt` location (was `com.octopuscommunity.octopus_sdk_flutter_example`) all migrate to the same dedicated Flutter-sample identifier — distinct from the native Swift / Android SDK samples (`com.octopuscommunity.sdk.sample`) so the three can coexist on a single device. iOS team migrated from `4KE44M8274` (useradgents, the team that originally bootstrapped the SDK) to `8W7579HZX7` (Octopus Community) so push provisioning lives on the same Apple Developer account as the native samples. (#116, #117, #118)
- **iOS push provisioning end-to-end**: new `example/ios/Runner/Runner.entitlements` declaring `aps-environment = development`, wired via `CODE_SIGN_ENTITLEMENTS` in the three Runner build configs. The dedicated bundle has a matching APNs Auth Key + AWS SNS platform applications on the Octopus backend, so a sandbox push from the BE routes end-to-end to the sample. (#116, #117)
- **Android notification icon — monochrome white silhouette**: new `@drawable/ic_stat_notification` (Octopus chat-bubble silhouette painted white on transparent) in the five canonical densities (24 / 36 / 48 / 72 / 96 px), referenced by `flutter_local_notifications`' `AndroidInitializationSettings` and by Firebase Messaging's `default_notification_icon` meta-data; `notification_color = #02569B` (Flutter Sky Blue) for the status-bar accent chip. Replaces the full-color `@mipmap/ic_launcher` that Android 5+ rendered as an opaque grey square. iOS uses the app icon for notifications by default; no separate asset needed. (#118, #119)
- **App icon redesign**: Octopus chat-bubble + a centred "Flutter" pill badge at the top (Chrome-Beta-style, Flutter Sky Blue `#02569B`) — distinguishes the Flutter sample from the native Swift / Android samples on the home screen. Generated for iOS (`Assets.xcassets`) + Android (legacy mipmap + adaptive icon foreground / background) by the new `flutter_launcher_icons: ^0.14.4` dev-dependency from `example/assets/icon/app_icon_flutter.png`. App display name set to `"Octopus SDK Sample - Flutter"` on both platforms. (#119)
- **`OCTOPUS_FLUTTER_PUSH_API_KEY` picker slot**: a new named API-key slot `flutterPush` ("Flutter push (dedicated bundle)") wired to the new bundle's push provisioning. Selectable from the Config screen's API-key picker, or as the default with `OCTOPUS_KEY_NAME=OCTOPUS_FLUTTER_PUSH_API_KEY`. The key is injected at build time via `--dart-define` and is never committed. (#119)

## 1.11.0

### New Features
- **Push notification**
- **`syncFollowGroups`**: batch follow/unfollow groups in one round-trip via `OctopusSDK().syncFollowGroups([...])`. Returns per-action `SyncFollowGroupResult` with a typed `SyncFollowGroupStatus` (with `unknownError` fallback for future native variants). RPC-level failures surface as `PlatformException` with codes `not_connected`, `no_network`, `server`, or `other`.
- **Typed Dart `OctopusEvent` / `Screen` classes for new 1.11 events**: `GroupFollowingChangedEvent`, `MainFeedScreen`, `GroupsScreen`, `GroupDetailScreen` (with `GroupDetailSource` enum: `bridge` / `community` / `unknown`).

### Bug Fixes
- **`ProfileField.picture` was silently dropped from `appManagedFields`**: the Dart side serialized it as `'AVATAR'`, but both native bridges only recognize `'PICTURE'` and silently dropped the rest. Customers who initialized with `appManagedFields: [..., ProfileField.picture]` had the field never reach the native SDK, so users could still edit their profile picture inside the Octopus UI. Wire format is now correct (`PICTURE`). Customers using `ProfileField.picture` should re-test their profile flows — pictures will now be blocked in the Octopus UI and routed through `onModifyUser('PICTURE')` as documented.

### Dependencies
- Android Octopus SDK: 1.9.0 → 1.11.0
- iOS Octopus SDK: 1.9.0 → 1.11.0

## 1.9.1

### Bug Fixes
- **Late subscriber replay**: `notSeenNotificationsCount` and `hasAccessToCommunity` streams now cache the latest native emission so that Dart listeners attached after `initialize()` don't miss the initial value
- **screenDisplayed event parsing**: Fixed `type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>'` crash when receiving `screenDisplayed` events

### Example App
- Load logo from bundled asset instead of hardcoded base64 string
- Enable custom logo display (`logoBase64`)
- Set `ProfileField.nickname` as app-managed field
- Remove hardcoded `navBarTitle` from `OctopusHomeScreen`

## 1.9.0

### New Features
- **Notification Badge Count**: `Stream<int> notSeenNotificationsCount` for reactive badge updates, `updateNotSeenNotificationsCount()` to force refresh
- **Community Access / A/B Testing**: `Stream<bool> hasAccessToCommunity` for reactive access state, `overrideCommunityAccess(bool)` to override cohort, `trackCommunityAccess(bool)` for analytics
- **URL Interception**: `onNavigateToUrl` callback on `OctopusHomeScreen` with `UrlOpeningStrategy` enum (`handledByApp` / `handledByOctopus`)
- **Locale Override**: `overrideDefaultLocale(Locale?)` to override the SDK UI language (e.g. `Locale('fr')`, `Locale('en', 'US')`, or `null` to reset)
- **Custom Analytics**: `trackCustomEvent(String name, Map<String, String> properties)` to send custom events to Octopus analytics
- **SDK Events**: `Stream<OctopusEvent> events` — typed event stream covering 20 event types (content creation/deletion, reactions, polls, gamification, screen navigation, clicks, profile changes, sessions). Use `OctopusSDK.events.listen(...)` with Dart pattern matching

### Breaking Changes

See [MIGRATING.md](MIGRATING.md#to-190) for details

- `appManagedFields` parameter changed from `List<String>?` to `List<ProfileField>?` — use `ProfileField.nickname`, `.picture`, `.bio` instead of raw strings
- Renamed `OctopusView` to `OctopusHomeScreen`
- Renamed `OctopusSdkFlutter` to `OctopusSDK`
- Renamed `initializeOctopusSDK()` to `initialize()`
- Renamed `showOctopusHome()` to `showOctopusHomeScreen()`
- Renamed `OctopusSdkFlutterPlugin` to `OctopusSDKFlutterPlugin` (internal)
- Renamed `OctopusSdkFlutterPlatform` to `OctopusSDKPlatform` (internal)
- Renamed `MethodChannelOctopusSdkFlutter` to `OctopusSDKMethodChannel` (internal)
- Renamed `OctopusComposeWidget` to `OctopusHomeScreen` (Android internal)
- Removed legacy `showNativeUI()` and `closeNativeUI()` methods

### Dependencies
- Android Octopus SDK updated to 1.9.0
- iOS Octopus SDK updated to 1.9.0

### Improvements
- Simplified callback mechanism: replaced dual callback registry with single event stream
- SDK now initializes automatically on app start (removed manual "Init" button in example)
- Added user connection state persistence between app restarts
- Auto-reconnect user after SDK init if previously connected

### Example App
- Display unread notification count and community access state in SDK Status panel
- Consolidated connect/disconnect into single conditional button
- Added `SafeArea` to Configuration tab for edge-to-edge display fix
- Shortened toast durations
- Community tab now recreates on each tap (removed IndexedStack)
- Moved secrets (API key, JWT token) to gitignored `secrets.dart` file

## 1.7.1
- Moving Android Octopus SDK to 1.7.2 (fixes Protobuf dependencies conflicts with Firebase)
- Moving iOS Octopus SDK to 1.7.2 (fixes Cocoapods package name conflicts between GRPC-Swift and GRPC-Core)

## 1.7.0
- First public release aligned with Octopus native SDK 1.7 on iOS and Android.
- Added SSO (`initializeOctopusSDK`)
- Added user session helpers: `connectUser`, `connectUserWithTokenProvider`, and `disconnectUser`.
- Introduced embedded `OctopusView` widget with callbacks for login navigation, profile edits, and back events.
- Added theme customization (colors, font sizz, logo, light/dark modes) passed through to the native UI.


