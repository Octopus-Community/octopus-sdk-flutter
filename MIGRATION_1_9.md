# How to migrate to 1.9.x

## Class & method renames

The main class and several methods have been renamed for consistency:

| 1.7.x | 1.9.x |
|-------|-------|
| `OctopusSdkFlutter` | `OctopusSDK` |
| `OctopusView` | `OctopusHomeScreen` |
| `initializeOctopusSDK()` | `initialize()` |
| `showOctopusView()` | `showOctopusHomeScreen()` |

**Before:**
```dart
final octopus = OctopusSdkFlutter();
await octopus.initializeOctopusSDK(apiKey: 'your-api-key');
octopus.showOctopusView(context, onNavigateToLogin: () { ... });
```

**After:**
```dart
final octopus = OctopusSDK();
await octopus.initialize(apiKey: 'your-api-key');
octopus.showOctopusHomeScreen(context, onNavigateToLogin: () { ... });
```

---

## `appManagedFields`: strings replaced by `ProfileField` enum

The `appManagedFields` parameter now uses the `ProfileField` enum instead of raw strings.

| 1.7.x (String) | 1.9.x (ProfileField) |
|-----------------|----------------------|
| `'NICKNAME'` | `ProfileField.nickname` |
| `'AVATAR'` | `ProfileField.picture` |
| `'BIO'` | `ProfileField.bio` |

**Before:**
```dart
await OctopusSdkFlutter().initializeOctopusSDK(
  apiKey: 'your-api-key',
  appManagedFields: ['NICKNAME', 'AVATAR', 'BIO'],
);
```

**After:**
```dart
await OctopusSDK().initialize(
  apiKey: 'your-api-key',
  appManagedFields: [ProfileField.nickname, ProfileField.picture, ProfileField.bio],
);
```

---

## `OctopusView` → `OctopusHomeScreen`

The widget has been renamed. Its constructor parameters are unchanged — `onNavigateToLogin`, `onModifyUser`, and `onBack` still work the same way.

**Before:**
```dart
OctopusView(
  navBarTitle: 'Community',
  onNavigateToLogin: () { /* ... */ },
  onModifyUser: (field) { /* ... */ },
  onBack: () => Navigator.pop(context),
)
```

**After:**
```dart
OctopusHomeScreen(
  navBarTitle: 'Community',
  onNavigateToLogin: () { /* ... */ },
  onModifyUser: (field) { /* ... */ },
  onBack: () => Navigator.pop(context),
)
```

---

## `embeddedView()`: callback parameters removed

If you were using `OctopusSdkFlutter.embeddedView()` directly (instead of the widget), the `onNavigateToLogin`, `onModifyUser`, and `onBack` callback parameters have been removed. Use `OctopusHomeScreen` widget instead, which handles callbacks via the event stream internally.

**Before:**
```dart
OctopusSdkFlutter.embeddedView(
  navBarTitle: 'Community',
  theme: myTheme,
  onNavigateToLogin: () { /* ... */ },
  onModifyUser: (field) { /* ... */ },
  onBack: () { /* ... */ },
)
```

**After:**
```dart
OctopusHomeScreen(
  navBarTitle: 'Community',
  theme: myTheme,
  onNavigateToLogin: () { /* ... */ },
  onModifyUser: (field) { /* ... */ },
  onBack: () { /* ... */ },
)
```

---

## Removed methods

| Removed | Replacement |
|---------|-------------|
| `showNativeUI()` | Use `showOctopusHomeScreen()` or embed `OctopusHomeScreen` widget |
| `closeNativeUI()` | No longer needed — dismiss the widget/route via standard Flutter navigation |

---

## New: URL interception (`onNavigateToUrl`)

`OctopusHomeScreen` and `showOctopusHomeScreen()` now support a new `onNavigateToUrl` callback to intercept URL taps inside the community UI.

```dart
OctopusHomeScreen(
  onNavigateToLogin: () { /* ... */ },
  onNavigateToUrl: (url) {
    // Return handledByApp if your app opens the URL itself
    // Return handledByOctopus to let the SDK open it in the browser
    if (url.contains('myapp.com')) {
      launchInApp(url);
      return UrlOpeningStrategy.handledByApp;
    }
    return UrlOpeningStrategy.handledByOctopus;
  },
)
```

---

## Quick find & replace checklist

Run these replacements across your Dart source files:

1. `OctopusSdkFlutter` → `OctopusSDK`
2. `OctopusView` → `OctopusHomeScreen`
3. `initializeOctopusSDK(` → `initialize(`
4. `showOctopusView(` → `showOctopusHomeScreen(`
5. `'NICKNAME'` → `ProfileField.nickname` (in `appManagedFields`)
6. `'AVATAR'` → `ProfileField.picture` (in `appManagedFields`)
7. `'BIO'` → `ProfileField.bio` (in `appManagedFields`)
8. Remove any calls to `showNativeUI()` / `closeNativeUI()`
9. If using `embeddedView()` directly, move to `OctopusHomeScreen` widget

The import stays the same:
```dart
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
```