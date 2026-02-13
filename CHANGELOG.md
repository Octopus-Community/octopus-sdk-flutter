## 1.9.0

### New Features
- **Notification Badge Count**: `Stream<int> notSeenNotificationsCount` for reactive badge updates, `updateNotSeenNotificationsCount()` to force refresh
- **Community Access / A/B Testing**: `Stream<bool> hasAccessToCommunity` for reactive access state, `overrideCommunityAccess(bool)` to override cohort, `trackCommunityAccess(bool)` for analytics
- **URL Interception**: `onNavigateToUrl` callback on `OctopusHomeScreen` with `UrlOpeningStrategy` enum (`handledByApp` / `handledByOctopus`)
- **Locale Override**: `overrideDefaultLocale(Locale?)` to override the SDK UI language (e.g. `Locale('fr')`, `Locale('en', 'US')`, or `null` to reset)
- **Custom Analytics**: `trackCustomEvent(String name, Map<String, String> properties)` to send custom events to Octopus analytics
- **SDK Events**: `Stream<OctopusEvent> events` — typed event stream covering 20 event types (content creation/deletion, reactions, polls, gamification, screen navigation, clicks, profile changes, sessions). Use `OctopusSDK.events.listen(...)` with Dart pattern matching

### Breaking Changes

See MIGRATION_1_9.md for details

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


