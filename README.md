# Octopus Community SDK for Flutter

Embed a moderated, white-label social community — feed, groups, posts, comments, reactions,
profiles — in your Flutter app with one Dart API over the native Android and iOS SDKs.

[![pub package](https://img.shields.io/pub/v/octopus_sdk_flutter.svg)](https://pub.dev/packages/octopus_sdk_flutter)
[![Platforms](https://img.shields.io/badge/platforms-Android%2023%2B%20%7C%20iOS%2014%2B-blue.svg)](#requirements)
[![Android SDK](https://img.shields.io/badge/Android%20SDK-1.15.0-3DDC84.svg)](https://github.com/Octopus-Community/octopus-sdk-android)
[![iOS SDK](https://img.shields.io/badge/iOS%20SDK-1.15.0-147EFB.svg)](https://github.com/Octopus-Community/octopus-sdk-swift)
[![License](https://img.shields.io/badge/license-Octopus%20Mobile%20SDK-lightgrey.svg)](LICENSE)

<img src="https://raw.githubusercontent.com/Octopus-Community/octopus-sdk-android/main/docs/images/fullscreen.png" width="280" alt="The Octopus community feed, as rendered by the native Android SDK this package embeds">

## What you get

- **Native UI, not a webview.** The community screens are the native Android and iOS SDK views,
  embedded as Flutter widgets (`OctopusHomeScreen`) or presented as a route or modal.
- **Your brand.** `OctopusTheme` sets colors, fonts, logo and light/dark mode.
- **Nothing to host.** Octopus runs the back end, storage, moderation, engagement tools and
  analytics; you integrate the client.
- **Your users, your accounts.** Connect your signed-in users through SSO, with a JWT minted by
  your backend.
- **Wired into your app.** Push notifications, a typed event stream, and a bridge that attaches a
  community discussion to your own content (articles, products, events).

## Requirements

| Package | Flutter | Dart | Android | iOS | Native SDKs (Android · iOS) |
|---|---|---|---|---|---|
| 1.15.x | 3.44+ (tested 3.44.5) | 3.12+ | `minSdk` 23, `compileSdk` 35, Kotlin 2.1+, Android Gradle Plugin 8.6+ | 14.0+ | 1.15.0 · 1.15.0 |

On Android the plugin compiles with Kotlin 2.1.10 and a JVM target of 11; use Kotlin 2.1 or
later and Android Gradle Plugin 8.6 or later in your app. This repository's CI builds
and tests with Flutter 3.44.5 and its bundled Dart 3.12.2.

On iOS, enable Swift Package Manager with
`flutter config --enable-swift-package-manager`.

The package's `MAJOR.MINOR` tracks the native SDKs it wraps, so a breaking Dart change can land
in a minor release; each one is listed in [CHANGELOG.md](CHANGELOG.md) and
[MIGRATING.md](MIGRATING.md). Details: [Versioning](doc/integration-guide.md#versioning).

## Installation

```bash
flutter pub add octopus_sdk_flutter
```

or in `pubspec.yaml`:

```yaml
dependencies:
  octopus_sdk_flutter: ^1.15.0
```

Two one-time native steps: on Android, `MainActivity` must extend `FlutterFragmentActivity`
(not `FlutterActivity`); on iOS, set the deployment target to 14.0. Full list:
[Platform setup](doc/integration-guide.md#platform-setup).

## Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OctopusSDK().initialize(apiKey: 'YOUR_API_KEY');
  runApp(const MaterialApp(home: CommunityPage()));
}

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) => OctopusHomeScreen(
        navBarTitle: 'Community',
        onNavigateToLogin: () {/* open your login screen */},
      );
}
```

Users can browse anonymously from there. To connect your signed-in users (SSO), theme the UI or
wire push, follow the [integration guide](doc/integration-guide.md).

## Sample app

A full sample — every presentation mode, theming, push, deep links, the bridge, multi-community
switching — lives in [`example/`](example/):

```bash
git clone https://github.com/Octopus-Community/octopus-sdk-flutter.git
cd octopus-sdk-flutter/example
flutter run --dart-define=OCTOPUS_API_KEY=YOUR_API_KEY
```

Android builds also need your Firebase `google-services.json`; see
[example/README.md](example/README.md). To get an API key, request a sandbox key through the form
on [octopuscommunity.com](https://www.octopuscommunity.com) (also on the
[Getting Started](https://doc.octopuscommunity.com/getting_started/) page); it arrives within
24 hours.

## Links

- Documentation: [doc.octopuscommunity.com](https://doc.octopuscommunity.com)
- Integration guide: [doc/integration-guide.md](doc/integration-guide.md) ·
  push with Firebase: [doc/push-notifications-with-firebase.md](doc/push-notifications-with-firebase.md)
- API reference: [pub.dev](https://pub.dev/documentation/octopus_sdk_flutter/latest/)
- [CHANGELOG.md](CHANGELOG.md) · [MIGRATING.md](MIGRATING.md)
- Other Octopus SDKs: [Android](https://github.com/Octopus-Community/octopus-sdk-android) ·
  [iOS](https://github.com/Octopus-Community/octopus-sdk-swift) ·
  [React Native](https://github.com/Octopus-Community/octopus-sdk-react-native) ·
  [Unity](https://github.com/Octopus-Community/octopus-sdk-unity)
- Issues: [GitHub](https://github.com/Octopus-Community/octopus-sdk-flutter/issues)

## License

Distributed under the **Octopus Community Mobile SDK License** — see [LICENSE](LICENSE).

### Custom icons

Use `OctopusTheme.icons` to customize the native icon set, activity button and
reaction images. See the [icon customization guide](doc/theming.md) for Flutter
asset loading and examples.
