## 1.7.1
- Moving Android Octopus SDK to 1.7.2 (fixes Protobuf dependencies conflicts with Firebase)
- Moving iOS Octopus SDK to 1.7.2 (fixes Cocoapods package name conflicts between GRPC-Swift and GRPC-Core)

## 1.7.0
- First public release aligned with Octopus native SDK 1.7 on iOS and Android.
- Added SSO (`initializeOctopusSDK`)
- Added user session helpers: `connectUser`, `connectUserWithTokenProvider`, and `disconnectUser`.
- Introduced embedded `OctopusView` widget with callbacks for login navigation, profile edits, and back events.
- Added theme customization (colors, font sizz, logo, light/dark modes) passed through to the native UI.


