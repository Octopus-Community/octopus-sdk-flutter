# Octopus Community SDK for Flutter

[![pub package](https://img.shields.io/pub/v/octopus_sdk_flutter.svg)](https://pub.dev/packages/octopus_sdk_flutter)
[![Android SDK](https://img.shields.io/badge/Android%20SDK-1.12.0-3DDC84.svg)](https://github.com/Octopus-Community/octopus-sdk-android)
[![iOS SDK](https://img.shields.io/badge/iOS%20SDK-1.12.2-147EFB.svg)](https://github.com/Octopus-Community/octopus-sdk-swift)

Drop a fully moderated, white-label community — feed, posts, comments, reactions,
profiles, push, and analytics — into your Flutter app. The package wraps the
native [Android](https://github.com/Octopus-Community/octopus-sdk-android) and
[iOS](https://github.com/Octopus-Community/octopus-sdk-swift) Octopus SDKs behind
a single Dart API, so you write Flutter and ship a native community on both
platforms.

> Full guides, theming reference, backend setup, and the bridge cookbook live at
> **[doc.octopuscommunity.com](https://doc.octopuscommunity.com)**. This README
> is the 5-minute quick start.

## Requirements

| | Min |
|---|---|
| Flutter | 3.10 |
| Dart | 3.0 |
| Android | `minSdk` 21, `compileSdk` 35 |
| iOS | 14.0 |

You also need an Octopus **API key** for your community. Reach out to
[Octopus Community](https://www.octopuscommunity.com) to get one.

## Install

```yaml
dependencies:
  octopus_sdk_flutter: ^1.12.1
```

## Quick start

Pick the auth mode that matches your app:

- **SSO** — your backend already authenticates users and can mint a JWT for
  Octopus. Use [`initialize`](https://pub.dev/documentation/octopus_sdk_flutter/latest/)
  + [`connectUserWithTokenProvider`](https://pub.dev/documentation/octopus_sdk_flutter/latest/).
- **Octopus Auth** — let Octopus handle sign-in via magic-link email. Use
  [`initializeOctopusAuth`](https://pub.dev/documentation/octopus_sdk_flutter/latest/).

### 1. Initialize once at startup

```dart
import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OctopusSDK().initialize(apiKey: 'YOUR_OCTOPUS_API_KEY');
  runApp(const MyApp());
}
```

### 2. Embed the community screen

```dart
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return OctopusHomeScreen(
      navBarTitle: 'Community',
      onNavigateToLogin: () => Navigator.pushNamed(context, '/login'),
    );
  }
}
```

That is the full integration for an SSO host with anonymous browsing. Authenticated
users come next.

### 3. Connect the signed-in user (SSO)

When your user logs into your app, hand Octopus a JWT signed by your backend.
Use a **token provider** (not a static token) so the SDK can refresh the JWT
when entitlements change:

```dart
await OctopusSDK().connectUserWithTokenProvider(
  userId: currentUser.id,
  tokenProvider: () async => await myBackend.mintOctopusJwt(),
  nickname: currentUser.displayName,
);
```

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

The example app under `example/` demonstrates the full Firebase Messaging +
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

## Example app

A fully wired sample with theming, push, deep links, bridge mode, multi-community
switching, and all integration shapes (embedded / fullscreen / modal / bottom
sheet) lives under [`example/`](example/) in the repo.

## Resources

- Full documentation: [doc.octopuscommunity.com](https://doc.octopuscommunity.com)
- Migrating from earlier versions: [MIGRATING.md](MIGRATING.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Issues: [GitHub](https://github.com/Octopus-Community/octopus-sdk-flutter/issues)
- Native counterparts: [Android](https://github.com/Octopus-Community/octopus-sdk-android),
  [iOS](https://github.com/Octopus-Community/octopus-sdk-swift)

## License

Distributed under the **Octopus Community Mobile SDK License** — see
[LICENSE](LICENSE) for the full text.
