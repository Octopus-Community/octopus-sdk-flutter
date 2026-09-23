# Integration guide — octopus_sdk_flutter

The [README](../README.md) gets you from zero to an open community screen. This page is the
next step: platform setup in full, signing your users in, theming, presentation modes, the
bridge, push, the reactive streams and the less common APIs. Backend-side topics (JWT
signing, SSO, user management) live at [doc.octopuscommunity.com](https://doc.octopuscommunity.com).

Every snippet targets the latest published release of the package.

## Versioning

**What the version number means.** This package's `MAJOR.MINOR` always matches the
`MAJOR.MINOR` of the native SDKs it wraps — the native-SDK badges in the README. `^1.13.0` means
native 1.13 on *both* platforms. The patch digits move independently: the package
patches for its own fixes, and each native patches on its own cadence, so
Android 1.13.1 with iOS 1.13.2 under package 1.13.0 is normal. Read the badges for
the exact pins.

One consequence to plan for: because the minor tracks the natives, a **breaking
Dart change can arrive in a minor**. Every one is listed under `### Breaking` in
`CHANGELOG.md`, with a before/after section in `MIGRATING.md`.

## Platform setup

A couple of one-time native steps the embedded community UI needs. Full setup
guide (including Swift Package Manager): the
[setup guide](https://doc.octopuscommunity.com/SDK/sso/).

### Android

- **`MainActivity` must extend `FlutterFragmentActivity`** (not `FlutterActivity`) —
  the embedded community view depends on it:
  ```kotlin
  import io.flutter.embedding.android.FlutterFragmentActivity

  class MainActivity : FlutterFragmentActivity()
  ```
- Add the INTERNET permission in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  ```
- Keep `minSdk 21` / `compileSdk 35` (see the requirements table in the README).

### iOS

- Set the minimum deployment target to **14.0** in `ios/Podfile`:
  ```ruby
  platform :ios, '14.0'
  ```
- On **Swift Package Manager** (the default since Flutter 3.44) the plugin and
  its native dependencies resolve automatically — no Podfile step needed.
- On the **CocoaPods** path, run `cd ios && pod install`; if you hit a gRPC
  conflict, add `pod 'gRPC-Swift', :modular_headers => true` to your `Podfile`.

## Signing your users in

Pick the auth mode that matches your app. Both start from the `initialize` call shown in the
README quickstart (or `initializeOctopusAuth` for Octopus Auth).

- **SSO** — your backend already authenticates users and can mint a JWT for
  Octopus. Use [`initialize`](https://pub.dev/documentation/octopus_sdk_flutter/latest/)
  + [`connectUserWithTokenProvider`](https://pub.dev/documentation/octopus_sdk_flutter/latest/).
- **Octopus Auth** — let Octopus handle sign-in via magic-link email. Use
  [`initializeOctopusAuth`](https://pub.dev/documentation/octopus_sdk_flutter/latest/).

### Connect the signed-in user (SSO)

When your user logs into your app, hand Octopus a JWT signed by your backend.
Use a **token provider** (not a static token) so the SDK can refresh the JWT
when entitlements change:

```dart
final result = await OctopusSDK().connectUser(
  userId: currentUser.id,
  tokenProvider: () async => await myBackend.mintOctopusJwt(),
  nickname: currentUser.displayName,
);

switch (result) {
  case OctopusSuccess():
    // Connected. `connectionState` emits independently.
    break;
  case OctopusInvalidArguments<OctopusServerError>(:final errors):
    // The connection was refused — a banned user, a JWT the backend rejects,
    // a profile field it will not accept. Show it: this is the case where a
    // login screen otherwise looks like it did nothing.
    for (final error in errors.cast<ClientUserError>()) {
      switch (error) {
        case ClientUserBannedError():
          showBanned(error.errorMessage);
        default:
          showError(error.errorMessage);
      }
    }
  case OctopusConnectionFailure():
    showError('Could not reach Octopus.');
}
```

**On the `default` above.** That switch singles out one leaf, so it is
non-exhaustive and the `default` is required. Enumerate every leaf instead and
you have to drop it: `ClientUserError` is sealed, so the analyzer proves the
switch complete and a catch-all becomes a fatal warning.

You do not need one for robustness. The leaves are not symmetric across
platforms — some are only ever emitted on Android, others only on iOS — but the
set cannot grow under a running host: a wire error this version does not know
folds into `ClientUserOtherError`. A new leaf only ever arrives by upgrading
this package, called out in `CHANGELOG.md` and `MIGRATING.md`. The per-platform
table lives in the `ClientUserError` API docs.

On sign-out:

```dart
await OctopusSDK().disconnectUser();
```

## Theming

Override colors, fonts, logo, and forced light/dark mode via `OctopusTheme`:

```dart
OctopusHomeScreen(
  navBarTitle: 'Community',
  theme: OctopusTheme(
    primaryMain: const Color(0xFF6750A4),
    onPrimary: Colors.white,
    themeMode: OctopusThemeMode.dark, // omit to follow the device
    logoBase64: myLogoBase64,
  ),
  onNavigateToLogin: () => Navigator.pushNamed(context, '/login'),
)
```

## Presenting the community

`OctopusHomeScreen` works inline (in a tab, on a page), as a pushed route, or
as a modal. For the common one-liner, use the helper:

```dart
OctopusSDK().showOctopusHomeScreen(
  context,
  navBarTitle: 'Community',
  onNavigateToLogin: () => Navigator.pushNamed(context, '/login'),
);
```

Want to start the user directly on a post or group? Pass an `initialScreen`:

```dart
OctopusHomeScreen(
  initialScreen: OctopusInitialScreen.post(
    PostScreenInfo(postId: postId),
  ),
  // ...
)
```

There are also dedicated `OctopusPostDetailsScreen(postId:)` and
`OctopusGroupDetailsScreen(groupId:)` widgets for bridge-mode entry points.

To open a **member**, pass `OctopusInitialScreen.activity(...)` for their posts
(by your own `clientUserId`, or by their Octopus `profileId`) or
`OctopusInitialScreen.profile(clientUserId: ...)` for their profile — with the
id omitted, the latter opens the connected user's own editable profile. The
dedicated `OctopusProfileScreen(clientUserId:)` widget is the shorthand:

```dart
OctopusProfileScreen(clientUserId: member.id)
```

This is what a host that intercepts profile taps with `onNavigateToProfile`
uses to hand the user back to the SDK from its own profile page.

## Bridge: link your content to a discussion

If your app already has its own content (articles, products, events), the
**bridge** lets you attach a community discussion to each item. Call once,
get an `OctopusPost` back, then display its details:

```dart
final result = await OctopusSDK().fetchOrCreateClientObjectRelatedPost(
  ClientPost(
    objectId: article.id,
    text: article.title,
    catchPhrase: article.subtitle,
    viewObjectButtonText: 'Read the article',
  ),
);

result.onSuccess((post) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OctopusPostDetailsScreen(postId: post.id),
  ));
});
```

Wire the "view object" button so a tap returns to your article:

```dart
OctopusSDK.setNavigateToClientObjectCallback((objectId) {
  // Open your article/product screen for objectId
});
```

## Push notifications

Forward the device push token, and let the SDK tell you when a push is its own:

```dart
// 1. Register the token (FCM on Android, APNs on iOS)
await OctopusSDK().registerPushNotificationToken(token);

// 2. On payload received
if (OctopusSDK.isOctopusNotification(payload)) {
  final notification = OctopusSDK.getOctopusNotification(payload);
  if (notification != null) {
    OctopusSDK().openNotification(
      context,
      notification,
      onNavigateToLogin: () => Navigator.pushNamed(context, '/login'),
    );
  }
}
```

A step-by-step Firebase setup is in [push-notifications-with-firebase.md](push-notifications-with-firebase.md).
The example app under [`example/`](../example/) demonstrates the full Firebase Messaging +
local-notifications + APNs wiring on both platforms.

## Reactive state

The SDK exposes its world as Dart streams. Late subscribers get the latest
value replayed, so a widget mounting after `initialize()` does not miss it.

| Stream | Emits |
|---|---|
| `OctopusSDK.isInitialisedFlow` | `bool` — SDK initialized state |
| `OctopusSDK.connectionState` | `OctopusConnectionState` — connected / guest / not connected |
| `OctopusSDK.profile` | `OctopusProfile?` — current user, or `null` |
| `OctopusSDK.notSeenNotificationsCount` | `int` — unread badge count |
| `OctopusSDK.groups` | `List<OctopusGroup>` — community groups |
| `OctopusSDK.hasAccessToCommunity` | `bool` — A/B cohort flag |
| `OctopusSDK.events` | `OctopusEvent` — typed analytics-grade event stream |

Example: keep a badge updated.

```dart
StreamBuilder<int>(
  stream: OctopusSDK.notSeenNotificationsCount,
  builder: (context, snapshot) => Badge(
    label: Text('${snapshot.data ?? 0}'),
    child: const Icon(Icons.notifications),
  ),
)
```

## What else is in the box

Things you do not need on day one, but will probably want later — full
reference at [doc.octopuscommunity.com](https://doc.octopuscommunity.com):

- **Multi-community switching** — `OctopusSDK().switchCommunity(apiKey: ...)`
  swaps the SDK to another community at runtime. Pass `key: ValueKey(apiKey)`
  to your embedded widget so the native view rebuilds.
- **Reactions** — `OctopusSDK().setReaction(OctopusReactionKind.heart, postId)`
  (or `null` to remove).
- **Programmatic group follow / unfollow** — `followGroup`, `unfollowGroup`,
  `syncFollowGroups` for batched updates.
- **Locked groups** — `OctopusSDK.setGroupAccessDeniedCallback((groupId) { ... })`
  to show your own paywall when a user taps a group they cannot access.
- **Native create-post editor** — `OctopusSDK().showOctopusCreatePostScreen(...)`
  presents the platform-owned editor as a full-screen modal.
- **URL interception** — `onNavigateToUrl` on `OctopusHomeScreen` returns
  `UrlOpeningStrategy.handledByApp` or `.handledByOctopus`.
- **Locale override** — `OctopusSDK().overrideDefaultLocale(Locale('fr'))`.
- **Custom analytics** — `OctopusSDK().trackCustomEvent('purchase', { ... })`.
- **Refresh entitlements** — `OctopusSDK().refreshEntitlements()` re-mints the
  JWT via the registered token provider when your backend updates the user's
  community entitlements.
- **Compact count formatting** — `formatOctopusCompactCount(12340)` → `"12K"`,
  matching the SDK's own counters.

## Troubleshooting

- **The community screen is blank or crashes on Android** — make sure
  `MainActivity` extends `FlutterFragmentActivity` (see [Platform setup](#platform-setup)).
- **iOS build can't resolve the native pods** — set the deployment target to
  `14.0` and run `cd ios && pod install --repo-update`; on a gRPC naming
  conflict add `pod 'gRPC-Swift', :modular_headers => true`.
- **"Invalid token" / authentication failures** — verify your API key and that
  your `tokenProvider` returns a valid, unexpired JWT signed with the shared
  secret. The SDK re-invokes it on every refresh (e.g. `refreshEntitlements()`).
- **The feed doesn't load** — check device connectivity and confirm the SDK was
  `initialize()`d before you connect a user or mount the screen.

More: [doc.octopuscommunity.com](https://doc.octopuscommunity.com).
