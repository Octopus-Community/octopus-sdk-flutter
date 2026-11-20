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
- Use `minSdk 23` / `compileSdk 36` or later, with Android Gradle Plugin 8.9.1 or
  later (see the requirements table in the README).

#### Predictive back (Android 14+)

The native create-post screen (`OctopusCreatePostActivity`) opts in to predictive
back by itself. The home screen and embedded view run inside your host activity,
so opt in that activity in `android/app/src/main/AndroidManifest.xml` by adding
`android:enableOnBackInvokedCallback="true"` to its existing `<activity>` element
(usually `.MainActivity`, extending `FlutterFragmentActivity`).

With the host activity opted in, Flutter routes back through its predictive-back
support. Use `PopScope` for route back handling; legacy `WillPopScope` does not
support predictive back, so apps still using it have different gesture behavior.
See Flutter's "Android predictive back" migration guide for the migration to
`PopScope`.

### iOS

- Set the minimum deployment target to **14.0** in `ios/Podfile`:
  ```ruby
  platform :ios, '14.0'
  ```
- Enable **Swift Package Manager** with
  `flutter config --enable-swift-package-manager`. The plugin and its native
  dependencies resolve automatically — no Podfile step needed.
- On the **CocoaPods** path:
  - **Link frameworks statically.** The native Octopus UI pod looks up its
    images in its own resource bundle, which is only found with static
    frameworks: with Flutter's default (dynamic) frameworks the app crashes on
    the first Octopus screen (`Assets+Generated.swift` — `Fatal error`, image
    not found). Static is the only linkage the plugin's example app and the
    native SDK's CocoaPods validation app are built and tested with:
    ```ruby
    target 'Runner' do
      use_frameworks! :linkage => :static
      use_modular_headers!

      flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
    end
    ```
    (`use_modular_headers!` mirrors the example app and is optional for
    Octopus.) CocoaPods applies this setting to every pod of the target, so your other
    pods (Firebase, ad or push SDKs…) are linked statically too. If one of them
    cannot be, use the Swift Package Manager path above instead: it needs no
    linkage setting.
  - **gRPC conflict with Firebase Firestore** (or any other pod that depends on
    `gRPC-Core`), which fails the link with `Undefined symbol: grpc_…` /
    `gpr_…`: copy
    [`gRPC-Swift.podspec.json`](https://github.com/Octopus-Community/octopus-sdk-swift/blob/main/CocoaPodsValidationApp/gRPC-Swift.podspec.json)
    from the native SDK repository next to your `Podfile`, and add inside the
    `Runner` target:
    ```ruby
    pod 'gRPC-Swift', :podspec => 'gRPC-Swift.podspec.json'
    ```
    The `pod 'gRPC-Swift', :modular_headers => true` line older versions of
    this guide recommended does not fix this link error.
  - Then run `cd ios && pod install`.

## Signing your users in

Your app owns authentication through SSO. Start with `initialize` from the README
quickstart, then call `connectUser` with a token provider that obtains a JWT from
your backend. Wire `onNavigateToLogin` on `OctopusHomeScreen` to open your
app's login flow when an anonymous member performs an action that requires sign-in.

### Connect the signed-in user (SSO)

When your user logs into your app, call `connectUser` with its required
`tokenProvider`. The SDK calls it for the initial token and every subsequent
token request. Fetch a fresh JWT signed by your backend each time: SSO JWTs
expire, so returning a captured token will replay a stale JWT on refresh.
See the [migration guide](../MIGRATING.md#to-1160-from-115x) when upgrading
from 1.15.x.

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
    viewObjectButton: OctopusLocalizedText.autoTranslated('Read the article'),
    // Up to 10 images, local bytes or remote URLs, in display order.
    medias: [OctopusRemoteImageAttachment(article.coverUrl)],
  ),
);

result.onSuccess((post) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OctopusPostDetailsScreen(postId: post.id),
  ));
});
```

### Button labels per language

The label of the "view object" button, and of the call-to-action of a
prefilled post (`OctopusPostCTA.localized`), is an `OctopusLocalizedText`:

- `OctopusLocalizedText.autoTranslated(text)` — one label, which Octopus
  translates automatically for every reader;
- `OctopusLocalizedText.perLanguage(texts, defaultLanguage: ...)` — one label
  per language your app has, keyed by BCP-47 language tag (`'en'`, `'pt-BR'`,
  `'zh-Hant-TW'`). A reader whose language is in the list sees that label as
  is; any other reader sees an automatic translation of the default language's
  label.

```dart
ClientPost(
  objectId: article.id,
  text: article.title,
  viewObjectButton: OctopusLocalizedText.perLanguage({
    'en': 'Read the article',
    'fr': "Lire l'article",
    'pt-BR': 'Ler o artigo',
  }, defaultLanguage: 'en'),
)

OctopusPostCTA.localized(
  url: Uri.parse('myapp://article/42'),
  localizedLabel: OctopusLocalizedText.perLanguage({
    'en': 'Read',
    'fr': 'Lire',
  }, defaultLanguage: 'en'),
)
```

Give BCP-47 tags (`'en'`, `'pt-BR'`, `'zh-Hant-TW'`). The wrapper checks
nothing and sends the tags as you wrote them; the bridges only read an
underscore as a hyphen. The native SDK validates the label when it is used:
`fetchOrCreateClientObjectRelatedPost` when it sends the post,
`showOctopusCreatePostScreen` before the editor opens. When it refuses the
label, the call throws an `OctopusLocalizedTextValidationError` (an
`ArgumentError`) carrying a `kind` and, when it concerns one language, the
`languageCode` the native SDK built: no text (`emptyTexts`), a tag without a
language, `und` included (`emptyLanguage`), an empty or blank label (`blankText`), two tags of
the same language (`duplicateLanguage`), or a default language with no label
(`defaultLanguageMissing`). On the embedded `OctopusInitialScreen.createPost`
route, which returns nothing to Dart, a refused label drops the CTA instead.

Labels are taken when the post is created only: a post that already exists for
the `objectId` keeps its button. Keep each label under 28 characters so that it
fits on one line; a longer one wraps. Octopus groups the regions of one
language (`en-US`, `en-GB`), except for Chinese: give `zh-Hans` and `zh-Hant`
(or a region) apart. When your backend signs bridge posts, it signs the
language codes the native SDK sends: `language[-Script][-REGION]`, with Hebrew,
Indonesian and Yiddish under `he`, `id` and `yi`.

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
| `OctopusSDK.communityAccessDeniedReason` | `CommunityAccessDeniedReason?` — why the access is denied, `null` when granted or not known yet |
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
  `14.0` and run `cd ios && pod install --repo-update`.
- **iOS link fails with `Undefined symbol: grpc_…` / `gpr_…`** (CocoaPods, next
  to Firebase Firestore or another `gRPC-Core` user) — use the
  `gRPC-Swift.podspec.json` override described in
  [Platform setup](#platform-setup).
- **iOS crashes when the Octopus screen opens, in `Assets+Generated.swift`**
  (CocoaPods) — the pods are linked as dynamic frameworks; switch to
  `use_frameworks! :linkage => :static` (see [Platform setup](#platform-setup))
  or to the Swift Package Manager path.
- **"Invalid token" / authentication failures** — verify your API key and that
  your `tokenProvider` returns a valid, unexpired JWT signed with the shared
  secret. The SDK re-invokes it on every refresh (e.g. `refreshEntitlements()`).
- **The feed doesn't load** — check device connectivity and confirm the SDK was
  `initialize()`d before you connect a user or mount the screen.

More: [doc.octopuscommunity.com](https://doc.octopuscommunity.com).
