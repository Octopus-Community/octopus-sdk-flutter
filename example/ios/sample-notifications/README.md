# Sample .apns notification payloads for the iOS simulator

These payloads exercise `OctopusSDK.openNotification` end-to-end on the iOS simulator. Replace the `REPLACE_WITH_REAL_*` placeholders with IDs of content that exists in your Octopus community.

> Using `firebase_messaging` on iOS instead of the native APNs path documented below? See [`doc/push-notifications-with-firebase.md`](../../../doc/push-notifications-with-firebase.md). The `.apns` payloads in this folder still work for simulator testing via `xcrun simctl push` — they don't go through FCM.

## Required keys

The Octopus keys live inside a top-level `data` envelope (matches what the iOS native SDK looks at and what the Octopus backend sends through APNs):

```json
"data": {
  "is_octopus_notification": "true",
  "title": "...",
  "body": "...",
  "link_path": "post/{postId}"
}
```

Required inside `data`:
- `is_octopus_notification`: `"true"` (string, not bool — APNs custom values are JSON strings)
- `title`, `body`: notification copy mirrored in `aps.alert`
- `link_path`: e.g. `post/{postId}` or `post/{postId}?commentId={commentId}` or `post/{postId}?commentId={commentId}&replyId={replyId}`

Optional inside `data` for richer routing:
- `post_id`, `comment_id`, `reply_id`

Top-level (alongside `data`):
- `aps`: the standard APNs alert / sound / badge dict
- `Simulator Target Bundle`: consumed by `xcrun simctl push` to verify target app; stripped before delivery

> **Why `data`?** The iOS native SDK (`OctopusSDK.isAnOctopusNotification`) reads `userInfo["data"]` to find the Octopus keys. On Android, FCM's `RemoteMessage.data` already arrives unwrapped. The Flutter SDK's `OctopusNotification.fromMap` and `OctopusSDK.isOctopusNotification` accept **either** shape — they detect the `data` envelope automatically and also fall back to `aps.alert.title`/`body` for user-facing copy. The example app forwards the raw APNs `userInfo` to the SDK without any pre-processing.

## How to push

```bash
# Boot a simulator first (any device).
xcrun simctl boot "iPhone 15"  # or whichever you use

# Build + run the example app on it.
cd ../..    # back to example/
flutter run -d "iPhone 15"

# In another terminal, push a notification.
xcrun simctl push booted \
  com.octopuscommunity.sdk.flutter.sample \
  example/ios/sample-notifications/post.apns
```

Tap the banner to trigger `openNotification`. Watch the Flutter console for `[Push]` log lines.

## Tap vs foreground

- App in **foreground**: the AppDelegate presents the banner via `userNotificationCenter:willPresent`. Tapping it triggers `userNotificationCenter:didReceive` → forwarded to Dart as `notificationTapped`.
- App in **background** (home screen): tap the banner from the lock-screen / notification center → same `didReceive` path.
- App **killed / cold start**: tap the banner → app launches → `launchOptions[.remoteNotification]` carries the userInfo → Dart pulls it via `getInitialNotification` after the SDK is initialized.
