# Multi-Community Switch

This document describes the current procedure for switching between multiple Octopus communities within a single app session, along with constraints and platform-specific behaviors.

## Overview

Some apps need to support multiple Octopus communities (e.g. different brands, environments, or tenants). Since each community is identified by a unique API key, switching communities means re-initializing the SDK with a different API key.

There is **no dedicated "switch community" method**. The mechanism relies on calling the existing lifecycle methods in the correct order.

## Recommended Procedure

```dart
final octopus = OctopusSDK();

/// Switch from the current community to a new one.
Future<void> switchCommunity({
  required String newApiKey,
  required String userId,
  required String token,
  String? nickname,
  String? bio,
  String? picture,
  List<ProfileField>? appManagedFields,
}) async {
  // 1. Disconnect the current user
  await octopus.disconnectUser();

  // 2. Re-initialize with the new community's API key
  await octopus.initialize(
    apiKey: newApiKey,
    appManagedFields: appManagedFields,
  );

  // 3. Connect the user in the new community
  await octopus.connectUser(
    userId: userId,
    token: token,
    nickname: nickname,
    bio: bio,
    picture: picture,
  );
}
```

The three steps **must** be called in this exact order: `disconnectUser()` → `initialize()` → `connectUser()`.

## Step-by-Step Explanation

### 1. `disconnectUser()`

Logs out the current user from the current community. This clears user-specific state on the native side (session, profile data, cached content).

> **Why this step is required:** On Android, calling `initialize()` alone does **not** disconnect the previous user. Skipping this step may leave stale user state. On iOS, `initialize()` does call `disconnectUser()` internally as a safeguard, but relying on this is not recommended — always disconnect explicitly for consistent cross-platform behavior.

### 2. `initialize(apiKey: newApiKey)`

Re-initializes the native SDK with the new community's API key. This:

- Creates a new native SDK instance pointed at the new community
- Restarts internal reactive stream subscriptions (notification count, community access, SDK events)
- Cancels any in-flight native collection jobs from the previous community

### 3. `connectUser(...)`

Authenticates the user in the new community. The JWT token must be valid for the **new** community — tokens are community-specific.

## UI Considerations

After switching communities, the `OctopusHomeScreen` widget **must** be recreated. The embedded native view is bound to the community that was active when it was created.

Two approaches:

### Option A: Remove and re-add the widget

```dart
// Use a key to force widget recreation
int _communityVersion = 0;

Future<void> switchCommunity(String newApiKey) async {
  await octopus.disconnectUser();
  await octopus.initialize(apiKey: newApiKey);
  await octopus.connectUser(userId: userId, token: token);

  setState(() {
    _communityVersion++; // Forces OctopusHomeScreen to recreate
  });
}

// In build():
OctopusHomeScreen(
  key: ValueKey(_communityVersion),
  // ... other parameters
)
```

### Option B: Navigate away and back

```dart
Future<void> switchCommunity(String newApiKey) async {
  // Navigate away from the community screen
  Navigator.of(context).pop();

  await octopus.disconnectUser();
  await octopus.initialize(apiKey: newApiKey);
  await octopus.connectUser(userId: userId, token: token);

  // Navigate back to the community screen (creates a fresh widget)
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CommunityScreen()),
  );
}
```

## Reactive Streams Behavior

The reactive streams (`notSeenNotificationsCount`, `hasAccessToCommunity`, `events`) **persist across community switches**. They are backed by a single global `StreamController` that is never recreated.

After switching:

- **`notSeenNotificationsCount`**: Will emit the new community's count as soon as the native side sends it. Until then, a late subscriber may receive the **previous community's cached count**. This is a known limitation.
- **`hasAccessToCommunity`**: Same behavior — the cached value reflects the previous community until the new one emits.
- **`events`**: Will emit events from the new community. No cleanup is needed; old event subscriptions remain valid.

**Recommendation:** If your app displays notification counts or access state, reset your local UI state to a default value (e.g. `0` / `null`) immediately before calling `initialize()` with the new API key.

```dart
// Reset UI state before switching
setState(() {
  _notSeenCount = 0;
  _hasAccessToCommunity = null;
});

await octopus.disconnectUser();
await octopus.initialize(apiKey: newApiKey);
await octopus.connectUser(userId: userId, token: token);
```

## Constraints and Gotchas

### Must-know

1. **Always call `disconnectUser()` before `initialize()`** — skipping this step on Android leaves the previous user session active in the new community context.

2. **JWT tokens are community-specific** — a token generated for community A will not work for community B. Your backend must issue a new token for the target community.

3. **The `OctopusHomeScreen` widget must be recreated** — the embedded native view does not automatically refresh when the underlying community changes.

4. **`appManagedFields` can differ between communities** — you may pass different values to each `initialize()` call if the communities have different profile management configurations.

### Platform-specific behaviors

5. **iOS: automatic `disconnectUser()` on re-init** — the iOS plugin calls `disconnectUser()` on the previous instance when `initialize()` is called again. This is a safety net, not a contract. Always call `disconnectUser()` explicitly.

6. **Android: no automatic cleanup on re-init** — the Android plugin only cancels coroutine collection jobs. It does **not** call `disconnectUser()` on the previous instance. Forgetting to disconnect will cause undefined behavior.

### Edge cases

7. **Cached stream values may be stale** — after switching, `notSeenNotificationsCount` and `hasAccessToCommunity` may briefly return values from the previous community. Reset your UI state before switching.

8. **Concurrent `initialize()` calls** — calling `initialize()` while a previous call is still in progress is not guarded against. Ensure your app serializes community switches.

9. **Octopus Auth mode** — the same procedure applies when using `initializeOctopusAuth()` instead of `initialize()`. Replace the `initialize()` call with `initializeOctopusAuth(apiKey: newApiKey, deepLink: ...)`.

10. **`trackCustomEvent()` and `overrideCommunityAccess()`** — these calls apply to the **currently initialized** community. After switching, they automatically target the new community.

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

class MultiCommunityExample extends StatefulWidget {
  const MultiCommunityExample({super.key});

  @override
  State<MultiCommunityExample> createState() => _MultiCommunityExampleState();
}

class _MultiCommunityExampleState extends State<MultiCommunityExample> {
  final octopus = OctopusSDK();
  int _communityVersion = 0;
  String _currentCommunity = 'Community A';
  bool _isReady = false;
  int _notSeenCount = 0;

  // Your community API keys
  static const communities = {
    'Community A': 'api_key_community_a',
    'Community B': 'api_key_community_b',
  };

  @override
  void initState() {
    super.initState();
    OctopusSDK.notSeenNotificationsCount.listen((count) {
      if (mounted) setState(() => _notSeenCount = count);
    });
    _initCommunity('Community A');
  }

  Future<void> _initCommunity(String name) async {
    final apiKey = communities[name]!;

    setState(() {
      _isReady = false;
      _notSeenCount = 0; // Reset cached values
    });

    await octopus.initialize(apiKey: apiKey);
    await octopus.connectUser(
      userId: 'user_123',
      token: await _fetchToken(apiKey), // Your backend call
    );

    setState(() {
      _currentCommunity = name;
      _communityVersion++;
      _isReady = true;
    });
  }

  Future<void> _switchTo(String name) async {
    setState(() {
      _isReady = false;
      _notSeenCount = 0;
    });

    // 1. Disconnect from current community
    await octopus.disconnectUser();

    // 2. Initialize new community
    final apiKey = communities[name]!;
    await octopus.initialize(apiKey: apiKey);

    // 3. Connect user in new community
    await octopus.connectUser(
      userId: 'user_123',
      token: await _fetchToken(apiKey),
    );

    setState(() {
      _currentCommunity = name;
      _communityVersion++;
      _isReady = true;
    });
  }

  Future<String> _fetchToken(String apiKey) async {
    // Call your backend to get a JWT for the given community
    throw UnimplementedError('Replace with your backend call');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCommunity),
        actions: [
          PopupMenuButton<String>(
            onSelected: (name) {
              if (name != _currentCommunity) _switchTo(name);
            },
            itemBuilder: (_) => communities.keys
                .map((name) => PopupMenuItem(
                      value: name,
                      child: Text(name),
                    ))
                .toList(),
          ),
        ],
      ),
      body: _isReady
          ? OctopusHomeScreen(
              key: ValueKey(_communityVersion),
              navBarTitle: _currentCommunity,
              onNavigateToLogin: () {
                // Handle login
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
```

## Analytics

When tracking community switches in your own analytics, consider logging:

- The **source** community (the one being left)
- The **target** community (the one being joined)
- Whether the switch was **successful** or failed
- The **duration** of the switch (from `disconnectUser()` to the new `connectUser()` completing)

The SDK's built-in events (`SessionStartedEvent`, `SessionStoppedEvent`) will fire naturally as part of the disconnect/reconnect flow. Listen to `OctopusSDK.events` to capture these.

## Backward Compatibility

This document formalizes an existing, undocumented capability. The procedure described here works with SDK version 1.7.0 and later. No API changes were introduced — this relies entirely on existing public methods (`disconnectUser()`, `initialize()`, `connectUser()`).
