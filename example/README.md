# Octopus SDK Flutter — Example app

A showcase of the `octopus_sdk_flutter` plugin. It opens on a **Config** screen,
then a bottom-navigation shell with four tabs:

- **Home** — a read-only dashboard (init status, connection, unseen count, community access).
- **Scenarios** — a searchable list of one-tap scenario screens, each exercising one SDK capability.
- **Community** — the embedded `OctopusHomeScreen`.
- **Settings** — login / edit profile / disconnect, language, server, reset.

Each scenario is driven by **preset buttons** (no free-text forms) and shows a
live result panel, so the effect of every SDK call is observable on screen.

## Running

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

The scenario set matches the cross-platform scenario catalog (the same `id`s and
element identifiers are used on Android / iOS / React Native):

| Scenario | SDK surface |
|---|---|
| Connection | `connectUser` / `disconnectUser` |
| Sync Followed Groups | `syncFollowGroups` (batch follow / unfollow) |
| Notifications | `updateNotSeenNotificationsCount` + `notSeenNotificationsCount` |
| Community Access | `overrideCommunityAccess` / `trackCommunityAccess` + `hasAccessToCommunity` |
| Custom Events | `trackCustomEvent` |
| Locale | `overrideDefaultLocale` |
| Theme | custom `OctopusTheme` on the embedded UI |

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
├── debug/                     # Debug tab + the SDK event / API-call recorder
└── widgets/                   # Shared scenario scaffold + cards
```

> The **Debug** tab is part of the app you are running: `main.dart` starts the
> recorder at launch, so it captures every SDK event and every API call the
> sample makes from the first frame. Nothing needs to be enabled.
>
> One debug surface does *not* ship — a console sheet reachable from Settings,
> installed by a separate internal entrypoint. It lives in `debug/internal/`,
> which is the only part of `debug/` stripped from the published package.

## Push notifications

The shell registers the device push token and deep-links a tapped Octopus
notification into the Community tab — Firebase Messaging (FCM) on Android, the
native APNs bridge in `AppDelegate.swift` on iOS.
