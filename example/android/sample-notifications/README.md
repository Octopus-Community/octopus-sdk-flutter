# Android push notifications — example app testing

Sends FCM data-messages to the example app running on an Android emulator (or device). Uses Firebase Cloud Messaging via the HTTP v1 API.

## Prerequisites

1. **A Firebase project** with your Android app added.
   - Package name: `com.octopuscommunity.sdk.flutter.sample`
   - Download `google-services.json` from the Firebase Console → Project settings → Your apps → Android app.
   - Drop it into `example/android/app/google-services.json`. (It's gitignored.)
2. **Cloud Messaging API enabled** in Google Cloud Console for the same project (FCM HTTP v1 requires it).
3. **Service account key** with the `firebaseAdmin` or `Firebase Cloud Messaging Admin` role. Used to mint an OAuth bearer token for the HTTP v1 endpoint. Save the JSON locally — do NOT commit.

## One-time setup

```bash
cd example
flutter pub get
flutter run -d emulator-5554       # or your emulator id from `adb devices`
```

When the app launches, Android 13+ shows a notification permission prompt — **tap Allow**. Watch the Flutter console for:

```
[Push] FCM authorization status: AuthorizationStatus.authorized
[Push] FCM token received: <long-token-string>
[Push] FCM token registered with Octopus
```

Copy the token — that's what you'll target in the test push.

## Sending a test push

### Option A — Firebase Console (easiest)

1. Open Firebase Console → Cloud Messaging → New campaign → Notifications.
2. Set title + body (these show in the system tray banner and are mirrored into the Flutter SDK).
3. Target → Single device → paste the FCM token from above.
4. **Critical**: under "Additional options → Custom data", add these key/value pairs:
   - `is_octopus_notification` = `true`
   - `link_path` = `post/REAL_POST_ID` (or `post/REAL_POST_ID?commentId=REAL_COMMENT_ID` for a comment)
   - `post_id` = `REAL_POST_ID` (optional, but recommended)
   - `comment_id` = `REAL_COMMENT_ID` (optional)
5. Send. The emulator should show a system banner; tapping it opens the example, switches to the Community tab, and lands on the deep link.

### Option B — HTTP v1 API via curl

Replace `PROJECT_ID`, `OAUTH_TOKEN`, and `FCM_TOKEN`:

```bash
# 1) Get a bearer token from the service account JSON (one-liner via gcloud):
OAUTH_TOKEN=$(gcloud auth application-default print-access-token)

# 2) Send the push:
curl -X POST \
  -H "Authorization: Bearer $OAUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d @example/android/sample-notifications/post.json \
  https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send
```

`post.json` in this folder is a ready-to-edit template — replace the placeholder token and content IDs.

## Payload shape (FCM HTTP v1)

```json
{
  "message": {
    "token": "DEVICE_FCM_TOKEN",
    "notification": {
      "title": "New comment on your post",
      "body": "Someone commented — tap to see"
    },
    "data": {
      "is_octopus_notification": "true",
      "link_path": "post/POST_ID?commentId=COMMENT_ID",
      "post_id": "POST_ID",
      "comment_id": "COMMENT_ID"
    }
  }
}
```

- `notification.title` / `notification.body` populate the system tray banner.
  The example app merges them into the SDK payload (`OctopusNotification.title` / `body`) so they survive into in-app copy too — matches the iOS `aps.alert` convention.
- `data` carries the Octopus keys. All values must be **strings** (FCM HTTP v1 rejects nested objects/numbers in `data`).

## Behavior matrix

| Starting state | Push tap result |
|---|---|
| App in foreground | `onMessage` fires; in-app: tab switches to Community, embedded view opens at the deep link. **No system banner** (Android FCM never auto-shows for foreground apps). |
| App backgrounded | System tray banner shown by Android. Tap → `onMessageOpenedApp` fires → tab switches, embedded view opens deep-linked. |
| App killed | System tray banner shown by Android. Tap → app cold-starts, `getInitialMessage` drains the payload after SDK init, tab switches, embedded view opens deep-linked. |

## What you should see in the console

```
[Push] FCM foreground message: {is_octopus_notification: true, link_path: post/..., post_id: ...}
[Push] handling notification: {is_octopus_notification: true, link_path: post/..., title: ..., body: ...}
```

If you see `[Push] not an Octopus notification — ignoring`, double-check that `is_octopus_notification` is in the `data` field (not `notification`) and equals the **string** `"true"`.

If the SDK call succeeds but you don't land on the right post, verify `link_path` matches the format the Octopus iOS/Android native SDKs expect: `post/{postId}`, `post/{postId}?commentId={commentId}`, or `post/{postId}?commentId={commentId}&replyId={replyId}`.

## Cross-platform note

The same `link_path` syntax works on both Android and iOS. You can reuse this `post.json` payload's `data` block in your iOS `.apns` testing too (see `example/ios/sample-notifications/`).
