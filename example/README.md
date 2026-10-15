# Octopus SDK Flutter — Example app

A showcase of the `octopus_sdk_flutter` plugin. It opens directly on **Scenarios**,
with configuration available from Settings. An injected demo key starts the SDK
using the build host; a keyless build keeps the catalog browsable. The shell has
three tabs:

- **Scenarios** — a searchable list of one-tap scenario screens, each exercising one SDK capability.
- **Community** — the SDK UI, with an **In tab / Full screen** preference.
- **Settings** — Community summary, Account, Appearance, Language, Configuration,
  Developer tools, About and a separate Reset Configuration group. Appearance
  updates the sample and SDK together; the SDK language override is saved.
  Configuration edits are staged in collapsible sections until Apply.

Each card opens a detail screen with Back, Parameters or Try it, presets,
Execute, and Live state or Result. Member lookup also accepts a User ID.
Search matches scenario titles, descriptions and API names; all groups start
collapsed and collapse again after leaving the tab.

## Community navigation

**In tab** is the default. The SDK owns the feed and detail headers; switching
tabs preserves its native view. Re-tapping Community returns to the feed.
**Full screen** presents the whole native flow over the sample shell. Close it
with the SDK's Back button to return to the Community tab. The choice survives
restarts; changing it or re-targeting the SDK discards the previous navigation.
Reset Configuration restores In tab.
Profile and connection updates preserve the current native view and navigation.
Settings › Developer tools › Host app integration owns the navigation,
profile, sign-in, content, locked-group and link handling choices. Changes
are saved and apply immediately.
Link opening defaults to the native SDK. The Flutter bridge supports either
native handling of all links or host handling of all links. The Android sample's
selective contact-page rule is shown as unavailable because the bridge cannot
return a per-link decision to the native SDK.

Scenarios' **Open the community** card also offers Tab, Modal, Sheet and
Full screen shortcuts. Modal/Sheet/Full screen are separate demonstrations and
do not change the persistent preference.

A push tap closes any existing presentation, waits for SDK initialization,
then opens its target once. Post/profile notification links are forwarded to
the native SDK. The sample also accepts `group/<groupId>` and
`member/<OctopusProfileId>` links through the public group and member-activity
initial-screen APIs. Host login/profile-edit/profile callbacks push a host page
on the root navigator, preserving the SDK stack underneath. Back returns to the
same community screen that triggered the callback.

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

Pass your own API key (and a JWT issued by your backend — see
[the SSO docs](https://doc.octopuscommunity.com/backend/sso)):

```bash
flutter run \
  --dart-define=OCTOPUS_API_KEY=your_api_key \
  --dart-define=OCTOPUS_USER_ID=your_test_user_id \
  --dart-define=OCTOPUS_USER_TOKEN=your_jwt_token
```

The app still opens on Scenarios without a key. Settings shows that the SDK
has not started; Configuration remains available to supply a key.

### ⚠️ Server environment

The published `octopus_sdk_flutter` targets the **production** Octopus server
(`api.8pus.io`) and the SDK exposes no host setter — so this sample talks to
production by default. Every action (connect, follow, post) reaches a real
community. A build made with `--dart-define=OCTOPUS_INTERNAL=true` shows a
persistent red banner on every screen whenever the Config screen's server is
production (the default without `--dart-define=OCTOPUS_API_HOST=<host>`).
**Do not publish test content against a client community.**

Because of that default, a key pasted into the Config screen's `Custom…` field
is kept for the session only — it is never written to on-device storage. The
sample restores every other choice (key slot, user id, theme) on the next
launch, but a config that no longer resolves to a key is not auto-started.
It keeps the Scenarios shell browsable; open Settings → Configuration to
re-enter the key. On the `Custom…` source, **Apply** stays disabled until a
key is pasted. Apply starts the SDK or switches its community live, then
returns to the screen that opened Configuration on success. An initialization
failure stays on the form and points to Debug info. Builds that inject a key via `--dart-define`
auto-start their restored configuration.

The **Demo** server always uses the host injected into the current build by
`OCTOPUS_API_HOST`, or the SDK's production default when none is injected.
Switching Custom → Demo ignores the custom host and port. Saved Demo choices
follow the new build host after an app update; only Custom retains its typed
endpoint. Upgrades from the older default-as-Custom schema normalize matching
build hosts to Demo while retaining explicitly different custom endpoints.

The server and API key source are independent: changing the server preserves
the current key. When named keys are injected, Community offers **Demo** for
the generic `OCTOPUS_API_KEY` alongside the named keys and **Custom…**. A named
key takes effect only when selected explicitly.

**Reset Configuration** clears the saved local setup, stops the SDK and keeps
the sample shell open. Configuration then offers the build defaults; Apply or
the next launch can start them. Language, host integration and Community
navigation preferences return to their defaults. Nothing is deleted on the server.

## Scenarios

One row per `_ScenarioDescriptor` entry of the `_sections` list in
[`lib/scenarios/scenarios_screen.dart`](lib/scenarios/scenarios_screen.dart), grouped
and ordered the way the screen renders them — six collapsible sections (Sign-in &
user, Presentation modes, Community & groups, Notifications, Theme & language, Host
callbacks & events), each in source order. That list is the source of truth, so a new
scenario is added there and this table is re-derived from it, never extended by hand.
The `id` is the catalog scenario id and drives the card's accessibility identifier
`scenarios-<id>-card`, which is how an automated run reaches a scenario.

The `debugOverride*` controls are debug-only test affordances, not supported
public API. Their applied-preset state survives a Community round trip,
disconnect and user-session reset, matching the native overrides. It clears
when the SDK stops (including a Settings reset) or switches community.

The **Live community config** card shows masked key presence, Unified Profile,
terms acceptance, force login and account age. The Flutter config API does not
expose the Android panel's Post/Comment/Reply options, profile lock, gamification
or Powered by Octopus flag; unavailable values stay unknown rather than off.
Member lookup returns the community profile ID, message count and gamification
standing. The Flutter data model does not expose a member nickname.

| Scenario | Card `id` | SDK surface |
|---|---|---|
| Unified Profile | `unifiedProfile` | `onNavigateToProfile` + `debugOverrideExposeClientUserId` |
| Sign in and out as the demo user | `connection` | `connectUser` / `disconnectUser`; `connectionState` + `profile` streams (reads `OctopusProfile.entitlements`) |
| Read a member's community profile | `communityData` | `fetchCommunityData` / `communityDataFlow`, `OctopusProfile.clientUserId` |
| Lock the profile fields the host owns | `profileFieldsLock` | `debugOverrideProfileFieldsLock` + `ProfileFieldsLock` / `ProfileFieldLockState` |
| Change how members accept the terms | `termsAcceptance` | `debugOverrideTermsAcceptanceMode` + `TermsAcceptanceMode` |
| Choose a nickname before contributing | `forceNicknameChoice` | `debugOverrideForceNicknameChoice` + `common.clearText` |
| Customize consent wordings | `consentTexts` | `debugOverrideConsentTexts` + `OctopusConsentTexts` |
| Re-issue the demo user's entitlements | `refreshEntitlements` | `refreshEntitlements` + `profile` stream |
| Open the community on a chosen screen | `initialScreen` | `OctopusHomeScreen(initialScreen:)` with `OctopusInitialScreen.post` / `.group` / `.createPost`, `showOctopusHomeScreen`, `showOctopusCreatePostScreen`, standalone `OctopusPostDetailsScreen` |
| Open the community full screen | `fullscreen` | `OctopusHomeScreen` on a pushed route (what `showOctopusHomeScreen` does), `getOctopusNotification` |
| Open the community as a modal | `modal` | `OctopusHomeScreen` on a `fullscreenDialog` route — `navigationMode`, `navBarLeadingAction`, `getOctopusNotification` |
| Open the community as a bottom sheet | `sheet` | `OctopusHomeScreen` in a modal bottom sheet — `navigationMode`, `navBarLeadingAction`, `getOctopusNotification` |
| Browse the community's groups | `groups` | `fetchGroups`, `followGroup`, `unfollowGroup`, `groups` stream |
| Follow or unfollow every group at once | `syncFollowGroups` | `syncFollowGroups`, `fetchGroups`, `groups` stream |
| Grant or deny access to the community | `communityAccess` | `overrideCommunityAccess`, `hasAccessToCommunity` stream |
| Open the post attached to a product | `bridge` | `fetchOrCreateClientObjectRelatedPost`, `setNavigateToClientObjectCallback`, `setReaction`, `groups` stream |
| Start a post from the host app | `createPost` | `showOctopusCreatePostScreen` + `CreatePostScreenInfo` / `OctopusPrefilledPost` / `OctopusPostCTA`; reads the `groups` stream; `bridgeShareTokenProvider` for image posts in a picture-restricted community |
| React to a post from the host app | `reactions` | `setReaction(reaction, postId)` (react / change reaction / unreact); surfaces the concrete `OctopusConnectionFailure` subtype on failure |
| Change what members are allowed to post | `contentOptions` | `debugOverrideContentOptions` + `ContentOptions` / `PostOptions.textRequired` / `CommentOptions` / `ReplyOptions` |
| Handle a member reaching a closed group | `groupAccessDenied` | `setGroupAccessDeniedCallback` |
| Set the unread notification count | `notSeenNotifications` | `notSeenNotificationsCount` stream + `updateNotSeenNotificationsCount` |
| Open a post from a push notification | `pushNotifications` | `isOctopusNotification` / `getOctopusNotification` / `openNotification` |
| Switch the community's language | `locale` | `overrideDefaultLocale` |
| Apply the host's brand to the community | `theme` | custom `OctopusTheme` on the embedded UI |
| Send a custom analytics event | `customEvents` | `trackCustomEvent` |
| Restart or stop the SDK | `lifecycle` | `reset`, `stop`, `switchCommunity`; restart the retained configuration |
| Watch what the SDK reports | `events` | `events` stream (`OctopusEvent`) |
| Report which cohort the member is in | `trackABTests` | `trackCommunityAccess` |
| Force Octopus's own A/B decision | `forceOctopusABTests` | `overrideCommunityAccess` + `hasAccessToCommunity` stream |

The **Choose the SDK back button** link inside Full screen keeps the additional
`embeddedBack` demonstration reachable without adding a fifth presentation card.
Unified Profile wires the host callback and debug flag live, remounting the
community view instead of selecting an auth preset and restarting the SDK. The
switch forces the flag on when enabled; disabling it restores the backend value
and removes the host profile callback. **Backend flag override** lets QA force
the flag on or restore the server value independently of the callback.
Modal/Sheet/Full screen reuse the community routes. Sheet keeps its native
community toolbar on both platforms and dismisses through its drag handle or Back.

## Structure

```
example/lib/
├── main.dart                  # Entry point + app shell + push wiring
├── octopus_demo_config.dart   # --dart-define credentials + demo fixtures
├── app_state.dart             # Shared state (ChangeNotifier + InheritedNotifier)
├── branding.dart              # Brand theme + bundled-logo helper
├── config/                    # Settings configuration form screen
├── home/                      # Home dashboard
├── scenarios/                 # Scenarios list + one screen per scenario
├── community/                 # Embedded OctopusHomeScreen
├── settings/                  # Settings tab
├── auth/                      # Login + profile-edit pages
├── debug/                     # Events log screen, Debug console sheet + the SDK event / API-call recorder
└── widgets/                   # Shared scenario scaffold + cards
```

> **Debug is not a tab.** `main.dart` starts the recorder at launch
> unconditionally, so it captures every SDK event and every API call the
> sample makes from the first frame — nothing needs to be enabled. The
> recorded feed is read from Settings → "Developer tools"
> (`settings-devtools-entry`), which offers four entries:
>
> - **Host app integration** — enables the profile, profile editor, sign-in,
>   content and group-access host callbacks and selects URL handling.
> - **Events log** (`debug-open-button`) — a pushed screen
>   (`events-log-screen`) listing live SDK events, with a count
>   and copy / clear actions in the app bar
>   (`events-copy-log-button` / `debug-clear-button`).
> - **Debug info** (`debug-info-entry`) — the build and session facts a bug
>   report needs, copyable in one gesture (`debug-info-copy-button`).
>   Its SDK rows share the Settings status and include auth mode and community
>   access. SDK version and network reachability are marked unavailable because
>   the Flutter plugin does not expose them. Host integration names the profile
>   editor callback `onNavigateToProfileEdit` (`onModifyUser` in Flutter).
> - **Debug console** (`debug-console-entry`) — the merged SDK / host feed in a bottom
>   sheet (`debug-console-sheet`), with search and independent Event / State /
>   API Call filters (`debug-filter-select`), dismissed by dragging or with
>   `debug-console-close`.
>
> The Debug console is also one tap away from every tab root except
> Community (which shows the SDK's own bar): the bug icon in the top bar
> (`shell-debug-console-button`), mirroring the Android sample's top-bar
> action.
>
> All four ship in every build, including the published package.
>
> `debug/internal/` still exists, but only as a QA-tooling-compatibility
> entrypoint (`flutter run -t lib/debug/internal/main_debug.dart`, kept for
> tooling that launches it by path) — its own console-install call is redundant
> with the default entrypoint's and is the only part of `debug/` stripped from
> the published package.

## Push notifications

The shell registers the device push token and deep-links a tapped Octopus
notification into the Community tab — Firebase Messaging (FCM) on Android, the
native APNs bridge in `AppDelegate.swift` on iOS.
