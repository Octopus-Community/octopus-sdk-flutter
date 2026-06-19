# Octopus SDK for Flutter

[![pub package](https://img.shields.io/pub/v/octopus_sdk_flutter.svg)](https://pub.dev/packages/octopus_sdk_flutter)
[![Android SDK](https://img.shields.io/badge/Android_SDK-1.12.0-34a853?logo=android&logoColor=white)](https://github.com/Octopus-Community/octopus-sdk-android)
[![iOS SDK](https://img.shields.io/badge/iOS_SDK-1.12.2-f05138?logo=apple&logoColor=white)](https://github.com/Octopus-Community/octopus-sdk-swift)

White-label social community SDK for Flutter — embed a fully moderated community feed, profiles, notifications and more directly inside your app, with your own branding.

📖 **Full documentation: [doc.octopuscommunity.com](https://doc.octopuscommunity.com/)** — the canonical, always-up-to-date integration guide. This README is a quick start; the documentation covers every API in depth and states each feature's availability per platform (iOS, Android, Flutter).

## Features

- 🧩 **Embedded community UI** — drop the `OctopusHomeScreen` widget anywhere in your widget tree
- 👤 **SSO user management** — connect / disconnect your own users with a signed JWT (token provider)
- 🎨 **Theming** — primary colors, font sizes, custom logo, light / dark mode
- 🧭 **Open a specific screen** — open straight onto a post, a group, or the post editor
- 🔀 **Multi-community** — switch the active community at runtime
- 🔗 **Bridges** — link your own content (articles, products…) to auto-created community posts, with live reaction / comment / view counts
- 🗂️ **Groups** — observe the community's groups and the user's follow state
- 🔔 **Push notifications** & an unseen-notifications **badge** stream
- 🧪 **A/B testing** — gate community access with a reactive stream
- 🌐 **URL interception** & **locale override**
- 📊 **Custom analytics** & a typed **SDK event stream**
- 🔌 **Custom API endpoint** — route SDK traffic to a custom host (`ApiServer`)

## Requirements

| Tool / platform | Minimum |
| --- | --- |
| Flutter | 3.10 |
| Dart | 3.0 |
| Android | `minSdk` 21, `compileSdk` 35 |
| iOS | 14.0 |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  octopus_sdk_flutter: ^1.12.0
```

Then run:

```bash
flutter pub get
```

### Android setup

1. Make your `MainActivity` extend `FlutterFragmentActivity` (required for the embedded UI):

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```

2. Target the right SDK levels in `android/app/build.gradle`:

   ```groovy
   android {
       compileSdk 35
       defaultConfig {
           minSdk 21
       }
   }
   ```

3. Add the internet permission to `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```

### iOS setup

Configure `ios/Podfile`:

```ruby
platform :ios, '14.0'

target 'Runner' do
  use_frameworks! :linkage => :static
  use_modular_headers!
  # ... flutter_install_all_ios_pods ...
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
```

Then install the pods:

```bash
cd ios && pod install
```

> **gRPC module conflict:** if `pod install` reports a duplicate `gRPC` module, keep `use_modular_headers!` (above), or add `pod 'gRPC-Swift', :modular_headers => true` to your `Podfile`.

## Quick start

```dart
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

final octopus = OctopusSDK();

// 1. Initialize as early as possible (SSO mode).
await octopus.initialize(
  apiKey: 'YOUR_API_KEY',
  // appManagedFields: [ProfileField.nickname, ProfileField.picture],
);

// 2. Connect your user. The token provider returns a signed JWT minted by your
//    backend (see "Generate a signed JWT for SSO" in the documentation).
await octopus.connectUserWithTokenProvider(
  userId: yourUserId,
  nickname: yourUserNickname,
  tokenProvider: () async => fetchOctopusTokenFromYourBackend(),
);

// 3. Display the community anywhere in your widget tree.
OctopusHomeScreen(
  onNavigateToLogin: () {
    // Launch your own login flow, then call connectUser*.
  },
  onModifyUser: (field) {
    // Open your own profile editor for the requested field.
  },
);

// 4. Disconnect on sign-out.
await octopus.disconnectUser();
```

→ Step-by-step guide: **[SDK Setup Guide](https://doc.octopuscommunity.com/SDK/sso?platform=flutter)**.

## New in 1.12.0

Custom API endpoint (`ApiServer`), multi-community `switchCommunity`, SDK lifecycle (`reset` / `stop` / `isInitialised`), the community `groups` stream, the connected-user `profile` stream, `setReaction` on any post, the Bridge post API (`fetchOrCreateClientObjectRelatedPost`, `getClientObjectRelatedPostFlow`, …), "open a specific screen" (`initialScreen`), the in-app post editor (`showOctopusCreatePostScreen`), and the `formatOctopusCompactCount` helper. See the [CHANGELOG](CHANGELOG.md) for the complete list and migration notes.

## Example app

A full demo lives in [`example/`](example) — initialization, SSO, theming, and feature scenarios. To run it you need a sandbox community: an **API key** and an **SSO JWT secret**.

```bash
cd example
flutter pub get
flutter run
```

## Documentation & support

- 📖 Integration guide: [doc.octopuscommunity.com](https://doc.octopuscommunity.com/)
- 🐙 Website: [octopuscommunity.com](https://www.octopuscommunity.com)
- 🐛 Issues: [github.com/Octopus-Community/octopus-sdk-flutter/issues](https://github.com/Octopus-Community/octopus-sdk-flutter/issues)

## License

Licensed under the Octopus Community Mobile SDK License Agreement — see [LICENSE](LICENSE).
