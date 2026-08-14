# Migrating

This guide consolidates the migration notes for every minor release of the
`octopus_sdk_flutter` plugin since 1.9. Each section lists the breaking changes
first (with before/after code), then the additive surface introduced in that
release. The most recent version is at the top.

- [To 1.13.0 (from 1.12.x)](#to-1130-from-112x)
- [To 1.12.2 (from 1.12.0/1.12.1)](#to-1122-from-11201121)
- [To 1.12.0 (from 1.11.x)](#to-1120-from-111x)
- [To 1.11.0 (from 1.10.x)](#to-1110-from-110x)
- [To 1.10.0 (from 1.9.x)](#to-1100-from-19x)
- [To 1.9.0](#to-190)

---

## To 1.13.0 (from 1.12.x)

Two breaking changes (a screen event that no longer exists natively, and
`connectUser` now returning an `OctopusResult`) and two behaviour changes (a
payload the SDK used to reject is now accepted, and `bottomSafeAreaInset: 0` now
resolves the Android bottom inset from the mount point). Expect new analyzer
warnings even if you change nothing — see the `@useResult` note below.

### Breaking — `SettingsAboutScreen` removed

The native SDKs removed the "About the community" screen in 1.13.0 (its three
legal links were already duplicated in the Activity and current-user Profile
overflow menus), so neither platform emits a `settingsAbout` screen-displayed
event anymore. `SettingsAboutScreen` is therefore gone from the `Screen`
hierarchy.

This only breaks compilation if you `switch` exhaustively over `Screen` without
a `default` or wildcard arm — remove the `SettingsAboutScreen()` arm:

**Before:**
```dart
final label = switch (screen) {
  SettingsAccountScreen() => 'Account settings',
  SettingsAboutScreen() => 'About the community',
  // …
};
```

**After:**
```dart
final label = switch (screen) {
  SettingsAccountScreen() => 'Account settings',
  // …
};
```

There is no runtime change to handle: the event stopped being emitted when the
native screen was removed, so no host logic keyed on it can still fire. Nothing
replaces it — the screen itself is gone, not renamed.

### Breaking — `connectUser` now returns `OctopusResult`

`OctopusSDK.connectUser(...)` and the deprecated
`OctopusSDK.connectUserWithTokenProvider(...)` previously returned `Future<void>`
and **reported success even when the connection had been refused**: both bridges
discarded the native result, so a banned user, a JWT the backend rejects, or a
missing token completed exactly like a successful connect. Both now return
`Future<OctopusResult<void, ClientUserError>>`. Same shape as
`overrideCommunityAccess` in 1.12.0.

**Your call sites keep compiling.** `void` is a top type, so
`Future<OctopusResult<void, ClientUserError>>` is assignable to `Future<void>` —
assignments, `return`s, `unawaited(...)`, `Future.wait` and tearoffs stored in a
`Future<void> Function({...})` typedef are all unaffected. Handle the result:

**Before:**
```dart
await octopus.connectUser(userId: id, tokenProvider: mintJwt);
// assumed connected
```

**After (helpers — the simplest path):**
```dart
(await octopus.connectUser(userId: id, tokenProvider: mintJwt))
    .onSuccess((_) => debugPrint('connected'))
    .onFailure((f) => showError('$f'));
```

**After (exhaustive `switch`):**
```dart
final result = await octopus.connectUser(userId: id, tokenProvider: mintJwt);
switch (result) {
  case OctopusSuccess():
    // connected; `connectionState` emits independently
    break;
  case OctopusInvalidArguments<OctopusServerError>(:final errors):
    // the connection was refused — show it, or your login screen looks like
    // it did nothing
    for (final error in errors.whereType<ClientUserError>()) {
      showError(error.errorMessage);
    }
  case OctopusConnectionFailure():
    showError('Could not reach Octopus.');
}
```

The [exhaustive-switch footgun](#breaking--overridecommunityaccessbool-now-returns-octopusresult)
documented for 1.12.0 applies here too: the explicit
`OctopusInvalidArguments<OctopusServerError>` type argument is required for
exhaustiveness, and `errors` binds as `List<OctopusServerError>`.

**`ClientUserError` leaves are not symmetric across platforms.** Some are only
ever emitted on Android, others only on iOS, and a native SDK bump can start
emitting on a platform a variant that was absent there — so do not narrow your
handling to one platform's subset. The per-platform table lives in the
`ClientUserError` API docs and is machine-checked against both bridges by
`scripts/verify_connect_user_parity.dart`.

What a native bump *cannot* do is add a leaf: an unknown wire error folds into
`ClientUserOtherError`. So once you have narrowed to `ClientUserError`, switch
**exhaustively with no `default`/wildcard arm** — the hierarchy is sealed, and a
catch-all over a complete switch is a fatal analyzer warning. New leaves only
ever arrive by upgrading this package, and are called out here.

**Behaviour note — the token provider outlives a failed connect.** The
`tokenProvider` you register stays registered whatever the connect returns, and
is released by `disconnectUser()`. Both native SDKs keep their own reference to
it and re-invoke it on every later refresh (`refreshEntitlements()`), and several
refusals are raised with the user already connected (a rejected nickname comes
back as `ClientUserProfileError` *after* the session was saved), so a refusal is
not a signal to stop answering token requests.

**Behaviour note — on iOS the returned `Future` now waits for the attempt.** The
iOS bridge used to reply to Dart *before* the native connect had done anything,
so `await connectUser(...)` resolved within milliseconds regardless of the
outcome — which is precisely why it could not report a refusal. It now resolves
when the attempt completes. Android already awaited, so the two platforms now
agree; there is nothing to change in your code. But if you `await` this call on a
**blocking path** — a splash screen, a route guard, a `FutureBuilder` gating the
first frame — that wait is now as long as the network takes on iOS, and up to
**60 s** if the `tokenProvider` you passed never answers. Both bridges then fall
back to an empty token, but what you get back differs by platform: Android
rejects an empty token locally and deterministically, as
`ClientUserMissingTokenError`, whereas iOS has no local check — it forwards the
empty string to the backend token exchange, so the outcome depends on that
call's answer and can be `ClientUserInvalidTokenError`, `ClientUserOtherError`,
or a **connection-level** failure (`OctopusStatusError`) that is not a
`ClientUserError` at all. Neither platform carries a dedicated "the provider
never answered" code, but the consequence differs. On **Android** the two
outcomes stay distinguishable: an unanswered (hence empty) token is refused
locally as `ClientUserMissingTokenError`, while a token the backend refused comes
back as `ClientUserBannedError`, `ClientUserProfileError` or
`ClientUserOtherError`. On **iOS** both go through the same exchange, so they are
indistinguishable from the result alone — time the call on your side if you need
to tell them apart. One more reason to handle the
`OctopusConnectionFailure` arm of the `switch` above, not just the typed one.
Either show a progress state around the call, or don't await it and react to the
result when it lands.

**Behaviour note — on iOS a refusal does not always reach you.** When the token
exchange fails while **nothing is connected yet** (the ordinary first login), the
native `SSOConnectionRepository.connect()` falls back to `connectAsGuest()` and
returns normally: this bridge sees no error and hands you `OctopusSuccess` while
the user is anonymous. That covers the empty token above, a JWT the backend
refuses, and a `tokenProvider` that threw. The refusal *does* arrive when a
connection already existed — reconnecting after a previous failure, for instance
— because that path rethrows; and a concurrent guest connection can make the call
return without ever requesting a token (`guard !isConnecting else { return }`),
though only in a narrow window: the caller first waits up to 3 s for that
connection to end, and throws if it has not.
Android has no such fallback: every refusal is reported there. So on iOS an
`OctopusSuccess` means "the SDK is usable", not "your SSO user is
authenticated". It cannot be fixed from the bridge — what is actionable is the
cause: sign a valid token, and answer the provider promptly. Do not build a
"logged in" state on iOS out of `OctopusSuccess` alone; confirm it with the
connection state, which does tell the two apart. Both are **streams**, not
snapshots: the `OctopusSDK.isUserConnected` stream emits `false` under the guest
fallback, and `OctopusSDK.connectionState` emits `OctopusConnected(isGuest:
true)`. Subscribe and drive your "logged in" state off them, rather than sampling
one right after the call returns — they emit independently of `connectUser`'s
`Future` and can still be carrying the previous state at that instant. Both
predate this release; the iOS guest flag they rely on needs native iOS
`1.12.6+`, which this version pins.

### Breaking (analyzer) — ignoring an `OctopusResult` is now a warning

`connectUser` and `connectUserWithTokenProvider` are annotated `@useResult`.
Discarding their result raises an `unused_result` **warning** — and
`flutter analyze` / `dart analyze --fatal-warnings` exit non-zero on warnings
alone, so a host that upgrades without touching a line of its own code can see
its CI turn red on those two call sites.

The other `OctopusResult`-returning methods (`overrideCommunityAccess`,
`refreshEntitlements`, `setReaction`, `fetchGroups`, `followGroup`,
`unfollowGroup`, `fetchOrCreateClientObjectRelatedPost`) are **not** annotated
here. Annotating them is a second, independent break with its own migration, and
it is not what this change is about. Nothing breaks at runtime, and there is no
behaviour change.

Handle the result, or discard it explicitly — a wildcard assignment satisfies the
annotation:

```dart
// Best-effort call whose outcome you really do not need:
final _ = await octopus.connectUser(userId: id, tokenProvider: mintJwt);
```

A non-binding `_` needs **Dart 3.7+**, and this package's floor is 3.0.0. On an
older SDK `_` is an ordinary local name, so a *second* discard in the same scope
collides with the first — and giving it a real name only trades `unused_result`
for `unused_local_variable`. If you are below 3.7, silence the annotation
directly instead:

```dart
// ignore: unused_result
await octopus.connectUser(userId: id, tokenProvider: mintJwt);
```

**What does break at compile time:** any class that *overrides* or *implements*
`connectUser` / `connectUserWithTokenProvider` while still declaring the old
`Future<void>` return type — a hand-written wrapper around `OctopusSDK`, or a
hand-written `OctopusSDKPlatform` fake in your own tests — now fails with
`invalid_override`. Widen the override's return type to
`Future<OctopusResult<void, ClientUserError>>`. Mocks that never redeclare the
method (`implements OctopusSDK` with `noSuchMethod`, mocktail-style, or a bare
`extends OctopusSDK {}`) are unaffected.

### Behaviour change — a content-less `OctopusPrefilledPost` is accepted

`text` and `image` are both optional now, matching the native 1.13 relaxation. A
payload carrying only a `topicId` and/or a `cta` used to throw
`OctopusPrefilledPostContentEmptyError`; it is now accepted and opens the editor
on the preselected group with empty, user-editable fields.

Nothing compiles differently — the error class is still exported, so an
exhaustive `switch` over `OctopusPrefilledPostValidationError` keeps working —
but it is never thrown again. **If you relied on that throw** as your only
empty-payload check, you now get an empty editor instead of an error:

**Before** — the SDK rejected the payload for you:
```dart
try {
  final prefill = OctopusPrefilledPost(topicId: groupId);
  // unreachable: threw OctopusPrefilledPostContentEmptyError
} on OctopusPrefilledPostContentEmptyError {
  showError('Nothing to share');
}
```

**After** — validate host-side if an empty share is not what you want:
```dart
if (text == null && image == null) {
  showError('Nothing to share');
  return;
}
final prefill = OctopusPrefilledPost(text: text, image: image, topicId: groupId);
```

Text-length and CTA validation are unchanged. On Android, the full-screen
create-post entry point had the same pre-1.13 rule baked in and silently dropped
a `topicId`/`cta`-only prefill; it now only drops a wholly empty one.

### Behaviour change — `bottomSafeAreaInset: 0` resolves from the mount point (Android)

On `OctopusHomeScreen`, `OctopusHomeContent`, `OctopusPostDetailsScreen` and
`OctopusGroupDetailsScreen`, the `bottomSafeAreaInset` default of `0` used to mean
"reserve nothing". On **Android** it now means "reserve whatever bottom padding
the ambient `MediaQuery` still has left at the mount point", so a full-screen
mount keeps the native floating "Write a post" pill clear of the system
navigation bar on edge-to-edge devices (API 35+) without any host configuration.

Nothing compiles differently — no signature, type or default changed. **iOS
deliberately does not resolve anything here** (its embedded view already sits
inside the safe area, so there was nothing to clear), so an iOS host that leaves
the default is unaffected by *this* change. An iOS host that passes an **explicit**
value is affected by a different one — see
[the next section](#behaviour-change--ios-no-longer-double-counts-bottomsafeareainset).
Note this scopes to the widgets: the `showOctopusHomeScreen` / `openNotification`
helpers have inferred an inset on both platforms since 1.12.3, and this release
does not change that.

Three host shapes are worth checking on Android.

**1. You passed `0` to mean "reserve nothing".** An explicit `0` can no longer
express that, because `0` *is* the "resolve it for me" value (so is any negative
value). Consume the padding instead:

**Before:**
```dart
OctopusHomeScreen(bottomSafeAreaInset: 0)
```

**After:**
```dart
MediaQuery.removePadding(
  context: context,
  removeBottom: true,
  child: OctopusHomeScreen(),
)
```

**2. You pad the layout without consuming the padding.** A plain `Padding`, a
`Column` above a fixed footer or a `Stack` bottom overlay leaves the ambient
`MediaQuery` untouched, so the widget now reserves the navigation-bar inset a
second time *inside* the native view — on top of your own gap:

```dart
// Now reserves the nav-bar inset inside the embedded view as well.
Scaffold(
  body: Column(children: [Expanded(child: OctopusHomeScreen()), myFooter]),
)
```

Either pass the total you want (`bottomSafeAreaInset: myFooterHeight`) or wrap in
the `MediaQuery.removePadding` shown above.

**3. You use `Scaffold(extendBody: true)` with a bottom bar.** Your embedded view
runs *behind* the bar, and `Scaffold` re-injects the bar's height into the body's
`MediaQuery.padding` — so the widget now reserves that height instead of nothing:

```dart
// The pill now clears the bar; before, it sat behind it.
Scaffold(
  extendBody: true,
  bottomNavigationBar: myBar,
  body: OctopusHomeScreen(),
)
```

This is usually what you want — it is the case the parameter was designed for —
but it *is* a change, so check the result if you had compensated for it yourself.
Without `extendBody: true`, a `Scaffold` `bottomNavigationBar` /
`persistentFooterButtons` consumes the padding instead: the value resolves to `0`,
the native default applies, and nothing changes. A `SafeArea` ancestor behaves the
same way.

One limitation worth knowing: a widget first built while a keyboard is already up
resolves `0` and keeps it for its whole life (the engine folds the bottom inset
into `viewInsets`, and the native view reads creation params once). A `Scaffold`
body does not escape this. Pass the inset explicitly if your host can mount the
SDK with the keyboard open.

### Behaviour change — iOS no longer double-counts `bottomSafeAreaInset`

`bottomSafeAreaInset` is documented as the **total** bottom padding to reserve, and
that is how Android has always behaved. The iOS bridge forwarded your value
untouched to the native SDK, which applies it *on top of* the safe area the
embedded view already sits in — so the same Dart value reserved roughly twice the
intended band on iOS. The bridge now subtracts that safe area before handing the
value over. Only the Flutter bridge changed; the native iOS SDK's own additive
contract is untouched.

For a requested value `R`, and `S` = the safe area **the embedded view itself sits
in** (not the device's — `S` is `0` for the common case of a `Scaffold` body above a
bottom bar, and 34 pt on a notched iPhone only when the view runs to the bottom of
the screen), the reserved band is:

| | before | after |
|---|---|---|
| Android | `R` | `R` (unchanged) |
| iOS | `R + S` | `max(R, S)` |

The two platforms now agree whenever `R >= S` — the intended usage, since `R` is
meant to cover your own bottom chrome, which itself sits above the system inset.
Below `S`, iOS still never reserves less than the safe area it already occupies.

**If you never passed the parameter, nothing changes.** The normalization applies
only to a value you explicitly sent; with none, the bridge keeps its historical
10 pt added on top of the safe area, so existing layouts do not shift. (Dart omits
the key when the value is `0`, so `0` and "not provided" are the same thing on the
wire.)

**If you passed a value on iOS and had compensated for the doubling** — sending only
your bar's height `H` instead of the documented height + safe-area inset — your
reserved band changes from `H + S` to `max(H, S)`. Send the total you want, which is
now the same value on both platforms:

**Before** (compensating for the doubling — iOS reserved `56 + 34 = 90`, Android `56`):

```dart
OctopusHomeScreen(bottomSafeAreaInset: myBarHeight) // 56
```

**After** (both platforms reserve `90`):

```dart
final inset = myBarHeight + MediaQuery.of(context).padding.bottom;
OctopusHomeScreen(bottomSafeAreaInset: inset)
```

This also fixes a regression shipped in 1.12.3: `showOctopusHomeScreen` /
`openNotification` auto-reserve the launching view's raw bottom safe area, and on
iOS that value was then added to the safe area again (measured on iPhone 16 /
iOS 18.6 before the fix: 34 pt sent, 34 pt of system inset, both applied). Those
two helpers now reserve the intended amount on iOS. On **iOS 14** the native SDK
ignores the value entirely — its inset modifier requires iOS 15+ — so nothing extra
is reserved there either way.

**Known divergence with a hardware keyboard.** The native iOS SDK compares the
reported keyboard height against the same value it uses as a reserved height, so
normalizing the value also moves that threshold. The outcome changes only for a
reported keyboard height in `(R - S, R]`, which a full-height software keyboard
never hits; the reachable case is a hardware keyboard (iPad, or Bluetooth on
iPhone), which reports only the accessory bar. A host passing `R = 70` over `S = 20`
with 55 pt reported previously kept its band and now drops it, letting host bottom
chrome overlap the composer while typing. One scalar cannot carry both meanings from
the bridge side; a proper fix needs the native SDK to take the total and the
threshold separately.

### New

- **Unified Profile: read a member's community data.** `fetchCommunityData` (one
  shot) and `communityDataFlow` (reactive) return the new `OctopusCommunityData`
  (`profileId`, `messageCount`, `gamification`), so you can show Octopus stats on
  **your own** profile screen. Identify the member by exactly one of `profileId`
  or `clientUserId` (the latter requires the community to expose client user ids).
  `OctopusProfile.clientUserId` is the connected user's counterpart id, for
  correlating with your own user record. See
  [CHANGELOG.md](CHANGELOG.md) for the full contract — including that
  `OctopusGamification.score` is always `null` through this API.
- **`onNavigateToProfile` on all six entry points** — the four widgets
  (`OctopusHomeScreen`, `OctopusHomeContent`, `OctopusPostDetailsScreen`,
  `OctopusGroupDetailsScreen`) and the two navigation helpers
  (`OctopusSDK.showOctopusHomeScreen`, `OctopusSDK.openNotification`) — handle
  every profile tap in your own app ("Unified Profile"). You receive the tapped
  member's `clientUserId`; combine it with `fetchCommunityData` to render your own
  profile page. If you mount `OctopusSDK.embeddedView` yourself, the same
  behaviour comes from its new `interceptProfileTaps` and `hasModifyUserHandler`
  flags, which the widgets derive from the callbacks you pass them.

  Nothing to change unless you want it: **passing the callback is what activates
  the behaviour**, so leaving it null keeps the SDK's native profile screens
  exactly as before. Two things to know before wiring it:
  - It only takes effect if the community also exposes client user ids — ask
    Octopus to enable it. Until then the SDK keeps its own screens.
  - It is read **at mount time**, so pass it when you build the widget; flipping
    it on an already-mounted view does nothing until that view is rebuilt (give
    the widget a `key` that changes if you need to toggle it at runtime, as the
    sample's Community tab does).
- **`OtherUserPostsScreen(profileId:)`** — screen-displayed event for another
  member's activity (their posts list), distinct from `OtherUserProfileScreen`
  (the profile summary). Emitted on **both** platforms.
- **`ActivityScreen`** — screen-displayed event for the connected user's own
  activity, emitted instead of `ProfileScreen` when the community runs in
  Unified Profile mode. **Android only** — the iOS native SDK has no equivalent
  screen event, so do not key cross-platform logic on it.

If you `switch` exhaustively over `Screen`, add arms for these two. A host that
uses a `default`/wildcard arm needs no change; a host that parses events
defensively already received them as `UnknownScreen` before this release.

**When they fire.** Both come from the native activity screen, but they are not
gated alike. `OtherUserPostsScreen` fires on the **ordinary** path — tapping
another member's avatar or name opens that member's activity, with no Unified
Profile involved, so you will receive it whether or not you wire
`onNavigateToProfile` (verified on device). `ActivityScreen` is the connected
user's own activity, which replaces `ProfileScreen` only once Unified Profile is
active — that one does require *both* the community to expose client user ids
*and* a host-wired `onNavigateToProfile` (new in this release, see below).

### Dependencies

Native Android 1.12.1 → 1.13.2, native iOS 1.12.6 → 1.13.2. Inherited with no
wrapper API change: 24 SDK languages (Arabic incl. RTL), large-screen content
width on tablets, the "View group" post-menu entry, and the community background
color applied on every native iOS screen. iOS additionally gains Xcode 27
compatibility — if you build with Xcode 27, this bump is required.

On Android, 1.13.2 changes what your own theme renders: the in-app browser now
follows the resolved Octopus color scheme instead of the device setting, a
translucent `background` or `primary` is dropped instead of being forwarded (it
used to render as a see-through toolbar), and the Material3 content colors
(`onBackground`, `onSurface`, `onSurfaceVariant`) follow the Octopus palette — so
a host that darkened `background` without redefining them will see labels that
were invisible appear, most visibly in the profile overflow menu.

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

// Or, ignoring the outcome — no behavioural change for fire-and-forget
// callers. This method is not `@useResult`, so the analyzer stays quiet; the
// explicit discard is a readability choice, not a requirement:
final _ = await octopus.overrideCommunityAccess(true);
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
> for the `switch` to be exhaustive: the analyzer builds the sealed subtype
> space from each subtype's declared **bound**, so the arm it wants is the
> `<OctopusServerError>` one, and naming the narrower leaf instead leaves the
> switch `non_exhaustive_switch_statement`. (The wide arm still matches a narrow
> instance at run time — Dart class generics are covariant.) The pattern binds
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
