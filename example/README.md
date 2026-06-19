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

### Octopus team — `scripts/run-sample.sh` (recommended)

The wrapper sources keys from pm-tools' centralized secrets file
(`<pm-tools>/shared/config/secrets.local.yaml` — the single source of truth
shared with the Android and React Native samples), signs a short-lived SSO JWT
with the SSO secret, and forwards everything to `flutter run`:

```bash
# from the repo root
scripts/run-sample.sh                # default device
scripts/run-sample.sh -d emulator-5562
```

One-time setup:

1. `git pull` your local `pm-tools` clone (the centralized template lands as
   `shared/config/secrets.local.yaml.example`).
2. `cp shared/config/secrets.local.yaml.example shared/config/secrets.local.yaml`
   and fill in the real keys (share via 1Password / Slack DM — never commit).

Overrides:

```bash
# Use a different key from the yaml as the primary
# (see the api_keys: names in secrets.local.yaml)
OCTOPUS_KEY_NAME=<A_KEY_NAME_FROM_SECRETS_YAML> \
  scripts/run-sample.sh

# pm-tools cloned elsewhere
PM_TOOLS_DIR=/elsewhere/pm-tools scripts/run-sample.sh

# Build instead of run
FLUTTER_CMD="build apk" scripts/run-sample.sh --debug
```

### Cold-clone consumers — manual `--dart-define`

External users don't have access to the team's pm-tools clone. Pass your own
key (and optionally a JWT issued by your backend for SSO mode — see
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
`--dart-define=OCTOPUS_SERVER=demo2`. **Do not publish test content against a
client community.**

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
└── widgets/                   # Shared scenario scaffold + cards
```

> Internal builds add a Debug console (live SDK event + API-call log) run via a
> dedicated entrypoint; it is stripped from the published package.

## Push notifications

The shell registers the device push token and deep-links a tapped Octopus
notification into the Community tab — Firebase Messaging (FCM) on Android, the
native APNs bridge in `AppDelegate.swift` on iOS.
