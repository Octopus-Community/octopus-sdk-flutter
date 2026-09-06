# Octopus SDK Flutter — Example app

A showcase of the `octopus_sdk_flutter` plugin. It opens on a **Config** screen,
then a bottom-navigation shell with four tabs:

- **Home** — a read-only dashboard (init status, connection, unseen count, community access).
- **Scenarios** — a searchable list of one-tap scenario screens, each exercising one SDK capability.
- **Community** — the embedded `OctopusHomeScreen`.
- **Settings** — login / edit profile / disconnect, language, server, "Back
  to Config" (non-destructive) / "Reset Configuration" (destructive, its own
  danger zone), the Debug console entry, and the app version.

Each scenario is driven by **preset buttons** (no free-text forms) and shows a
live result panel, so the effect of every SDK call is observable on screen.

## Running

### Android prerequisite — `google-services.json`

The sample wires Firebase Messaging for push, so the Google Services Gradle
plugin is applied and **every** Android build fails without a
`google-services.json`, push or no push:

```
Execution failed for task ':app:processDebugGoogleServices'.
> File google-services.json is missing.
```

The file is per-project and gitignored, so it cannot ship here. Download yours
from the Firebase Console (Project settings → Your apps → Android app) and drop
it at `example/android/app/google-services.json` — the same step
[`android/sample-notifications/README.md`](android/sample-notifications/README.md)
describes for the notification scenarios. iOS needs no equivalent: it uses the
native APNs bridge, not Firebase.

### Credentials

The sample reads its credentials from `--dart-define` at build time
(see `lib/octopus_demo_config.dart`) — **no key is ever committed to this repo**.

Pass your own API key (and, for SSO mode, a JWT issued by your backend — see
[the SSO docs](https://doc.octopuscommunity.com/backend/sso)):

```bash
flutter run \
  --dart-define=OCTOPUS_API_KEY=your_api_key \
  --dart-define=OCTOPUS_USER_ID=your_test_user_id \
  --dart-define=OCTOPUS_USER_TOKEN=your_jwt_token
```

The app still launches without a key — the Home tab simply reports an
initialization error.

### ⚠️ Server environment

The published `octopus_sdk_flutter` targets the **production** Octopus server
(`api.8pus.io`) and the SDK exposes no host setter — so this sample talks to
production by default. Every action (connect, follow, post) reaches a real
community. A persistent red banner warns about this on every screen. Internal QA
builds that swap in a demo/dev native SDK suppress the banner with
`--dart-define=OCTOPUS_API_HOST=<non-prod host>`. **Do not publish test content
against a client community.**

Because of that default, a key pasted into the Config screen's `Custom…` field
is kept for the session only — it is never written to on-device storage. The
sample restores every other choice (key slot, user id, theme) on the next
launch, but a config that no longer resolves to a key is not auto-started: it
lands back on the Config screen so the key is re-entered deliberately, in front
of the banner. On the `Custom…` source, Start stays disabled until a key is
pasted. A build shipping no key at all lands on that screen too, and on the
`Demo` source Start stays enabled there so a keyless clone can still explore
the app — Home then reports the initialization error described above. Builds that inject a key via
`--dart-define` are unaffected and still auto-start.

## Scenarios

One row per entry of the `_scenarios` descriptor list in
[`lib/scenarios/scenarios_screen.dart`](lib/scenarios/scenarios_screen.dart), in the
order the list renders them — that list is the source of truth, so a new scenario is
added there and this table is re-derived from it, never extended by hand. It holds the
catalog scenarios whose `platforms` include `flutter`. The `id` is the catalog scenario
id and drives the card's accessibility identifier `scenarios-<id>-card`, which is how
an automated run reaches a scenario.

| Scenario | Card `id` | SDK surface |
|---|---|---|
| Connection | `connection` | `connectUser` / `disconnectUser`; `connectionState` + `profile` streams (reads `OctopusProfile.entitlements`) |
| Sync Followed Groups | `syncFollowGroups` | `syncFollowGroups`, `fetchGroups`, `groups` stream |
| Custom Events | `customEvents` | `trackCustomEvent` |
| Locale | `locale` | `overrideDefaultLocale` |
| Theme | `theme` | custom `OctopusTheme` on the embedded UI |
| Bridge → Client Object | `bridge` | `fetchOrCreateClientObjectRelatedPost`, `setNavigateToClientObjectCallback`, `setReaction`, `groups` stream |
| Initial Screen | `initialScreen` | `OctopusHomeScreen(initialScreen:)` with `OctopusInitialScreen.post` / `.group` / `.createPost`, `showOctopusHomeScreen`, `showOctopusCreatePostScreen`, standalone `OctopusPostDetailsScreen` |
| Switch Community | `lifecycle` | `switchCommunity` |
| Refresh Entitlements | `refreshEntitlements` | `refreshEntitlements` + `profile` stream |
| Group Access Denied | `groupAccessDenied` | `setGroupAccessDeniedCallback` |
| Reactions | `reactions` | `setReaction(reaction, postId)` (react / change reaction / unreact); surfaces the concrete `OctopusConnectionFailure` subtype on failure |
| Create Post (Bridge Share) | `createPost` | `showOctopusCreatePostScreen` + `CreatePostScreenInfo` / `OctopusPrefilledPost` / `OctopusPostCTA`; reads the `groups` stream; `bridgeShareTokenProvider` for image posts in a picture-restricted community |
| Modal | `modal` | `OctopusHomeScreen` on a `fullscreenDialog` route — `navigationMode`, `navBarLeadingAction`, `getOctopusNotification` |
| Fullscreen | `fullscreen` | `OctopusHomeScreen` on a pushed route (what `showOctopusHomeScreen` does), `getOctopusNotification` |
| Sheet | `sheet` | `OctopusHomeScreen` in a modal bottom sheet — `navigationMode`, `navBarLeadingAction`, `getOctopusNotification` |
| Events Log | `events` | `events` stream (`OctopusEvent`) |
| Not-Seen Notifications | `notSeenNotifications` | `notSeenNotificationsCount` stream + `updateNotSeenNotificationsCount` |
| Push Notifications | `pushNotifications` | `isOctopusNotification` / `getOctopusNotification` / `openNotification` |
| Track A/B Tests | `trackABTests` | `trackCommunityAccess` |
| Force Octopus A/B Tests | `forceOctopusABTests` | `overrideCommunityAccess` + `hasAccessToCommunity` stream |
| Community Data (Unified Profile) | `communityData` | `fetchCommunityData` / `communityDataFlow`, `OctopusProfile.clientUserId` |

## Structure

```
example/lib/
├── main.dart                  # Entry point + app shell + push wiring
├── octopus_demo_config.dart   # --dart-define credentials + demo fixtures
├── app_state.dart             # Shared state (ChangeNotifier + InheritedNotifier)
├── branding.dart              # Brand theme + bundled-logo helper
├── config/                    # First-launch / reset Config screen
├── home/                      # Home dashboard
├── scenarios/                 # Scenarios list + one screen per scenario
├── community/                 # Embedded OctopusHomeScreen
├── settings/                  # Settings tab
├── auth/                      # Login + profile-edit pages
├── debug/                     # Debug console (modal) + the SDK event / API-call recorder
└── widgets/                   # Shared scenario scaffold + cards
```

> **Debug is not a tab.** `main.dart` starts the recorder at launch
> unconditionally, so it captures every SDK event and every API call the
> sample makes from the first frame — nothing needs to be enabled. The console
> itself is a modal sheet opened from Settings via "Open debug console"
> (`debug-open-button`), ships in every build including the published
> package, and offers copy / clear / close actions
> (`debug-copy-button` / `debug-clear-button` / `debug-close-button`).
>
> `debug/internal/` still exists, but only as a QA-tooling-compatibility
> entrypoint (`flutter run -t lib/debug/internal/main_debug.dart`, targeted by
> an internal QA launcher by path) — its own console-install call is redundant
> with the default entrypoint's and is the only part of `debug/` stripped from
> the published package.

## Push notifications

The shell registers the device push token and deep-links a tapped Octopus
notification into the Community tab — Firebase Messaging (FCM) on Android, the
native APNs bridge in `AppDelegate.swift` on iOS.
