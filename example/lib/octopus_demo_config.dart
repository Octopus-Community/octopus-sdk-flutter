// Sample demo configuration (API key + SSO test user + demo fixtures).
//
// Committed on purpose and contains NO secret — it only declares compile-time
// constants read from `--dart-define`, mirroring how the iOS sample injects via
// `secrets.xcconfig` and the Android sample via `BuildConfig`. The source always
// compiles, with or without a key. No key is ever committed to this repo, and
// the public OSS mirror ships none (a cold-clone consumer brings their own).
//
// Real values are injected at build/run time and never committed. For
// local dev / QA, pass them via --dart-define:
//
//   flutter run \
//     --dart-define=OCTOPUS_API_KEY=<your demo API key> \
//     --dart-define=OCTOPUS_USER_ID=<a stable test user id> \
//     --dart-define=OCTOPUS_USER_TOKEN=<JWT signed with the SSO secret>
//
// When no key is provided the app still launches and navigates; the SDK simply
// reports an initialization error on the Home dashboard, which is the expected,
// observable state for a key-less clone.

/// Demo API key for the embedded community, injected at build time.
///
/// Empty by default — see [hasInjectedApiKey] for the "no key passed" state.
const String octopusApiKey = String.fromEnvironment(
  'OCTOPUS_API_KEY',
  defaultValue: '',
);

/// Hardcoded last-resort fallback for the demo user id.
///
/// `String.fromEnvironment`'s `defaultValue` only kicks in when the define
/// is *missing*; passing `--dart-define=OCTOPUS_USER_ID=` (empty string)
/// slips an empty value through, which would later trip the
/// `DemoConfig.userId` non-empty assert. Resolving to this constant when the
/// injected value is empty keeps the build-time seed always non-empty.
const String _kDefaultUserIdSeed = 'flutter-sample-user';

const String _injectedUserId = String.fromEnvironment(
  'OCTOPUS_USER_ID',
  defaultValue: _kDefaultUserIdSeed,
);

/// Stable identifier for the demo SSO user used by the Connection scenario.
///
/// Always non-empty — defaults to [_kDefaultUserIdSeed] when the build
/// passes no `--dart-define=OCTOPUS_USER_ID=…` or an explicit empty value.
/// (Compared against `''` rather than `.isEmpty` because getters on
/// `String` are not const-evaluable; the equality operator is.)
const String octopusUserId = _injectedUserId == ''
    ? _kDefaultUserIdSeed
    : _injectedUserId;

/// JWT for the demo SSO user, signed by the backend with the shared SSO secret.
///
/// Empty by default — the Connection scenario surfaces the resulting error in
/// its result panel when no token is injected.
const String octopusUserToken = String.fromEnvironment(
  'OCTOPUS_USER_TOKEN',
  defaultValue: '',
);

/// SSO `CLIENT_USER_TOKEN_SECRET` for the demo community, injected at build
/// time. **Demo-only** — production hosts should never ship the secret inside
/// the client binary; they should call a trusted backend route that returns
/// the bridge signature (the secret stays server-side).
///
/// Empty by default. When non-empty, `BridgeTokenSigner` (in
/// `lib/auth/bridge_token_signer.dart`) uses it to sign per-call bridge
/// fingerprints, mirroring iOS's `TokenProvider.getBridgeSignature` which
/// reads the same secret from `Bundle.main.infoDictionary`. It is injected
/// at build time via `--dart-define`.
const String octopusSsoClientUserTokenSecret = String.fromEnvironment(
  'OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET',
  defaultValue: '',
);

/// Whether a real API key was injected via `--dart-define`.
bool get hasInjectedApiKey => octopusApiKey.isNotEmpty;

/// Whether a real SSO user token was injected via `--dart-define`.
bool get hasInjectedUserToken => octopusUserToken.isNotEmpty;

/// Whether the demo SSO secret was injected — required to sign bridge-post
/// fingerprints in the Bridge → Client Object scenario. Empty (keyless /
/// public build) → bridge create-post calls return `invalidClientToken`
/// from the backend because the host-side `tokenProvider` cannot sign.
bool get hasInjectedSsoSecret => octopusSsoClientUserTokenSecret.isNotEmpty;

/// The server the bundled native SDK talks to, declared at build time.
///
/// Optional non-production API host, injected via
/// `--dart-define=OCTOPUS_API_HOST=…`. Empty (the default, and always the
/// case on the public build) → the SDK's built-in production host.
///
/// CRITICAL: the published `octopus-sdk` the plugin depends on targets
/// **production** (`api.8pus.io`) and exposes no host setter — the Flutter
/// sample therefore talks to PROD whenever this is empty, where every action
/// (connect, follow, post) hits real client communities. Fail-safe: assume
/// prod unless a build explicitly injects a non-production host here. The
/// value is environment-specific and never committed — no private host
/// literal lives in this file (`.github/sync/match.py`'s content guard
/// rejects the internal demo host/env name on sight; see that file's
/// "internal backend env / host" entry). A demo-by-default *experience* for
/// internal contributors is provided by `scripts/run-sample.sh` (not
/// mirrored), which already injects the demo host on every run unless
/// `OCTOPUS_API_HOST` is overridden — report 11 §F1's "démo sauf mention
/// contraire" intent is met there, not by a literal in this committed file.
const String octopusApiHost = String.fromEnvironment('OCTOPUS_API_HOST');

/// The published production host — the one the SDK falls back to when no
/// `ApiServer` is passed. A public literal (it is in the public docs), and the
/// only host literal this file may carry.
const String productionHost = 'api.8pus.io';

/// The host the Config screen's **Demo** server environment resolves to.
///
/// Same injected value as [octopusApiHost], surfaced under the name the UI
/// uses. Empty on a build that injects none (a bare `flutter run`, the public
/// mirror, a store build) — in which case Demo resolves to the SDK default,
/// i.e. production, and every label says so rather than pretending otherwise.
String get octopusDemoApiHost => octopusApiHost.trim();

/// Whether this build injected a demo host at all — gates the Config screen's
/// helper text, never the availability of the Demo option (which stays the
/// default so a fresh install can't land on Prod by omission).
bool get hasInjectedDemoHost => octopusDemoApiHost.isNotEmpty;

/// Whether the *build* carries no host opinion, so the SDK's production
/// fail-safe applies unless the runtime config says otherwise. The runtime
/// counterpart — which the production banner actually keys on now that the
/// environment is switchable — is `DemoConfig.pointsAtProduction`.
bool get octopusIsProdServer => octopusApiHost.trim().isEmpty;

/// Whether this build is an *internal* Octopus build, injected via
/// `--dart-define=OCTOPUS_INTERNAL=true` by internal run/QA tooling only.
/// Always `false` on a public clone and on the store builds (nothing injects
/// it there), which is the point: it gates internal-only affordances such as
/// the production warning banner without leaking anything into the mirrored
/// sources.
const bool octopusIsInternalBuild = bool.fromEnvironment('OCTOPUS_INTERNAL');

/// Whether the persistent production warning banner is shown (and the top
/// inset handed to it — `octopusDemoAppBuilder` keys its `MediaQuery` padding
/// removal on this same predicate, so keep the two in sync by construction).
///
/// The banner is an internal safety net ("you are about to test against
/// something real — don't post"), not part of the sample's product surface: a
/// client integrating the SDK nominally points it at production (or their own
/// host) with their own sandbox or production key, so for them the banner
/// would shout permanently on the only configuration they ever use. The API
/// key is opaque — there is no way to tell a sandbox key from a production
/// one client-side — so the gate is the build, not the key (decided
/// 2026-08-26): internal builds warn on the prod fail-safe path, everyone
/// else never sees it.
bool get octopusShowsServerWarning =>
    octopusIsInternalBuild && octopusIsProdServer;

/// A real post id on the demo community, injected via
/// `--dart-define=OCTOPUS_DEMO_POST_ID=…` (injected at build time by default).
///
/// Prefills the Initial-Screen scenario's "Post id" field so its post /
/// post-details presets are runnable out of the box. Empty (keyless / public
/// build) → the field starts blank and the presets explain what to plug in.
/// Environment-specific like the keys, hence injected rather than committed.
const String octopusDemoPostId = String.fromEnvironment(
  'OCTOPUS_DEMO_POST_ID',
  defaultValue: '',
);

/// Group NAME the Bridge → Client Object scenario resolves to a `groupId`
/// (by lookup in the live `OctopusSDK.groups` stream) for its random-recipe
/// preset, injected via `--dart-define=OCTOPUS_DEMO_BRIDGE_TOPIC=…`.
///
/// Defaults to `General` — present on the demo community (the iOS sample uses
/// `Gourmands`, which the demo community does not have; the lookup falls back
/// to `null` = community default group when the name doesn't match).
const String octopusDemoBridgeTopic = String.fromEnvironment(
  'OCTOPUS_DEMO_BRIDGE_TOPIC',
  defaultValue: 'General',
);

/// Whether a non-empty demo post id is configured (i.e. [octopusDemoPostId] was
/// injected by default; a keyless / public build leaves it empty).
bool get hasDemoPostId => octopusDemoPostId.isNotEmpty;

/// The post id the notification fixture references.
///
/// Falls back to a clearly-labelled placeholder when [octopusDemoPostId] is
/// empty, so the value is always a well-formed, non-empty id (a `link_path`
/// like `post/` would otherwise be malformed). The placeholder resolves to a
/// not-found post — the SDK handles the stale link gracefully.
String get demoOrPlaceholderPostId =>
    hasDemoPostId ? octopusDemoPostId : 'octopus-demo-post-id-unset';

/// A representative Octopus push-notification payload, shaped like the flat
/// `RemoteMessage.data` map an Android FCM push delivers (the nested iOS APNs
/// `userInfo` shape is also accepted by `OctopusNotification.fromMap`).
///
/// Lets the Not-seen-notifications scenario exercise the full push-tap code
/// path — `isOctopusNotification` → `getOctopusNotification` →
/// `openNotification` — without an actual push, which a simulator/emulator
/// cannot easily deliver. The `post_id` / `link_path` reference
/// [demoOrPlaceholderPostId]; with [octopusDemoPostId] injected the payload
/// deep-links to real content.
Map<String, String> get sampleOctopusNotificationPayload => {
  'is_octopus_notification': 'true',
  'title': 'New activity in the demo community',
  'body': 'Tap to open the post this notification points at.',
  'link_path': 'post/$demoOrPlaceholderPostId',
  'post_id': demoOrPlaceholderPostId,
};
