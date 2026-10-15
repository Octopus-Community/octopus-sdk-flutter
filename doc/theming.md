# Icon customization

Pass `OctopusTheme.icons` to `OctopusHomeScreen`, `OctopusHomeContent`, or
`OctopusSDK().showOctopusCreatePostScreen`. The reference is iOS `OctopusTheme.Assets.Icons`, with groups: `groups`, `content`, `gamification`, `settings`, `profile`,
`common` and `screenStates`. The bridge maps these onto Android's icon names.

Declare PNG images (or WebP with alpha for tinted icons) under `flutter: assets:` in your app's `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/icons/activity.png
    - assets/icons/heart.png
```

```dart
final activity = await OctopusIconSource.asset('assets/icons/activity.png');
final heart = await OctopusIconSource.asset('assets/icons/heart.png');
final theme = OctopusTheme(
  icons: OctopusIcons(
    common: OctopusCommonIcons(activityButton: activity),
    content: OctopusContentIcons(
      reaction: OctopusReactionIcons(heart: heart),
    ),
  ),
);
// Use theme: theme on your OctopusHomeScreen / OctopusHomeContent.
```

Load assets once before building the widget. `asset` reads the exact bundle key,
without selecting density variants; package assets use `packages/name/path`.
Missing assets propagate a Flutter loading error. You can also construct
`OctopusIconSource.bytes(bytes)` or `const OctopusIconSource.base64(encoded)`.
Raw base64 and base64 `data:` URI prefixes work on both platforms.
Flutter does not download images in the native bridge: fetch remote images in
your application and pass the resulting bytes. SVG and animation are unsupported.

All 72 slots are optional (69 single images and three on/off pairs). Omission
keeps the native default. `OctopusIconOnOff(on: ..., off: ...)` requires both
images; if either fails native decoding, the whole pair keeps its default.
Unreadable images are ignored independently. Start with a fresh `OctopusTheme`
to reset overrides; `copyWith` preserves fields when passed null.

Use small square images, ideally 24×24 points with about 14.5×14.5 points of
drawn content and transparent borders. Icons are tinted by the native theme;
tinted images need an alpha channel (PNG/WebP, not JPEG). All six
`content.reaction` images and the four `screenStates` illustrations keep their
original colors; JPEG is suitable for those untinted slots only.

Android downsamples glyphs to a maximum edge of 128 pixels, and illustrations
(`screenStates`, legacy empty slots, `gamification.rulesHeader` and the logo)
to 1024 pixels. Encoded sources over 12 MiB are rejected on Android. Failed
images, including allocation failures, keep their native defaults and log the
slot name. Use appropriately sized assets to avoid unnecessary loading costs.
Standalone post creation carries icon cache-file paths in its Intent; files are
removed on final dismissal or if launching the editor fails. Rotation preserves
them. The logo continues to use the existing theme transport.

`common.activityButton` is visible in place of the connected user's avatar when
Unified Profile is active. It does not activate Unified Profile itself.

Native rendering controls which slots are visible. In iOS 1.15.0,
`gamification.rulesHeader` is ignored by the native initializer, which uses
`badge` for that illustration. The bridge preserves that native behavior.
The five legacy empty slots remain in the public API. Android 1.15.0 and
iOS 1.15.0 render `screenStates.emptyContent` instead of
`content.post.emptyFeedInGroups`, `emptyFeedInCurrentUserProfile`,
`emptyFeedInOtherUserProfile` and `content.comment.emptyFeed`. They render
`screenStates.emptyNotifications` instead of `profile.emptyNotifications`.
Use `screenStates.networkError` and `screenStates.error` for first-load failures.
Android 1.15.0 does not render `addPollOption`, `deletePollOption` or
`common.checkbox` overrides.
`content.post.commentCount`, `viewCount`, and `moreReactions` are declared by
both SDKs but are not rendered by their screens at these pins. The iOS-only
`common.close` is outside this shared API.

In the sample, open **Theme → Preset 6 · Custom icons + activity + reactions**, then the
Community tab. **SDK default (no theme)** restores the default icon set.
