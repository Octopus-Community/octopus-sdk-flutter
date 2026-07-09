# Migrating

This guide consolidates the migration notes for every minor release of the
`octopus_sdk_flutter` plugin since 1.9. Each section lists the breaking changes
first (with before/after code), then the additive surface introduced in that
release. The most recent version is at the top.

- [To 1.12.2 (from 1.12.0/1.12.1)](#to-1122-from-11201121)
- [To 1.12.0 (from 1.11.x)](#to-1120-from-111x)
- [To 1.11.0 (from 1.10.x)](#to-1110-from-110x)
- [To 1.10.0 (from 1.9.x)](#to-1100-from-19x)
- [To 1.9.0](#to-190)

---

## To 1.12.2 (from 1.12.0/1.12.1)

No breaking API changes — purely additive plus one deprecation.

### Deprecated — `connectUser`'s static `token` parameter

`OctopusSDK.connectUser`'s `token` parameter (a pre-minted static JWT) is
deprecated in favor of `tokenProvider`, an async callback the SDK invokes
whenever it needs a signed JWT — on initial connect **and** on every
subsequent refresh (e.g. `refreshEntitlements()`). A static token cannot be
re-minted, so a long-lived session eventually fails once it expires.

**Before:**
```dart
await octopus.connectUser(userId: userId, token: jwt);
```

**After:**
```dart
await octopus.connectUser(
  userId: userId,
  tokenProvider: () async => fetchFreshJwtFromYourBackend(),
);
```

`token` still works — no breaking change, will be removed in a future major
version. Passing both `tokenProvider` and `token` now throws `ArgumentError`
in every build (previously a debug-only `assert` that release builds
silently skipped, silently preferring `tokenProvider` if a caller mistakenly
passed both).

### New

- **`bridgeShareTokenProvider` on `CreatePostScreenInfo`** — sign prefilled
  image shares on the create-post editor when a community forbids member
  pictures. See [CHANGELOG.md](CHANGELOG.md) `## 1.12.2` for the full
  contract.
- **`navBarLeadingAction` on `OctopusHomeScreen` now works on Android too**
  (previously iOS-only).
- **iOS SPM (Swift Package Manager) dual-support** — the plugin now ships a
  `Package.swift` alongside the existing podspec; CocoaPods still supported.
- **iOS: `OctopusConnectionState.isGuest` now reported** (previously always
  `false` on iOS, see 1.12.0's note above).

### Dependencies
- Android Octopus SDK: 1.12.0 → 1.12.1
- iOS Octopus SDK: 1.12.2 → 1.12.6

---

## To 1.12.0 (from 1.11.x)

### Breaking — `overrideCommunityAccess(bool)` now returns `OctopusResult`

`OctopusSDK.overrideCommunityAccess(bool)` previously returned `Future<void>`
and threw a `PlatformException` on failure. It now returns
`Future<OctopusResult<void, OverrideCommunityAccessError>>` and surfaces
handled SDK failures as a typed `OctopusFailure` instead of throwing. This
mirrors the native Android `OctopusResult` API.

**Before:**
```dart
try {
  await octopus.overrideCommunityAccess(true);
  // success
} catch (e) {
  // failure
}
```

**After (helpers — the simplest path):**
```dart
(await octopus.overrideCommunityAccess(true))
    .onSuccess((_) => debugPrint('applied'))
    .onFailure((f) => debugPrint('failed: $f'));

// Or, ignoring the outcome (still valid — no behavioural change for
// fire-and-forget callers):
await octopus.overrideCommunityAccess(true);
```

**After (exhaustive `switch`):**
```dart
final result = await octopus.overrideCommunityAccess(true);
switch (result) {
  case OctopusSuccess():
    // success
  case OctopusConnectionFailure():
    // transport/auth failure (OctopusNoNetwork, OctopusStatusError, …) —
    // carries no typed error
  case OctopusInvalidArguments<OctopusServerError>(:final errors):
    // typed errors; recover the OverrideCommunityAccessError values via
    // errors.whereType<OverrideCommunityAccessError>()
}
```

> **Exhaustive-switch footgun**: the explicit
> `OctopusInvalidArguments<OctopusServerError>` type argument is **required**
> for the `switch` to be exhaustive. `OctopusInvalidArguments` is invariant in
> its error type, so the analyzer matches the bound. The pattern then binds
> `errors` as `List<OctopusServerError>`; use `whereType<…>()`, or the
> `OctopusInvalidArguments.filterErrors<…>()` / `hasError<…>()` helpers, to
> recover the concrete error type. You can also expand
> `case OctopusConnectionFailure()` into the five individual leaves
> (`OctopusNoNetwork`, `OctopusContentUnavailable`,
> `OctopusUserNotAuthenticated`, `OctopusPermissionDenied`,
> `OctopusStatusError`) if you need to react to each.

> Programming errors (calling before `initialize()`) still throw a
> `PlatformException` — only *handled* SDK failures are returned as an
> `OctopusFailure`.

#### iOS ↔ Flutter error-mapping table

Android returns a typed `OctopusResult` natively; iOS uses Swift `async throws`
and does not expose typed connection-vs-business failures for every call. The
Flutter iOS bridge therefore collapses some failure modes onto
`OctopusInvalidArguments<…>` with a single catch-all error. Code that
distinguishes `OctopusNoNetwork` from `OctopusInvalidArguments` will see only
the latter on iOS for these methods.

| Method | Android (typed) | iOS (Flutter bridge) |
|--------|-----------------|----------------------|
| `overrideCommunityAccess(bool)` | `OctopusSuccess` / `OctopusConnectionFailure*` / `OctopusInvalidArguments([OverrideCommunityAccessError])` | `OctopusSuccess` or `OctopusInvalidArguments([OverrideCommunityAccessUnknownError(message)])` for **every** handled failure |
| `setReaction(...)` | typed `SetReactionError` (`...UnknownReaction` / `...PostNotFound` / `...ReactionError`) | same typed leaves; plus removing a reaction with `null` when none is set is reported as `SetReactionReactionError` (Android: silent success) |
| `fetchOrCreateClientObjectRelatedPost(...)` | fine-grained `ClientPostError` subtypes | content errors collapse to `ClientPostOtherError` (iOS native does not expose the specific validation kind publicly) |
| `refreshEntitlements()` | typed `RefreshEntitlementsError` leaves | same typed leaves on both platforms |

### Behavior changes (non-breaking)

These are behavior changes on existing parameters: the public API surface is
unchanged, but Flutter hosts that relied on prior runtime behavior may observe
a different shape in 1.12.0. Notes below are tagged with the platform they
affect.

#### `OctopusHomeScreen.navigationMode` default flips to `.navigationStack`

`OctopusHomeScreen.navigationMode` (and `OctopusSDK.embeddedView`'s
`navigationMode` parameter) now defaults to
`OctopusNavigationMode.navigationStack` instead of `.automatic`. Every Flutter
route is by definition a UIKit-hosted reparented presentation, and the legacy
`NavigationView` container behind `.automatic` silently drops programmatic
sub-navigation pushes there (post taps that don't open the detail, "Yes"
confirmations on the unsaved-changes alert that leave the New Post screen in
place, …). `.navigationStack` keeps them working (iOS 16+, with a
`NavigationView` fallback on older OS).

Hosts that never passed `navigationMode` now silently get the working
container — a fix, not a regression. To opt back into the native iOS default,
pass it explicitly:

```dart
OctopusHomeScreen(
  // …
  navigationMode: OctopusNavigationMode.automatic, // opt back in to NavigationView
)
```

#### `showBackButton: true` now renders a back chevron on iOS

`OctopusHomeScreen(showBackButton: true)` (and `OctopusSDK.embeddedView`'s
`showBackButton`) is the cross-platform back-button flag the Android bridge
already honoured — the iOS bridge previously dropped it silently, so a host
that followed the documented pattern got a chevron on Android and nothing on
iOS. The iOS bridge now backfills the missing leading nav-bar action: when
`showBackButton: true` is on the wire and no explicit `navBarLeadingAction`
was provided, the native iOS SDK renders a back chevron whose tap routes
through the existing `backRequested` event → `OctopusHomeScreen.onBack`. An
explicit `navBarLeadingAction` (`.close` / `.back`) still wins.

Hosts whose iOS code wired `showBackButton: true` but no `onBack` will see
the chevron appear; `onBack` is null-safe (the chevron renders but is inert
without a handler), but you almost certainly want to pop the route:

```dart
OctopusHomeScreen(
  showBackButton: true, // now visible on iOS too — wire onBack
  onBack: () => Navigator.of(context).pop(),
)
```

#### Android: the embedded view now eagerly claims pointer events

`OctopusSDK.embeddedView` (and the underlying `OctopusHomeScreen`) configures
its Android `AndroidView` with an `EagerGestureRecognizer` in 1.12.0. Every
pointer that lands inside the embedded view's bounds is dispatched directly
to the native side, so the SDK's internal scroll (the feed) wins vertical
drags even when the host wraps the SDK in an ancestor that competes for
vertical gestures — a `showModalBottomSheet`, a parent `ListView`, a custom
draggable modal.

Prior to 1.12.0 the empty `gestureRecognizers` set meant ancestor Flutter
recognizers won the gesture arena over the embedded view: the bug case was
that the SDK feed was unscrollable inside a `showModalBottomSheet` because
its `VerticalDragGestureRecognizer` stole every drag. iOS was unaffected
(UIKit's gesture-recognizer delegation already let the inner `UIScrollView`
win — see `flutter/flutter#26425`/`#66270`).

Hosts that previously relied on a parent winning over the embedded view
(custom bottom sheet with no `showDragHandle`, a `PageView`/`TabBarView`
page swipe overlapping the SDK, an `InteractiveViewer` ancestor) will see
those gestures consumed by the SDK on Android in 1.12.0. To keep the
ancestor affordance, move it outside the embedded view's bounds:

```dart
showModalBottomSheet(
  isScrollControlled: true,
  showDragHandle: true, // Material 3 affordance — handle sits above the SDK
  builder: (ctx) => SizedBox(
    height: MediaQuery.sizeOf(ctx).height * 0.9,
    child: OctopusHomeScreen(/* … */),
  ),
);
```

`showDragHandle: true` is the recommended pattern when the SDK is hosted in a
modal sheet — the handle is rendered above the embedded view, outside the
`AndroidView` bounds, so dragging it dismisses while drags inside the feed
scroll the SDK.

### New

- **Custom API server endpoint** — `ApiServer(host, port)` model + optional
  `apiServer` parameter on `initialize(...)` / `initializeOctopusAuth(...)`.
  Routes the SDK's gRPC traffic to a custom host/port over TLS. Host is
  validated at construction (`ApiServerValidationError`).
- **Multi-community switching** — `switchCommunity(apiKey, appManagedFields, apiServer)`
  (SSO) and `switchCommunityOctopusAuth(apiKey, deepLink, apiServer)` (Octopus
  Auth) disconnect the current user, clear cached data, and reinitialize
  against another community at runtime. Give embedded UI a
  `key: ValueKey(apiKey)` so the native view is rebuilt for the new community.
- **SDK lifecycle** — `reset()` disconnects the user and returns the SDK to a
  clean state while staying initialized; `stop()` tears it down to an
  uninitialized state.
- **`setGroupAccessDeniedCallback(...)`** — fires with the `groupId` when the
  user taps a group they cannot access (locked group / follow button / detail
  CTA). The SDK never navigates on the user's behalf. Returns a `VoidCallback`
  to unregister; registering again replaces the previous callback
  (last-write-wins).
- **`refreshEntitlements()`** — `Future<OctopusResult<void, RefreshEntitlementsError>>`
  refreshes the connected user's community entitlements from the backend (SSO
  mode only). Typed errors: `RefreshEntitlementsNoClientTokenProviderError`,
  `RefreshEntitlementsUserNotConnectedError`,
  `RefreshEntitlementsNoNetworkError`,
  `RefreshEntitlementsUserBannedError` (backend message, displayable),
  `RefreshEntitlementsServerError`.
- **Streams: `groups` and `profile`**
    - `OctopusSDK.groups: Stream<List<OctopusGroup>>` — community groups
      (content categories). Replays the latest list to late subscribers and
      collapses consecutive duplicates. `OctopusGroup` exposes `id`, `name`,
      `isFollowed`, `canChangeFollowStatus`, `canAccess` (false =
      visible-but-locked → route through `setGroupAccessDeniedCallback`), and
      `canCreateChildren`.
    - `OctopusSDK.profile: Stream<OctopusProfile?>` — connected user
      (`null` when not connected). Emits on every profile change, including
      after `refreshEntitlements()`. `OctopusProfile` exposes the held
      `entitlements` (`Set<String>`, opaque tokens defined by the host app;
      display-only).
- **Connection state** — `connectionState: Stream<OctopusConnectionState>`
  (`OctopusNotConnected` / `OctopusConnected(isGuest)`) and the derived
  `isUserConnected: Stream<bool>`. On iOS `isGuest` is currently always
  `false` (the public iOS `OctopusProfile` does not surface `isGuest`).
- **Initialization state** — `isInitialised` synchronous getter and
  `isInitialisedFlow: Stream<bool>` (replays current value, collapses dupes).
- **`setReaction(reaction, postId)`** — purely additive in 1.12.0 (no
  `setReaction` existed in earlier Flutter releases). Sets (or removes, with
  `null`) the connected user's reaction on **any** post (bridge or community).
  `OctopusReactionKind` is a sealed class (not an enum) with const singletons
  `.heart` / `.joy` / `.mouthOpen` / `.clap` / `.cry` / `.rage`, plus an
  `OctopusUnknownReaction(serverValue)` forward-compat fallback so a reaction
  added by a newer backend decodes without an SDK release. Passing
  `OctopusUnknownReaction` to `setReaction` is rejected with
  `SetReactionUnknownReactionError`.

  ```dart
  (await octopus.setReaction(OctopusReactionKind.heart, postId))
      .onSuccess((_) => debugPrint('reacted'))
      .onFailure((f) => debugPrint('failed: $f'));

  // Remove the current reaction:
  await octopus.setReaction(null, postId);
  ```

  Exhaustive `switch` (same `OctopusInvalidArguments<OctopusServerError>`
  annotation rule — business errors arrive there; connection/auth failures
  stay in the orthogonal `OctopusConnectionFailure` branch):

  ```dart
  switch (await octopus.setReaction(OctopusReactionKind.joy, postId)) {
    case OctopusSuccess():
      // done
    case OctopusConnectionFailure():
      // OctopusNoNetwork, OctopusUserNotAuthenticated, … — no typed error
    case OctopusInvalidArguments<OctopusServerError>(:final errors):
      for (final e in errors.whereType<SetReactionError>()) {
        switch (e) {
          case SetReactionUnknownReactionError(): // unsupported reaction
          case SetReactionPostNotFoundError():    // unknown post / no access
          case SetReactionReactionError():        // backend error
        }
      }
  }
  ```

- **Typed results (`OctopusResult<D, E>`)** — sealed hierarchy mirroring the
  native SDK: `OctopusSuccess`, connection failures (`OctopusNoNetwork`,
  `OctopusContentUnavailable`, `OctopusUserNotAuthenticated`,
  `OctopusPermissionDenied`, `OctopusStatusError`), and
  `OctopusInvalidArguments<E>` carrying typed `OctopusServerError`s. Helpers
  available: `mapSuccess`, `mapErrors`, `onSuccess`, `onFailure`, `onError`,
  `getOrNull`, `getOrElse`. **Exhaustive switches must annotate
  `OctopusInvalidArguments<OctopusServerError>`** (see the breaking section
  above).
- **`fetchGroups()` / `followGroup(id)` / `unfollowGroup(id)`** —
  `Future<OctopusResult<…, GroupFollowUnfollowError>>` with sealed leaves
  `MissingGroup` / `UnfollowableGroup` / `GroupAlreadyFollowed` /
  `GroupAlreadyUnfollowed` / `LastFollowedGroup` / `Unknown`. On iOS the
  bridge maps onto the single-action `syncFollowGroups([Action])` (no
  individual native methods); `.notFollowable` and `.notUnfollowable` both
  collapse onto `UnfollowableGroup`. `LastFollowedGroup` is Android-only
  (iOS silently succeeds).
- **Bridge create-post models** — value-equal input models for the bridge
  create-post APIs: `OctopusPrefilledPost({text, image, topicId, cta})`
  (eager validation → sealed `OctopusPrefilledPostValidationError`:
  `ContentEmpty` / `TextTooShort(10)` / `TextTooLong(5000)` /
  `CtaLabelEmpty` / `CtaUrlEmpty`); `OctopusPostCTA({url, label})`;
  `CreatePostScreenInfo({prefilledPost})`; and
  `ClientPost({objectId, text, attachment, catchPhrase, viewObjectButtonText, groupId})`
  with sealed `OctopusClientPostAttachment` (`OctopusLocalImageAttachment(bytes)` /
  `OctopusRemoteImageAttachment(url)`). Image bytes are passed as `Uint8List`;
  dimension checks happen later in the editor (matches Android).
- **Bridge post API (`fetchOrCreateClientObjectRelatedPost`)** —
  `Future<OctopusResult<OctopusPost, ClientPostError>>` with an optional
  `tokenProvider: Future<String?> Function(String fingerprint)` invoked only
  when a new post must be created and your community requires a bridge
  signature. `OctopusPost` is the lean read view (`id`, `reactions`,
  `commentCount`, `viewCount`, `userReactionKind`). 17 typed
  `ClientPostError` leaves on Android; iOS collapses content errors to
  `ClientPostOtherError`.
- **`setNavigateToClientObjectCallback(...)`** — fires with the `objectId`
  when the user taps the "view object" button on a bridge post. Last-write-
  wins; returns a `VoidCallback` to unregister.
- **`getClientObjectRelatedPostFlow(clientObjectId)`** —
  `Stream<OctopusPost?>` observing the bridge post linked to a host object
  (`null` until it exists). Replays current value to new subscribers; each
  subscription drives its own native observation (safe to observe the same
  id from two places).
- **Create-post editor (`showOctopusCreatePostScreen`)** —
  `Future<void> showOctopusCreatePostScreen({CreatePostScreenInfo? info, OctopusTheme? theme})`
  opens the native editor presentation-style: a dedicated Activity on
  Android, a full-screen modal on iOS. Future completes when the editor
  closes. Login / profile-edit / view-object intents are routed back to the
  host via the existing global events (`onNavigateToLogin`, `onModifyUser`,
  `setNavigateToClientObjectCallback`).
- **`bottomSafeAreaInset` on `OctopusHomeScreen`** — optional `double`
  parameter (default `0`) that pads the embedded view's bottom area so the
  floating "Write a post" button clears the host app's bottom chrome.
  Plumbed end-to-end (Android `contentPadding`, iOS `bottomSafeAreaInset`).
  Pass `kBottomNavigationBarHeight + MediaQuery.viewPaddingOf(context).bottom`
  for a standard Material shell.
- **`OctopusHomeContent`** — no-navbar variant of `OctopusHomeScreen` for
  host-driven titles. Android-only renderer when both platforms support it;
  on iOS the bridge falls back to `OctopusHomeScreen` until the iOS pod
  ships the parity API.
- **`formatOctopusCompactCount(int, {Locale? locale})`** — top-level helper
  that formats integer counts in the same compact `K` / `M` / `B` style as
  the embedded community UI (`0`–`999` raw, then `1.2K` / `12K` / `999K` /
  `1.2M` / `1B`, band-floor). The optional `locale` flips the decimal
  separator (`1,2K` for French / German / Spanish / …, `1.2K` for English
  and the default).
- **Screen entry points (`OctopusInitialScreen`)** — sealed type with four
  variants: `.mainFeed()` (default), `.post(PostScreenInfo(postId: ...))`,
  `.group(GroupScreenInfo(groupId: ...))`, and
  `.createPost(CreatePostScreenInfo)` — passed via the new optional
  `initialScreen:` parameter on `OctopusHomeScreen` and `OctopusHomeContent`.
  Also adds dedicated `OctopusPostDetailsScreen(postId:)` /
  `OctopusGroupDetailsScreen(groupId:)` widgets as ergonomic shorthands.
  **Precedence rule:** when a `notification` with a non-empty `linkPath` is
  supplied at the same mount, the deep link wins and `initialScreen` is
  ignored. **Note:** image bytes carried in `OctopusPrefilledPost.image` are
  dropped on the embedded `createPost` route on both platforms — use
  `showOctopusCreatePostScreen` for the image-share flow.

### Dependencies
- Android Octopus SDK: 1.11.0 → 1.12.0
- iOS Octopus SDK: 1.11.0 → 1.12.0

---

## To 1.11.0 (from 1.10.x)

No breaking API changes — 1.11 is purely additive plus one bug fix that may
**change observable behaviour** for apps that relied on the bug.

### Breaking-ish — `ProfileField.picture` was silently dropped

Previously, `appManagedFields: [..., ProfileField.picture]` was serialised on
the Dart side as `'AVATAR'`, but both native bridges only recognise
`'PICTURE'` and dropped the rest. Users could therefore still edit their
profile picture inside the Octopus UI even when the host app claimed it as
app-managed. The wire format is now correct (`PICTURE`).

**Action required**: apps using `ProfileField.picture` should re-test their
profile flows. Pictures will now be blocked in the Octopus UI and routed
through `onModifyUser('PICTURE')` as documented.

### New

- **Push notifications** — first-class support for push notifications inside
  the SDK.
- **`syncFollowGroups([Action])`** — batch follow/unfollow groups in one
  round-trip via `OctopusSDK().syncFollowGroups([...])`. Returns per-action
  `SyncFollowGroupResult` with a typed `SyncFollowGroupStatus` (with
  `unknownError` fallback for future native variants). RPC-level failures
  surface as `PlatformException` with codes `not_connected`, `no_network`,
  `server`, or `other`.
- **Typed `OctopusEvent` / `Screen` classes for new 1.11 events** —
  `GroupFollowingChangedEvent`, `MainFeedScreen`, `GroupsScreen`,
  `GroupDetailScreen` (with `GroupDetailSource` enum: `bridge` / `community`
  / `unknown`).

### Dependencies
- Android Octopus SDK: 1.9.0 → 1.11.0
- iOS Octopus SDK: 1.9.0 → 1.11.0

---

## To 1.10.0 (from 1.9.x)

No breaking API changes — 1.10 is purely additive. (1.10 was not released
publicly as a standalone Flutter version; these features were backfilled into
the Flutter plugin alongside the 1.12.0 work but originate from the 1.10 line
of the native SDKs.)

### New

- **`switchCommunity(...)`** — `OctopusSDK().switchCommunity(apiKey, appManagedFields, apiServer)`
  (SSO) and `switchCommunityOctopusAuth(apiKey, deepLink, apiServer)`
  (Octopus Auth) disconnect the current user, clear cached data, and
  reinitialize against another community at runtime. Give embedded UI a
  `key: ValueKey(apiKey)` so the native view is rebuilt for the new
  community.
- **`reset()` and `stop()`** — `reset()` disconnects the user and returns
  the SDK to a clean state while staying initialized; `stop()` tears the
  SDK down to an uninitialized state. On iOS — which has no native `reset`/
  `stop`/`isInitialised` — these are ported on top of the available native
  surface; `reset()` disconnects the user only (no public cache-clearing
  API on iOS).
- **`isInitialised` + `isInitialisedFlow`** — synchronous getter and
  `Stream<bool>` (replays the current value to late subscribers, collapses
  consecutive duplicates) for the SDK's initialization state.
- **`OctopusHomeScreen` extras** — additional optional parameters on the
  embedded widget (theme, callback, and navbar configuration knobs aligned
  with the native 1.10 surface). Existing callers compile unchanged.

---

## To 1.9.0

1.9 was a major-version refresh — class/method renames, the introduction of
`ProfileField` as a typed enum, `OctopusView` → `OctopusHomeScreen`, removal
of imperative `showNativeUI` / `closeNativeUI` in favour of the embedded
widget, and the addition of `onNavigateToUrl` URL interception. The
breaking-change summary below covers the migration; the prior standalone
`MIGRATION_1_9.md` doc has been folded into this section.

### Breaking — summary

- `OctopusSdkFlutter` → `OctopusSDK`
- `OctopusView` → `OctopusHomeScreen`
- `initializeOctopusSDK()` → `initialize()`
- `showOctopusView()` → `showOctopusHomeScreen()`
- `appManagedFields` changed from `List<String>?` to `List<ProfileField>?`
  (use `ProfileField.nickname` / `.picture` / `.bio` instead of `'NICKNAME'`
  / `'AVATAR'` / `'BIO'`)
- `embeddedView()` callback parameters removed — use the `OctopusHomeScreen`
  widget instead
- Removed legacy `showNativeUI()` and `closeNativeUI()` methods

### New — summary

- **Notification badge count** — `Stream<int> notSeenNotificationsCount` for
  reactive badge updates, `updateNotSeenNotificationsCount()` to force
  refresh.
- **Community access / A/B testing** — `Stream<bool> hasAccessToCommunity`
  for reactive access state, `overrideCommunityAccess(bool)` to override the
  cohort (still `Future<void>` in 1.9 — see the 1.12 breaking change above),
  `trackCommunityAccess(bool)` for analytics.
- **URL interception** — `onNavigateToUrl` callback on `OctopusHomeScreen`
  with `UrlOpeningStrategy` enum (`handledByApp` / `handledByOctopus`).
- **Locale override** — `overrideDefaultLocale(Locale?)` to override the SDK
  UI language.
- **Custom analytics** — `trackCustomEvent(name, properties)` to send custom
  events to Octopus analytics.
- **SDK events** — `Stream<OctopusEvent> events` covering 20 event types
  (content creation/deletion, reactions, polls, gamification, screen
  navigation, clicks, profile changes, sessions). Use with Dart pattern
  matching.
