# Push notifications with Firebase Messaging (iOS + Android)

This guide covers integrating Octopus push notifications when your app uses
[`firebase_messaging`](https://pub.dev/packages/firebase_messaging) on both
platforms. It is the recommended path when you want a single Dart code path
for push handling across iOS and Android.

If you prefer native iOS APNs handling instead (no Firebase on iOS), see the
example in `example/ios/Runner/AppDelegate.swift` plus
`example/lib/main.dart`'s `_pushChannel` plumbing.

---

## How Octopus delivers pushes

| Platform | Delivery path | Token Octopus needs |
|---|---|---|
| iOS | Octopus backend → Apple APNs → device | **APNs device token** (hex string) |
| Android | Octopus backend → Firebase Cloud Messaging → device | **FCM registration token** |

This is the key thing to get right. On iOS the Firebase SDK gives you both
an FCM token (`getToken()`) and an APNs token (`getAPNSToken()`). Octopus
wants the **APNs** one, because the Octopus backend sends to Apple's APNs
servers directly. Sending the FCM token to Octopus would silently produce
"registered" with no delivery.

On Android, FCM is the only path — `getToken()` is what you register.

---

## Prerequisites

### Firebase project setup

1. Add your app to the Firebase Console:
   - iOS bundle id: must match your `Info.plist` `CFBundleIdentifier`.
   - Android package name: must match your `applicationId` in `android/app/build.gradle.kts`.
2. **iOS only — upload an APNs Authentication Key** in Firebase Console:
   `Project settings → Cloud Messaging → Apple app configuration → APNs Authentication Key`. Without this, FCM cannot send to iOS devices (and Octopus pushes are unaffected because they go through APNs directly — but you still need it for any FCM-routed iOS pushes the Firebase SDK delivers).
3. Download config files:
   - `GoogleService-Info.plist` → drop into `ios/Runner/` (next to `Info.plist`)
   - `google-services.json` → drop into `android/app/`

### Xcode capabilities (iOS)

In Xcode → Runner target → Signing & Capabilities:

1. Add **Push Notifications**.
2. Add **Background Modes** and enable **Remote notifications**.

### Android manifest

Already configured by the `firebase_messaging` plugin's manifest merger. For
Android 13+ you must also declare the runtime permission in
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Gradle plugin

In `android/settings.gradle.kts`:

```kotlin
plugins {
    // ... existing plugins ...
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

In `android/app/build.gradle.kts`:

```kotlin
plugins {
    // ... existing plugins ...
    id("com.google.gms.google-services")
}
```

---

## `pubspec.yaml`

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  octopus_sdk_flutter: ^1.13.2
```

---

## Dart wiring

### 1. Initialize Firebase

In `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
```

Unlike the Android-only Firebase path in the example app, you do **not**
gate `Firebase.initializeApp()` by platform here — both platforms run it.

### 2. Request permission and register the token with Octopus

```dart
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

Future<void> setupOctopusPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission();
  if (settings.authorizationStatus != AuthorizationStatus.authorized &&
      settings.authorizationStatus != AuthorizationStatus.provisional) {
    return;
  }

  // Register the platform-specific token Octopus needs.
  await _registerToken(messaging);

  // The token rotates from time to time. Re-register on every refresh.
  messaging.onTokenRefresh.listen((_) => _registerToken(messaging));
}

Future<void> _registerToken(FirebaseMessaging messaging) async {
  final token = Platform.isIOS
      ? await messaging.getAPNSToken()
      : await messaging.getToken();

  if (token == null || token.isEmpty) return;
  await OctopusSDK().registerPushNotificationToken(token);
}
```

**Important:** `getAPNSToken()` returns `null` until Firebase has captured
the APNs registration callback. Call `requestPermission()` first and await
it. If you call `getAPNSToken()` immediately on app start before the system
has issued the APNs token, you'll get `null`. The `onTokenRefresh`
listener catches the eventual registration too, so you don't need to poll.

### 3. Handle taps and foreground messages

The handler is identical on both platforms because `RemoteMessage.data` is
already the unwrapped Octopus payload by the time Firebase Messaging surfaces
it.

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

void wireOctopusHandlers(BuildContext Function() contextProvider) {
  // Foreground: FCM does NOT auto-show a banner. Route into Octopus
  // immediately so the user lands on the deep-linked content.
  FirebaseMessaging.onMessage.listen((message) {
    _handle(message, contextProvider);
  });

  // Tap from background: the OS displayed the banner; the user tapped it.
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _handle(message, contextProvider);
  });

  // Cold start: the app was killed when the tap happened.
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handle(message, contextProvider);
  });
}

void _handle(RemoteMessage message, BuildContext Function() contextProvider) {
  // Merge the notification.title/body into the data payload so the typed
  // OctopusNotification carries user-facing copy too (the cross-platform
  // equivalent of iOS APNs' aps.alert convention).
  final payload = <String, Object?>{...message.data};
  final notif = message.notification;
  if (notif?.title != null) payload.putIfAbsent('title', () => notif!.title!);
  if (notif?.body != null) payload.putIfAbsent('body', () => notif!.body!);

  if (!OctopusSDK.isOctopusNotification(payload)) return;
  final notification = OctopusSDK.getOctopusNotification(payload);
  if (notification == null) return;

  final ctx = contextProvider();
  OctopusSDK().openNotification(
    ctx,
    notification,
    onNavigateToLogin: () => Navigator.of(ctx).pushNamed('/login'),
  );
}
```

Pass a `BuildContext Function()` (typically backed by a `GlobalKey<NavigatorState>`) so the handler can route navigation even when it fires before the widget tree is fully mounted (the cold-start case).

---

## Backend payload shape

Whichever push provider sends to your customers' devices — Octopus's own
backend (for Octopus-generated notifications) or your backend via FCM (for
your own pushes) — the `data` block must contain these Octopus keys:

```json
{
  "is_octopus_notification": "true",
  "link_path": "post/{postId}?commentId={commentId}",
  "post_id": "{postId}",
  "comment_id": "{commentId}"
}
```

The SDK's `OctopusSDK.isOctopusNotification(payload)` accepts both shapes:

- **Flat** — keys at the top level (Firebase Messaging on Android delivers
  this; some custom backends do too).
- **Nested under `data`** — keys inside a `data` envelope (raw iOS APNs
  payloads from the Octopus backend).

You do not need to pre-process the payload before handing it to the SDK.

For test payloads and FCM HTTP v1 templates, see:

- `example/android/sample-notifications/` — FCM HTTP v1 + Firebase Console flow
- `example/ios/sample-notifications/` — `xcrun simctl push` flow for the native iOS path

---

## Gotchas

### `getAPNSToken()` returns null on iOS simulator

iOS simulators (Xcode 11.4+) accept `.apns` files via `xcrun simctl push`,
but Firebase Messaging cannot deliver real FCM pushes to a simulator
because Apple doesn't issue a real APNs token there. `getAPNSToken()` may
return a synthetic value or `null`. For end-to-end simulator testing, use
`xcrun simctl push` with payload files (see
`example/ios/sample-notifications/`). For real FCM testing on iOS, use a
physical device.

### Don't mix the native AppDelegate MethodChannel path with Firebase on iOS

`firebase_messaging` swizzles `UIApplicationDelegate` methods to capture
APNs callbacks. If you also implement
`didRegisterForRemoteNotificationsWithDeviceToken` /
`didReceive:withCompletionHandler:` manually (the pattern in
`example/ios/Runner/AppDelegate.swift`), you'll either get duplicate event
delivery or miss events depending on swizzling order. **Pick one path per
platform.**

If you need to keep custom AppDelegate methods for non-push reasons, set
`FirebaseAppDelegateProxyEnabled = NO` in `Info.plist` and forward
`didRegisterForRemoteNotificationsWithDeviceToken` /
`didReceiveRemoteNotification` to Firebase Messaging manually. The
firebase_messaging README documents this.

### Token registration order

`OctopusSDK.registerPushNotificationToken(token)` requires no prior
`connectUser`. You can register the token while anonymous; Octopus will
associate it with the user when `connectUser` is later called. The SDK
also re-registers the token whenever the user changes, so calling
`registerPushNotificationToken` once at startup is enough.

### Background isolate handler

If you use `FirebaseMessaging.onBackgroundMessage` (a top-level Dart
isolate triggered when the app is killed and a data-only push arrives),
you cannot call `OctopusSDK.openNotification` from there — the SDK
needs a `BuildContext` and a live Flutter engine. Defer the routing to
`onMessageOpenedApp` / `getInitialMessage` once the user taps the banner.

---

## What changes vs. the example app's Android-only Firebase wiring

The example app gates `Firebase.initializeApp()` with
`if (Platform.isAndroid)` and keeps the native iOS AppDelegate
MethodChannel path. If you switch iOS to Firebase too:

1. Drop the platform gate — initialize Firebase on both platforms.
2. Drop `_pushChannel` and its handlers; the `FirebaseMessaging`
   streams replace them.
3. Remove the manual `didRegisterForRemoteNotificationsWithDeviceToken` /
   `didReceive` overrides in `AppDelegate.swift` so Firebase's swizzling
   has clean ownership.
4. Bundle `GoogleService-Info.plist` and enable Push Notifications +
   Background Modes (Remote notifications) in Xcode.

The Dart-side handler (`_handle` above) and the SDK calls remain the same.
