import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'auth/connect_user_result.dart';
import 'auth/demo_user_token_provider.dart';
import 'branding.dart';
import 'community/community_navigation.dart';
import 'config/api_key_registry.dart';
import 'config/host_integration.dart';
import 'feature_toggles.dart';
import 'octopus_demo_config.dart';
import 'sample_tab.dart';
import 'scenarios/debug_scenario_overrides.dart';
import 'update/sample_update_checker.dart';

/// Where the API key passed to the SDK comes from.
enum ApiKeySource {
  /// A key injected at build time via `--dart-define` — either the generic
  /// `OCTOPUS_API_KEY` or one of the named picker keys (see
  /// [DemoConfig.selectedInjectedKey]).
  demo,

  /// A key the developer pastes into the Config screen (consumer flow).
  custom,
}

/// Backend environment the SDK is pointed at, chosen on the Config screen.
///
/// A real runtime switch (not a label): [DemoConfig.resolvedHost] turns the
/// choice into the `ApiServer` handed to `initialize` / `switchCommunity`.
///
/// Enum order is the picker order. First launch keeps the build-injected
/// host; without one, it uses the native SDK default.
enum ServerEnv {
  /// The internal demo backend, whose host is injected at build time via
  /// `--dart-define=OCTOPUS_API_HOST` (never committed — see
  /// [octopusDemoApiHost]). A build that injects none resolves to the SDK
  /// default instead, which is production; that is why the label says so.
  demo,

  /// The published production backend — the SDK's own default host (no
  /// `ApiServer` passed).
  prod,

  /// A host typed on the Config screen (`DemoConfig.customHost`), for a
  /// backend feature env or a local gateway.
  custom,
}

extension ServerEnvX on ServerEnv {
  /// Section label on Config, Home and Settings.
  String get label => switch (this) {
    ServerEnv.demo => 'Demo',
    ServerEnv.prod => 'Prod',
    ServerEnv.custom => 'Custom',
  };
}

/// Material brightness chosen on the Config screen.
enum AppThemeChoice { system, light, dark }

extension AppThemeChoiceX on AppThemeChoice {
  /// Label shown by the Config / Appearance pickers and the Settings summary.
  String get label => switch (this) {
    AppThemeChoice.system => 'System',
    AppThemeChoice.light => 'Light',
    AppThemeChoice.dark => 'Dark',
  };
}

/// Scenarios → Sign-in & user → "Unified Profile (exposeClientUserId)"
/// override: keep the backend's value, or force the flag on locally through
/// `OctopusSDK.debugOverrideExposeClientUserId` (debug/demo-only API). Mirrors
/// the Android sample's `HostOverrides.exposeClientUserIdOverride` — same
/// place, same labels, applied live.
enum ExposeClientUserIdOverride { backend, forceOn }

extension ExposeClientUserIdOverrideX on ExposeClientUserIdOverride {
  /// The value handed to the SDK — `null` clears the override.
  bool? get enabled => switch (this) {
    ExposeClientUserIdOverride.backend => null,
    ExposeClientUserIdOverride.forceOn => true,
  };

  String get label => switch (this) {
    ExposeClientUserIdOverride.backend => 'Use backend value',
    ExposeClientUserIdOverride.forceOn => 'Force active',
  };

  /// Semantics identifier of the choice's button — the Android sample's
  /// `expose-override-*` test tags, so one QA script drives both.
  String get testId => switch (this) {
    ExposeClientUserIdOverride.backend => 'expose-override-backend',
    ExposeClientUserIdOverride.forceOn => 'expose-override-on',
  };
}

const sdkLocalePreferenceKey = 'sdk_locale_v1';

/// Locale override choice (Locale scenario + Settings language picker).
enum LocaleChoice { system, fr, en }

extension LocaleChoiceX on LocaleChoice {
  /// The Flutter [Locale] passed to `overrideDefaultLocale` (null = system).
  Locale? get locale => switch (this) {
    LocaleChoice.system => null,
    LocaleChoice.fr => const Locale('fr'),
    LocaleChoice.en => const Locale('en'),
  };

  String get label => switch (this) {
    LocaleChoice.system => 'System',
    LocaleChoice.fr => 'fr',
    LocaleChoice.en => 'en',
  };
}

/// Immutable choices edited in Settings and applied when starting the SDK.
class DemoConfig {
  final ApiKeySource apiKeySource;

  /// The key pasted on the Config screen for [ApiKeySource.custom].
  ///
  /// Session-scoped on purpose: deliberately NOT persisted (see [toJson]), so
  /// a relaunch can never re-enter the SDK with a key someone pasted once and
  /// forgot about.
  final String customApiKey;

  /// The named injected key picked on the Config screen, when the build
  /// carries the named-key set (see `config/api_key_registry.dart`). `null`
  /// on keyless / public builds (the generic `OCTOPUS_API_KEY` is used) and
  /// for [ApiKeySource.custom].
  final InjectedApiKey? selectedInjectedKey;

  /// SSO `sub` the Connection-scenario presets connect with — picked on the
  /// Config screen so two instances of the sample running side-by-side can
  /// hold distinct user identities (push-notification end-to-end QA between
  /// an iOS simulator and an Android emulator, for example). Always
  /// non-empty at construction time (enforced by the assert below); callers
  /// (the Config screen's `_effectiveUserId` and [fromJson]) back-fill
  /// empty input with the build-time `OCTOPUS_USER_ID` seed, which itself
  /// resolves to `'flutter-sample-user'` if the build passes no define or
  /// an empty define. Callers SHOULD also trim before construction (both
  /// known callers do); the assert can't verify it (const-ctor asserts
  /// can't call `.trim()`).
  final String userId;

  final AppThemeChoice theme;
  final ServerEnv serverEnv;

  /// Hostname for [ServerEnv.custom]; ignored by Demo and Prod.
  final String customHost;
  final int customPort;

  /// Current build's host. Never persisted: Demo follows the running build.
  final String buildHost;

  /// Which `OctopusTheme` the embedded SDK surface starts on (Config → Theme
  /// preset). `true` = the sample's Octopus-navy brand theme, `false` = the
  /// SDK's own default. A Theme scenario preset can still override it live.
  final bool octopusNavyTheme;

  /// The two sample feature toggles (`Force login`, `Push registration`).
  ///
  /// They are operated from the header of their Scenarios section and **nowhere else** —
  /// the Config screen deliberately carries no switch for them. They live on the persisted
  /// config rather than in transient screen state because a tester who turns push
  /// registration off expects it to still be off after a relaunch.
  final FeatureToggles featureToggles;

  const DemoConfig({
    required this.apiKeySource,
    this.customApiKey = '',
    this.selectedInjectedKey,
    required this.userId,
    required this.theme,
    required this.serverEnv,
    this.customHost = '',
    this.customPort = 443,
    this.buildHost = octopusApiHost,
    this.octopusNavyTheme = true,
    this.featureToggles = FeatureToggles.defaults,
  }) : // Const-ctor asserts cannot call methods (`.trim()` would compile-fail
       // for the `const DemoConfig(…)` round-trip tests), so this is the
       // practical guard: non-empty. Callers are responsible for trimming —
       // `_effectiveUserId` on the Config screen and `fromJson` here both
       // back-fill empty/whitespace input to [octopusUserId] before construction.
       assert(
         userId.length > 0,
         'userId must be non-empty — callers must back-fill empty input to '
         'the build-time seed before construction',
       );

  /// The API key actually handed to the SDK for this configuration.
  String get effectiveApiKey => switch (apiKeySource) {
    ApiKeySource.custom => customApiKey,
    ApiKeySource.demo => selectedInjectedKey?.key ?? octopusApiKey,
  };

  String get communityLabel =>
      selectedInjectedKey?.label ??
      (apiKeySource == ApiKeySource.custom
          ? 'Custom community'
          : 'Demo community');

  /// Where the key comes from (Home dashboard, Debug info) — the source
  /// kind, never a key label: the picked named key's label is already the
  /// "Community" row, so repeating it here said nothing about the source.
  String get apiKeyLabel => switch (apiKeySource) {
    ApiKeySource.custom => 'Custom',
    ApiKeySource.demo =>
      selectedInjectedKey != null
          ? 'Named key (--dart-define)'
          : (hasInjectedApiKey
                ? 'Demo (--dart-define)'
                : 'Demo (no key injected)'),
  };

  /// The host the SDK is actually routed to for this configuration — empty
  /// means "pass no `ApiServer`", i.e. the native SDK's own default host
  /// (production).
  ///
  /// Demo always uses [buildHost], even if a saved config carries an old
  /// custom host. Legacy Custom configs without a host also use the build.
  String get resolvedHost => switch (serverEnv) {
    ServerEnv.demo => buildHost.trim(),
    ServerEnv.prod => '',
    ServerEnv.custom =>
      customHost.trim().isNotEmpty ? customHost.trim() : buildHost.trim(),
  };

  /// The `ApiServer` to hand `initialize` / `switchCommunity` (`null` = the
  /// SDK's default production host).
  ApiServer? get apiServer => resolvedHost.isEmpty
      ? null
      : ApiServer(
          host: resolvedHost,
          port: serverEnv == ServerEnv.custom ? customPort : 443,
        );

  /// Human-readable host for the Home / Settings summary rows.
  String get hostLabel => resolvedHost.isEmpty
      ? '$productionHost (SDK default)'
      : (serverEnv == ServerEnv.custom && customPort != 443
            ? '$resolvedHost:$customPort'
            : resolvedHost);

  String get serverLabel => serverEnv == ServerEnv.demo && resolvedHost.isEmpty
      ? 'Demo (SDK default)'
      : serverEnv.label;

  /// Whether this configuration talks to the production backend — either
  /// explicitly, or by resolving to the SDK's default host. Drives the
  /// internal-build production banner, which must follow the runtime choice
  /// now that the environment is switchable.
  bool get pointsAtProduction =>
      resolvedHost.isEmpty || resolvedHost == productionHost;

  DemoConfig copyWith({
    ApiKeySource? apiKeySource,
    String? customApiKey,
    InjectedApiKey? selectedInjectedKey,
    bool clearSelectedInjectedKey = false,
    String? userId,
    AppThemeChoice? theme,
    ServerEnv? serverEnv,
    String? customHost,
    int? customPort,
    String? buildHost,
    bool? octopusNavyTheme,
    FeatureToggles? featureToggles,
  }) => DemoConfig(
    apiKeySource: apiKeySource ?? this.apiKeySource,
    customApiKey: customApiKey ?? this.customApiKey,
    selectedInjectedKey: clearSelectedInjectedKey
        ? null
        : (selectedInjectedKey ?? this.selectedInjectedKey),
    userId: userId ?? this.userId,
    theme: theme ?? this.theme,
    serverEnv: serverEnv ?? this.serverEnv,
    customHost: customHost ?? this.customHost,
    customPort: customPort ?? this.customPort,
    buildHost: buildHost ?? this.buildHost,
    octopusNavyTheme: octopusNavyTheme ?? this.octopusNavyTheme,
    featureToggles: featureToggles ?? this.featureToggles,
  );

  Brightness? get forcedBrightness => switch (theme) {
    AppThemeChoice.system => null,
    AppThemeChoice.light => Brightness.light,
    AppThemeChoice.dark => Brightness.dark,
  };

  /// Serialises the config for persistence (see [AppState.bootstrap]). The
  /// injected key is stored by its stable [InjectedApiKey.id] and re-resolved
  /// from the current build's [injectedApiKeys] on load — that key value is
  /// never persisted (it lives only in the build-time define).
  ///
  /// No key VALUE is written here, [customApiKey] included. A pasted key is
  /// the only way a production-valid key enters the sample, and the sample
  /// talks to PROD whenever the build injects no `OCTOPUS_API_HOST` (see
  /// [octopusApiHost]) — so persisting it would let every later launch
  /// re-enter a client-facing backend with that key, silently, without the
  /// user ever passing the Config screen or its production banner again. Only
  /// the SOURCE (`custom`) is kept, so Settings can restore every other choice
  /// while the shell stays browsable without starting the SDK.
  Map<String, dynamic> toJson() => {
    'apiKeySource': apiKeySource.name,
    'selectedInjectedKeyId': selectedInjectedKey?.id,
    'userId': userId,
    'theme': theme.name,
    'serverEnv': serverEnv.name,
    'customHost': serverEnv == ServerEnv.custom ? customHost : '',
    'customPort': customPort,
    'octopusNavyTheme': octopusNavyTheme,
    'featureToggles': featureToggles.toJson(),
  };

  /// Rebuilds a config from [toJson] output. Returns `null` on any schema
  /// mismatch (enum renamed, missing field) so a stale persisted blob can never
  /// crash startup — the shell falls back to build defaults.
  ///
  /// `userId` is back-filled from the build-time [octopusUserId] seed when
  /// missing (old blob written before the picker landed) or empty, so a
  /// pre-existing on-device config never blocks startup just because the
  /// new field isn't there yet.
  static DemoConfig? fromJson(
    Map<String, dynamic> json, {
    String buildHost = octopusApiHost,
  }) {
    try {
      final injectedId = json['selectedInjectedKeyId'] as String?;
      InjectedApiKey? injected;
      for (final k in injectedApiKeys) {
        if (k.id == injectedId) {
          injected = k;
          break;
        }
      }
      // An injected key that disappeared must not silently select another
      // community. Restore the build defaults instead.
      if (injectedId != null && injected == null) return null;
      final rawUserId = (json['userId'] as String?)?.trim() ?? '';
      final resolvedUserId = rawUserId.isEmpty ? octopusUserId : rawUserId;
      var serverEnv = ServerEnv.values.byName(json['serverEnv'] as String);
      final customHost = (json['customHost'] as String?)?.trim() ?? '';
      // Older builds saved the initial host as Custom; #492 could re-save it
      // with port 443 before migration. Retain other hosts and non-default ports.
      if (serverEnv == ServerEnv.custom &&
          (customHost.isEmpty ||
              ((json['customPort'] == null || json['customPort'] == 443) &&
                  buildHost.trim().isNotEmpty &&
                  buildHost.trim() != productionHost &&
                  customHost == buildHost.trim()))) {
        serverEnv = ServerEnv.demo;
      }
      return DemoConfig(
        apiKeySource: ApiKeySource.values.byName(
          json['apiKeySource'] as String,
        ),
        // Never restored: no key value is persisted (see [toJson]). A blob
        // written by an older build still carries one — ignored here on
        // purpose, and stripped from storage by [loadPersistedDemoConfig].
        customApiKey: '',
        selectedInjectedKey: injected,
        userId: resolvedUserId,
        theme: AppThemeChoice.values.byName(json['theme'] as String),
        serverEnv: serverEnv,
        // Both fields post-date the first schema, so a blob written by an
        // older build carries neither — read them leniently rather than
        // sending the whole config back to the Config screen over a field
        // whose absence has a perfectly good default.
        customHost: serverEnv == ServerEnv.custom ? customHost : '',
        customPort: json['customPort'] as int? ?? 443,
        buildHost: buildHost,
        // `octopusNavyTheme` was `octopusTealTheme` before the navy rollout —
        // a blob written by a pre-rename build still carries the old key, and
        // reading only the new one would silently reset an existing "SDK
        // default" (`false`) choice back to the navy default. Fall back to
        // the pre-navy key before the hardcoded default.
        octopusNavyTheme:
            json['octopusNavyTheme'] as bool? ??
            json['octopusTealTheme'] as bool? ??
            true,
        // Absent from every blob written before this landed; the defaults are
        // deliberate (force-login off, push-registration on), so read leniently.
        featureToggles: FeatureToggles.fromJson(
          (json['featureToggles'] as Map?)?.cast<String, Object?>(),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// SharedPreferences key for the persisted [DemoConfig] (versioned so a future
/// schema change can bump it without colliding with stale blobs).
///
/// Visible to the tests because what matters about [loadPersistedDemoConfig] is
/// what it leaves *in* storage, which can only be asserted on the raw blob.
@visibleForTesting
const String demoConfigPrefsKey = 'octopus_demo_config_v1';

/// Reads the raw persisted blob, or `null` when storage itself is unavailable.
///
/// Separate from the parsing below so the two failures stay distinguishable:
/// only an unreadable *blob* justifies clearing what is on disk. A prefs
/// failure read nothing, so there is nothing to judge — clearing there would
/// throw away a valid config over a transient error.
Future<String?> _readPersistedConfigBlob() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(demoConfigPrefsKey);
  } catch (_) {
    return null;
  }
}

/// Loads the persisted [DemoConfig] (null if none / corrupt / schema drift).
///
/// Also self-heals a blob written by an older build, which stored the pasted
/// `customApiKey` verbatim: the config is re-persisted through the current
/// [DemoConfig.toJson], which carries no key value, so the plaintext key stops
/// sitting in on-device prefs on the first launch after this change. A blob
/// this build can't parse is dropped instead of left in place — it sends the
/// app back to its build defaults either way, so keeping it buys nothing and it
/// may still hold that plaintext key.
///
/// A top-level function rather than a method on [AppState]: that strip is the
/// security-relevant half of the change, and reaching it through [AppState]
/// would mean standing up the SDK singleton and its channels just to assert on
/// a prefs entry — so it would have shipped untested.
@visibleForTesting
Future<DemoConfig?> loadPersistedDemoConfig({
  String buildHost = octopusApiHost,
}) async {
  await _configWrites;
  final raw = await _readPersistedConfigBlob();
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final restored = DemoConfig.fromJson(json, buildHost: buildHost);
    if (restored == null) {
      await _clearPersistedDemoConfig();
      return null;
    }
    if (json.containsKey('customApiKey') ||
        json['serverEnv'] != restored.serverEnv.name ||
        (json['customHost'] ?? '') != restored.customHost) {
      await _persistDemoConfig(restored);
    }
    return restored;
  } catch (_) {
    await _clearPersistedDemoConfig();
    return null;
  }
}

/// Persists [config] so the next launch auto-restores it. Best-effort: a
/// storage failure logs but never blocks the run.
Future<void>? _configWrites;

Future<void> _persistDemoConfig(DemoConfig config) {
  final write = (_configWrites ?? Future<void>.value()).then(
    (_) => _writeDemoConfig(config),
  );
  _configWrites = write;
  // Keep only pending work; a completed queue must not retain an old zone.
  unawaited(
    write.whenComplete(() {
      if (identical(_configWrites, write)) _configWrites = null;
    }),
  );
  return write;
}

Future<void> _writeDemoConfig(DemoConfig config) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      demoConfigPrefsKey,
      jsonEncode(config.toJson()),
    )) {
      demoLog.note('Configuration could not be saved');
    }
  } catch (e) {
    demoLog.apiCall('persistConfig failed', {'error': '$e'});
  }
}

/// Clears the persisted config (Settings → Reset → build defaults).
Future<void> _clearPersistedDemoConfig() async {
  await _configWrites;
  await _removeSamplePreference(demoConfigPrefsKey);
}

Future<void> _removeSamplePreference(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key)) {
      demoLog.note('Preference could not be cleared', {'preference': key});
    }
  } catch (e) {
    demoLog.note('Preference clear failed', {'preference': key, 'error': '$e'});
  }
}

/// First-launch choices use the build's host, including the SDK default.
DemoConfig buildInitialDemoConfig({
  required String host,
  required String userId,
}) => DemoConfig(
  apiKeySource: ApiKeySource.demo,
  userId: userId,
  theme: AppThemeChoice.system,
  serverEnv: host.trim().isEmpty
      ? ServerEnv.prod
      : host.trim() == productionHost
      ? ServerEnv.custom
      : ServerEnv.demo,
  customHost: host.trim() == productionHost ? host.trim() : '',
  buildHost: host.trim(),
);

/// Host profile values from the last successful connection, separate from drafts.
typedef ConnectedDemoProfile = ({
  String userId,
  String? nickname,
  String? bio,
  String? picture,
});

const _hostProfilePrefsPrefix = 'octopus_host_profile_v1:';

/// Shared, reactive app state for the whole sample.
///
/// A plain [ChangeNotifier] (a Flutter foundation type — no state-management
/// package) surfaced to the widget tree through [AppScope]. Owns the single
/// [OctopusSDK] instance, the chosen [DemoConfig], init/connection status, and
/// the SDK stream values that the Home dashboard and scenario result panels
/// read.
class AppState extends ChangeNotifier {
  AppState({DemoConfig? buildConfig})
    : _buildConfig =
          buildConfig ??
          buildInitialDemoConfig(host: octopusApiHost, userId: octopusUserId);

  final DemoConfig _buildConfig;
  final OctopusSDK octopus = OctopusSDK();
  bool _disposed = false;

  DemoConfig? _config;
  DemoConfig? get config => _config;

  /// Choices remain editable before initialization and after a Settings reset.
  DemoConfig get configurationChoices => _config ?? _buildConfig;

  /// True while [bootstrap] restores the shell's configuration choices.
  bool _restoringConfig = true;
  bool get restoringConfig => _restoringConfig;

  /// Non-secret choices loaded at bootstrap, also available through [config]
  /// when their API key was not persisted and the SDK cannot auto-start.
  DemoConfig? _restoredConfig;
  DemoConfig? get restoredConfig => _restoredConfig;

  /// API key of the last initialized community, retained while stopped so
  /// Restart can target the same community. UI must hide it while stopped.
  ///
  /// Distinct from [DemoConfig.effectiveApiKey] (which captures the user's
  /// initial Config-screen choice — a SOURCE, not a value). This field
  /// survives [switchToCommunity] so the rest of the sample can always tell
  /// which community the SDK is actually talking to right now.
  String? _activeApiKey;
  String? get activeApiKey => _activeApiKey;
  ApiServer? _activeApiServer;

  bool _bootstrapped = false;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _stopped = false;
  bool get stopped => _stopped;

  String? _initError;
  String? get initError => _initError;

  /// Whether a real (non-guest) user is currently connected to the SDK.
  ///
  /// Derived from [connectionState] (the reactive stream the native SDK
  /// publishes). Was previously a manually-maintained mirror, but that
  /// could drift if the SDK disconnected the user without going through
  /// [disconnectUser] (token expiry, force-logout). Now always reflects
  /// the latest emission from `OctopusSDK.connectionState`.
  ///
  /// **Excludes guests.** On a forced-login community (and on a non-prod
  /// backend), the
  /// SDK auto-establishes an anonymous *guest* session right after
  /// [disconnectUser] — emitted as `OctopusConnected(isGuest: true)`. A plain
  /// `is OctopusConnected` check would treat that guest as "connected" and the
  /// disconnect would look like a no-op in the UI. We therefore exclude guests,
  /// matching `OctopusSDK.isUserConnected` (`state is OctopusConnected &&
  /// !state.isGuest`). The guest flag is reported on both platforms (iOS via
  /// `OctopusProfile.isGuest` since native SDK 1.12.6), so this excludes guests
  /// on iOS too.
  bool get userConnected {
    final state = _connectionState;
    return state is OctopusConnected && !state.isGuest;
  }

  int? _notSeenCount;
  int? get notSeenCount => _notSeenCount;

  bool? _hasAccess;
  bool? get hasAccess => _hasAccess;

  /// Latest [OctopusSDK.communityAccessDeniedReason]. `null` is a real value
  /// (access granted or not known yet), so [hasAccessDeniedReason] tells it
  /// apart from "not received yet".
  CommunityAccessDeniedReason? _accessDeniedReason;
  CommunityAccessDeniedReason? get accessDeniedReason => _accessDeniedReason;
  bool _hasAccessDeniedReason = false;
  bool get hasAccessDeniedReason => _hasAccessDeniedReason;

  OctopusProfile? _profile;
  OctopusProfile? get profile => _profile;

  List<OctopusGroup> _groups = const [];
  List<OctopusGroup> get groups => _groups;

  OctopusConnectionState? _connectionState;
  OctopusConnectionState? get connectionState => _connectionState;

  bool _isInitialised = false;
  bool get isInitialised => _isInitialised;

  String? _logoBase64;
  String? get logoBase64 => _logoBase64;

  /// "Version {version}+{build}" read from real platform build metadata
  /// (`package_info_plus`, D5 / report 18) — never a hand-kept string.
  /// `null` until [bootstrap] resolves it (a `Future`, not const-evaluable),
  /// which the Settings label handles by simply omitting the line for one
  /// frame; it fires alongside every other bootstrap field, before the
  /// first paint in practice.
  String? _sampleVersionLabel;
  String? get sampleVersionLabel => _sampleVersionLabel;

  /// Owns the Play in-app update state shown next to the version label in
  /// Settings. App-scoped rather than screen-scoped so a check survives the
  /// tester leaving Settings, and so the start-up check has somewhere to land
  /// before any screen is built. Android-only by construction — see
  /// [SampleUpdateChecker]; on iOS it reports [UpdateUnsupported] and the card
  /// renders nothing.
  final SampleUpdateChecker updateChecker = SampleUpdateChecker();

  /// Builds the [OctopusTheme] a Theme-scenario preset selected, under the
  /// brightness the host is forcing (`null` = follow the ambient one). A
  /// *builder*, not a built theme: the brightness that matters is the one in
  /// force when the theme is handed to the SDK, not the one that happened to be
  /// ambient when the tester tapped the preset.
  OctopusThemeBuilder? _activeOctopusThemeBuilder;

  /// Resolves the [OctopusTheme] to apply to the embedded SDK surface,
  /// combining the Theme-scenario brand theme (if any) with the host's
  /// Light/Dark/System choice from the Config screen so the SDK content
  /// tracks the same light/dark mode as the surrounding Flutter chrome.
  ///
  /// [_activeOctopusThemeBuilder] being `null` (no preset picked yet, or "Brand
  /// theme" — preset 1 — since it explicitly sets it back to `null`) falls
  /// back to [brandOctopusTheme] rather than to a bare `null`/`OctopusTheme`.
  /// Without this fallback the sample never poses an [OctopusTheme] at all
  /// by default, so every embedded SDK surface renders on the SDK's own
  /// `#141414` near-black primary instead of the brand color — this is what
  /// used to read as a "black CTA" bug (cadrage report 24 §2.6). The genuine,
  /// no-theme-at-all default is reachable via the "SDK default (no theme)"
  /// preset, which sets an explicit empty [OctopusTheme] instead of `null`.
  ///
  /// - **System** — returns the active brand theme (falling back to
  ///   [brandOctopusTheme] as above), so the native SDK falls back to its
  ///   own system-trait observation (Compose `isSystemInDarkTheme()` on
  ///   Android, `UITraitCollection` on iOS) — same behaviour as Flutter's
  ///   `MaterialApp.themeMode = system`.
  /// - **Light / Dark** — forces [OctopusThemeMode] on top of that theme, so
  ///   the SDK renders in the chosen mode regardless of the device setting.
  ///   Without this propagation, picking "Light" on a dark device would
  ///   leave the SDK rendering dark (it observes the system) while the
  ///   Flutter chrome flips light — a visible mismatch.
  OctopusTheme? effectiveOctopusTheme() {
    final forced = _config?.forcedBrightness;
    final builder = _activeOctopusThemeBuilder;
    // No scenario preset active → the Config screen's Theme preset decides:
    // "Octopus navy" (the default) poses the sample's brand theme, "SDK
    // default" poses an explicitly empty one so the SDK renders on its own
    // palette. Handing `null` to the SDK is NOT the same thing — see the
    // no-theme-at-all note above.
    final configTheme = _config?.octopusNavyTheme ?? true;
    final theme = builder == null
        ? (configTheme
              ? brandOctopusTheme(_logoBase64, brightness: forced)
              : const OctopusTheme())
        : builder(forced);
    if (forced == null) return theme;
    final mode = forced == Brightness.dark
        ? OctopusThemeMode.dark
        : OctopusThemeMode.light;
    return theme.copyWith(themeMode: mode);
  }

  String _activeThemeLabel = 'Octopus navy';
  String get activeThemeLabel => _activeOctopusThemeBuilder == null
      ? ((_config?.octopusNavyTheme ?? true) ? 'Octopus navy' : 'SDK default')
      : _activeThemeLabel;

  LocaleChoice _localeChoice = LocaleChoice.system;
  LocaleChoice get localeChoice => _localeChoice;

  OctopusNotification? _pendingCommunityNotification;
  OctopusNotification? get pendingCommunityNotification =>
      _pendingCommunityNotification;

  CommunityNavigation _communityNavigation = CommunityNavigation.inTab;
  CommunityNavigation get communityNavigation => _communityNavigation;

  // These generations are process-local: never persist an SDK navigation stack.
  int _communitySession = 0;
  int get communitySession => _communitySession;
  DebugScenarioOverrides _debugScenarioOverrides = DebugScenarioOverrides();
  DebugScenarioOverrides get debugScenarioOverrides => _debugScenarioOverrides;
  Future<void> applyForceNicknameChoice(bool? enabled, String label) async {
    final overrides = _debugScenarioOverrides;
    await octopus.debugOverrideForceNicknameChoice(enabled);
    if (identical(overrides, _debugScenarioOverrides)) {
      overrides.forceNicknameChoice = enabled == null
          ? null
          : (value: enabled, label: label);
    }
  }

  Future<void> applyConsentTexts(
    OctopusConsentTexts? texts,
    TermsAcceptanceMode? mode,
    String label,
  ) async {
    final overrides = _debugScenarioOverrides;
    // Clear texts first, apply mode first. Record each successful native operation
    // so a failure on the second call does not claim an unapplied value.
    if (texts == null) {
      await octopus.debugOverrideConsentTexts(null);
      if (!identical(overrides, _debugScenarioOverrides)) return;
      overrides.consentTexts = null;
      await octopus.debugOverrideTermsAcceptanceMode(null);
      if (identical(overrides, _debugScenarioOverrides)) {
        overrides.termsAcceptance = null;
      }
    } else {
      await octopus.debugOverrideTermsAcceptanceMode(mode);
      if (!identical(overrides, _debugScenarioOverrides)) return;
      overrides.termsAcceptance = mode == null
          ? null
          : (value: mode, label: label);
      await octopus.debugOverrideConsentTexts(texts);
      if (identical(overrides, _debugScenarioOverrides)) {
        overrides.consentTexts = (value: texts, label: label);
      }
    }
  }

  int _communityRootEpoch = 0;
  int get communityRootEpoch => _communityRootEpoch;
  OctopusNotification? _communityNotification;
  OctopusNotification? get communityNotification => _communityNotification;

  OctopusNotification? takeDisplayedCommunityNotification() {
    final notification = _communityNotification;
    _communityNotification = null;
    return notification;
  }

  Future<void> restoreCommunityNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(communityNavigationPreferenceKey);
    _communityNavigation = CommunityNavigation.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => CommunityNavigation.inTab,
    );
  }

  Future<void> setCommunityNavigation(CommunityNavigation mode) async {
    if (_communityNavigation == mode) return;
    _communityNavigation = mode;
    resetCommunityRoot();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(communityNavigationPreferenceKey, mode.name);
  }

  /// A root reset is intentional; switching tabs never calls this.
  void resetCommunityRoot() {
    _communityNotification = null;
    _communityRootEpoch++;
    notifyListeners();
  }

  /// The shell consumes a push only when an initialized surface can mount it.
  OctopusNotification? takeCommunityNotification() {
    final notification = _pendingCommunityNotification;
    _pendingCommunityNotification = null;
    return notification;
  }

  void displayCommunityNotification(OctopusNotification notification) {
    _communityNotification = notification;
    _communityRootEpoch++;
    notifyListeners();
  }

  void _onCommunityTargeted() {
    _communitySession++;
    _debugScenarioOverrides = DebugScenarioOverrides();
    _communityNotification = null;
  }

  /// Bumped whenever a push tap asks the shell to jump to the Community tab.
  int _navEpoch = 0;
  int get navEpoch => _navEpoch;

  /// Last `objectId` the SDK fired through
  /// [OctopusSDK.setNavigateToClientObjectCallback] (a "view object" tap on a
  /// bridge post inside the SDK feed). `null` until the user has triggered
  /// one at least once since app launch. Held at app level — the callback
  /// is registered in [bootstrap] so it survives navigation away from the
  /// Bridge → Client Object scenario (the user has to leave the scenario
  /// to reach the Community tab, find the bridge post, and tap "View
  /// recipe"; a scenario-local registration would have been disposed in
  /// between).
  String? _lastNavigateObjectId;
  String? get lastNavigateObjectId => _lastNavigateObjectId;

  /// Total count of `navigateToClientObject` fires since app launch.
  int _navigateFireCount = 0;
  int get navigateFireCount => _navigateFireCount;

  /// The handle returned by [OctopusSDK.setNavigateToClientObjectCallback];
  /// invoked from [dispose] so a hot-reload / app-lifecycle teardown
  /// unregisters cleanly.
  VoidCallback? _cancelNavigateCallback;

  StreamSubscription<int>? _countSub;
  StreamSubscription<bool>? _accessSub;
  StreamSubscription<CommunityAccessDeniedReason?>? _accessDeniedReasonSub;
  StreamSubscription<OctopusProfile?>? _profileSub;
  StreamSubscription<List<OctopusGroup>>? _groupsSub;
  StreamSubscription<OctopusConnectionState>? _connectionStateSub;
  StreamSubscription<bool>? _isInitialisedSub;

  /// One-time startup: load the bundled logo and subscribe to the SDK's
  /// state-shaped streams so their latest values are always available.
  ///
  /// Idempotent — guarded by [_bootstrapped] so accidental re-entry (e.g.
  /// from a hot-reload or a future caller) doesn't double-subscribe the
  /// stream listeners and leak them.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    _countSub = OctopusSDK.notSeenNotificationsCount.listen((count) {
      _notSeenCount = count;
      notifyListeners();
    });
    _accessSub = OctopusSDK.hasAccessToCommunity.listen((access) {
      _hasAccess = access;
      notifyListeners();
    });
    _accessDeniedReasonSub = OctopusSDK.communityAccessDeniedReason.listen((
      reason,
    ) {
      _accessDeniedReason = reason;
      _hasAccessDeniedReason = true;
      notifyListeners();
    });
    _profileSub = OctopusSDK.profile.listen((profile) {
      _profile = profile;
      notifyListeners();
    });
    _groupsSub = OctopusSDK.groups.listen((groups) {
      _groups = groups;
      notifyListeners();
    });
    _connectionStateSub = OctopusSDK.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });
    _isInitialisedSub = OctopusSDK.isInitialisedFlow.listen((initialised) {
      _isInitialised = initialised;
      notifyListeners();
    });
    // App-scoped registration: the Bridge → Client Object scenario used to
    // register/unregister this callback in its own initState/dispose, which
    // meant the callback was unregistered while the user navigated to the
    // Community tab to actually trigger a "View recipe" tap — so the fire
    // count never updated. Register here so it persists for the lifetime
    // of the app; the scenario reads [lastNavigateObjectId] /
    // [navigateFireCount] off this state.
    await restoreHostIntegration();
    _installContentCallback();
    _logoBase64 = await loadLogoBase64();
    final packageInfo = await PackageInfo.fromPlatform();
    _sampleVersionLabel = '${packageInfo.version}+${packageInfo.buildNumber}';
    // One check per launch, not awaited: it is a network round-trip to Play and
    // nothing downstream of bootstrap depends on its answer. The card renders
    // "checking" and then whatever came back.
    unawaited(updateChecker.check());
    // Restore non-secret choices even when no usable key remains. The shell
    // stays browsable, and Settings can seed its form from this configuration.
    await restoreCommunityNavigation();
    await restoreSdkLocale();
    var restored = await loadPersistedDemoConfig(
      buildHost: _buildConfig.buildHost,
    );
    // An explicitly production-host build discards choices from a previous
    // flavour, then starts its injected configuration on every launch.
    // An empty build host keeps saved choices and uses the SDK default.
    if (_buildConfig.resolvedHost == productionHost && restored != null) {
      demoLog.apiCall('bootstrap', {
        'warning':
            'prod build — replacing persisted choices with build configuration',
      });
      await _clearPersistedDemoConfig();
      restored = null;
    }
    // Android's first launch enters Scenarios and starts the injected demo
    // configuration. Keyless builds remain browsable, with configuration in
    // Settings. Keep the build host; never silently route its key to Demo.
    final initial = restored ?? _buildConfig;
    _config = initial;
    _restoredConfig = restored;
    await _restoreConnectedProfile();
    _restoringConfig = false;
    // Only auto-start a config that still resolves to a key. A custom-key
    // config never does (the pasted key isn't persisted), and auto-starting it
    // would re-enter the SDK — production by default, see [octopusApiHost] —
    // on an empty key. Keep Scenarios browsable without starting the SDK. Trimmed, like every other key check in the sample
    // (`_start` on the Config screen, [octopusApiHost] below): a build that
    // injects a whitespace-only key resolves to no usable key either.
    if (initial.effectiveApiKey.trim().isNotEmpty) {
      await start(initial);
    } else {
      notifyListeners();
    }
  }

  /// Applies [config] and initialises the SDK (host-managed / SSO auth).
  ///
  /// A first Start or one after stopping calls `initialize()`. Applying
  /// Configuration while the SDK is running switches the community live.
  Future<void> start(DemoConfig config) async {
    if (config.buildHost != _buildConfig.buildHost) {
      config = config.copyWith(buildHost: _buildConfig.buildHost);
    }
    if (_initialized) {
      await _startViaSwitch(config);
      if (_initError == null) await _applySdkLocale();
      return;
    }
    _config = config;
    if (_activeApiKey != null &&
        _hasDifferentCommunityTarget(
          config.effectiveApiKey,
          config.apiServer,
        )) {
      await _clearConnectedProfile(allUsers: true);
    }
    await _restoreConnectedProfile();
    _initError = null;
    _initialized = false;
    _stopped = false;
    notifyListeners();

    try {
      // Route the SDK to the host the chosen server environment resolves to
      // (`DemoConfig.resolvedHost`): the build-injected demo host for Demo, a
      // typed host for Custom, and nothing at all for Prod — the published
      // native SDK defaults to production when no `apiServer` is passed, so
      // "no ApiServer" IS the prod choice. No host literal is committed for
      // the demo env; it comes from `--dart-define=OCTOPUS_API_HOST`.
      final apiServer = config.apiServer;
      // No `appManagedFields` here on purpose. The Flutter sample tests
      // against the demo keys, each of which the backend issued
      // for a specific managed-fields shape (NO/ALL/SOME). Hardcoding
      // `[NICKNAME]` at init time was producing a host↔community mismatch
      // with the `NO_MANAGED_FIELDS_…` keys that swallows `forceLogin`
      // behavior. The host stays default (`SDK manages every profile
      // field`), which is the safe choice for a kitchen-sink demo.
      demoLog.apiCall('initialize', {
        'apiKey': _redactKey(config.effectiveApiKey),
        'apiServer': apiServer?.host ?? '(default prod)',
      });
      await octopus.initialize(
        apiKey: config.effectiveApiKey,
        apiServer: apiServer,
      );
      _initialized = true;
      await _applySdkLocale();
      _activeApiKey = config.effectiveApiKey;
      _activeApiServer = apiServer;
      _onCommunityTargeted();
      // The override is SDK-process state the native side only accepts once
      // initialized: pose it now so the first Community mount already sees it.
      await _applyExposeClientUserIdOverride();
      // Remember this config so the next launch auto-restores it (and so a
      // cold-start push can deep-link without a manual reconfigure).
      unawaited(_persistDemoConfig(config));

      // Do NOT auto-`connectUser` here. The native SDK already calls
      // `connectAsGuest()` inside `initialize()` (Android `OctopusSDK.kt`
      // line ~541), which puts the SDK into `Connected(guest)` — the exact
      // precondition the SDK's `checkAuthenticated` needs to surface
      // `forceLoginOnStrongActions` via `navigateToLogin()`. Calling
      // `connectUser(...)` with a valid SSO JWT here would upgrade the
      // user to a fully-logged-in profile (`profile.isGuest == false`),
      // which bypasses the force-login redirect entirely. The host triggers
      // `connectUser(...)` only when the user explicitly logs in
      // (Settings → "Log in" in this sample).
    } catch (e) {
      _initError = e.toString();
    }
    notifyListeners();
  }

  /// [start]'s branch for a Start reached with the SDK already mounted (a
  /// "Change Configuration" round-trip) — switches community live instead of
  /// re-`initialize()`-ing, via the existing [switchToCommunity].
  Future<void> _startViaSwitch(DemoConfig config) async {
    _config = config;
    _initError = null;
    notifyListeners();
    try {
      demoLog.apiCall('switchCommunity (Change Configuration → Start)', {
        'apiKey': _redactKey(config.effectiveApiKey),
      });
      // No explicit apiServer: [switchToCommunity] already defaults it to
      // the same --dart-define-resolved host [start] uses — computing it
      // again here would just duplicate that default and risk drifting
      // from it.
      await switchToCommunity(config.effectiveApiKey);
      await _restoreConnectedProfile();
      // [switchToCommunity] already updates [_activeApiKey] and notifies;
      // still persist here so a relaunch restores the post-switch choice,
      // exactly like the fresh-initialize path does.
      unawaited(_persistDemoConfig(config));
    } catch (e) {
      _initError = e.toString();
    }
    notifyListeners();
  }

  /// The host-side entitlement set the next user JWT will carry. Mutable so
  /// the Connection scenario's entitlement presets can flip "Premium" /
  /// "Moderator" on/off and `refreshEntitlements()` picks up the new value
  /// on the next native invocation of the persistent token provider.
  ///
  /// The SDK-published `OctopusProfile.entitlements` is the BE-resolved
  /// truth — this local set is only what the demo host *requests* in the
  /// signed JWT. Mirrors iOS's `AppUserManager.currentEntitlements`.
  Set<String> _currentEntitlements = const {};
  Set<String> get currentEntitlements => _currentEntitlements;

  /// Updates the entitlement set the next signed JWT will carry. Use
  /// `await octopus.refreshEntitlements()` afterwards to push the change
  /// through the SDK (the persistent token provider will re-sign with the
  /// new set, the BE issues a fresh community JWT, and the published
  /// profile updates).
  void setCurrentEntitlements(Set<String> entitlements) {
    _currentEntitlements = Set.unmodifiable(entitlements);
    notifyListeners();
  }

  /// The sample's **local test profile** — the fields the Account screen edits
  /// and hands to `connectUser`.
  ///
  /// Host-side by construction: `OctopusProfile` (the SDK's published profile)
  /// carries only `entitlements` and `clientUserId`, so nickname / bio /
  /// avatar are the demo host's own inputs, not SDK state read back. That is
  /// also why the Account screen can render an avatar at all — it renders what
  /// the host would send, falling back to initials.
  String _testNickname = '';
  String get testNickname => _testNickname;

  String _testBio = '';
  String get testBio => _testBio;

  /// Avatar handed to `connectUser(picture:)` — a URL or a base64 payload,
  /// whichever the tester pasted. Empty = no picture, render initials.
  String _testAvatarUrl = '';
  String get testAvatarUrl => _testAvatarUrl;

  ConnectedDemoProfile? _connectedProfile;
  int _connectedProfileGeneration = 0;

  /// Last successfully sent values for the active user. The SDK's profile
  /// stream does not expose these fields, and local test values may be unsent.
  ConnectedDemoProfile? get connectedProfile =>
      _connectedProfile?.userId == effectiveUserId ? _connectedProfile : null;

  /// Complete edit baseline, including after upgrading from an unsaved session.
  /// Use demo defaults only when no snapshot exists; retain recorded empties.
  ConnectedDemoProfile get profileForEditing =>
      connectedProfile ??
      (
        userId: effectiveUserId,
        nickname: effectiveUserId,
        bio: '',
        picture: 'https://i.pravatar.cc/150',
      );

  Future<void>? _profileWrites;

  /// Retains and persists the host payload only after a successful connection.
  Future<void> noteConnectedProfile({
    required String userId,
    required String? nickname,
    required String? bio,
    required String? picture,
    bool notify = true,
  }) async {
    final profile = (
      userId: userId,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
    // Other users are persisted, but never replace the active edit baseline.
    if (userId == effectiveUserId) {
      _connectedProfileGeneration++;
      _connectedProfile = profile;
      if (notify) notifyListeners();
    }
    await _queueProfileWrite((prefs) async {
      if (!await prefs.setString(
        '$_hostProfilePrefsPrefix$userId',
        jsonEncode({
          'userId': profile.userId,
          'nickname': profile.nickname,
          'bio': profile.bio,
          'picture': profile.picture,
        }),
      )) {
        demoLog.note('Host profile could not be saved');
      }
    });
  }

  Future<void> _queueProfileWrite(
    Future<void> Function(SharedPreferences) write,
  ) {
    final pending = (_profileWrites ?? Future<void>.value()).then((_) async {
      try {
        await write(await SharedPreferences.getInstance());
      } catch (_) {
        demoLog.note('Host profile storage unavailable');
      }
    });
    _profileWrites = pending;
    // Retain pending writes only, like the configuration persistence queue.
    unawaited(
      pending.whenComplete(() {
        if (identical(_profileWrites, pending)) _profileWrites = null;
      }),
    );
    return pending;
  }

  Future<void> _restoreConnectedProfile() async {
    if (connectedProfile != null) return;
    final generation = ++_connectedProfileGeneration;
    final userId = effectiveUserId;
    await _profileWrites;
    // A connection/clear for this user, stop, or newer restore supersedes
    // this read. Notes and clears for other users do not invalidate it.
    if (generation != _connectedProfileGeneration ||
        userId != effectiveUserId) {
      return;
    }
    _connectedProfile = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _connectedProfileGeneration ||
          userId != effectiveUserId) {
        return;
      }
      final raw = prefs.getString('$_hostProfilePrefsPrefix$userId');
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['userId'] != userId) return;
      _connectedProfile = (
        userId: userId,
        nickname: json['nickname'] as String?,
        bio: json['bio'] as String?,
        picture: json['picture'] as String?,
      );
    } catch (_) {
      demoLog.note('Host profile could not be restored');
    }
  }

  Future<void> _clearConnectedProfile({bool allUsers = false}) async {
    final userId = effectiveUserId;
    _connectedProfileGeneration++;
    _connectedProfile = null;
    await _queueProfileWrite((prefs) async {
      final keys = allUsers
          ? prefs.getKeys().where(
              (key) => key.startsWith(_hostProfilePrefsPrefix),
            )
          : ['$_hostProfilePrefsPrefix$userId'];
      for (final key in keys) {
        if (!await prefs.remove(key)) {
          demoLog.note('Host profile could not be cleared');
        }
      }
    });
  }

  /// Updates the local test profile. Does not touch the SDK: the change lands
  /// on the next connect / reconnect, which is what the Account screen's help
  /// lines say.
  void setTestProfile({String? nickname, String? bio, String? avatarUrl}) {
    _testNickname = nickname?.trim() ?? _testNickname;
    _testBio = bio?.trim() ?? _testBio;
    _testAvatarUrl = avatarUrl?.trim() ?? _testAvatarUrl;
    notifyListeners();
  }

  /// Display name for the Account / Home connection cards: the nickname the
  /// tester set, else the SSO user id.
  String get displayName =>
      _testNickname.isNotEmpty ? _testNickname : effectiveUserId;

  /// Pushes the current [currentEntitlements] through the SDK without
  /// re-creating the session (`refreshEntitlements`): the persistent token
  /// provider re-signs with the new set and the backend issues a fresh
  /// community JWT.
  Future<OctopusResult<void, RefreshEntitlementsError>>
  refreshEntitlements() async {
    demoLog.apiCall('refreshEntitlements', {
      'entitlements': _currentEntitlements.toList()..sort(),
    });
    final result = await octopus.refreshEntitlements();
    notifyListeners();
    return result;
  }

  /// Last connect attempt that came back refused, if the session is still
  /// down — what turns Home's connection card from "guest" (amber) into "SSO
  /// session failed" (red). Cleared by a successful connect and by an explicit
  /// disconnect, so the red state always means *a real attempt failed*, never
  /// "nobody has tried yet".
  String? _lastConnectError;
  String? get lastConnectError => _lastConnectError;

  /// Records a connect failure raised outside [connectDemoUser] (the Login
  /// page's own `connectUser` path, an exception a caller caught).
  void noteConnectFailure(String? message) {
    if (_lastConnectError == message) return;
    _lastConnectError = message;
    notifyListeners();
  }

  /// The SSO `sub` the next connect / profile-edit call will send to the SDK.
  ///
  /// Reads the Config-screen picker (persisted across kill+relaunch), with
  /// the build-time [octopusUserId] seed as the fallback for fresh installs
  /// and for code paths reached before a config is set (e.g. the Config
  /// screen itself).
  String get effectiveUserId => _config?.userId ?? octopusUserId;

  /// Connects the configured SSO user with a **persistent** token provider
  /// — the SDK will re-invoke the provider on every refresh. Distributed
  /// builds select the bundled user's pre-signed token, with fixed claims.
  /// Local signing picks up [_currentEntitlements] on every invocation.
  /// Without either, falls back to the pre-baked [octopusUserToken].
  ///
  /// On the pre-baked-token fallback path, the bundled [octopusUserToken] is
  /// signed against the build-time [octopusUserId] seed — connecting with a
  /// different runtime [effectiveUserId] will surface a BE auth error. The
  /// Config screen documents this; the SSO-secret path (used in normal QA)
  /// signs the JWT on the fly with whichever id is active.
  ///
  /// Returns the SDK's [OctopusResult] — a refused connection (banned user,
  /// JWT the backend rejects, …) resolves as a failure rather than throwing,
  /// so callers must inspect it to surface anything; `describeConnectUserFailure`
  /// turns it into a message. Rethrows on an actual exception. The reactive
  /// [connectionState] stream — the source of truth for [userConnected] —
  /// emits independently on success.
  /// Set [sendTestProfile] to also send the local test profile (nickname /
  /// bio / avatar) with the connect — what the Account screen does. Scenarios
  /// leave it off so they exercise `connectUser` with nothing but the JWT.
  Future<OctopusResult<void, ClientUserError>> connectDemoUser({
    Set<String> entitlements = const {},
    bool sendTestProfile = false,
  }) async {
    _currentEntitlements = Set.unmodifiable(entitlements);
    final userId = effectiveUserId;
    final nickname = sendTestProfile && _testNickname.isNotEmpty
        ? _testNickname
        : null;
    final bio = sendTestProfile && _testBio.isNotEmpty ? _testBio : null;
    final picture = sendTestProfile && _testAvatarUrl.isNotEmpty
        ? _testAvatarUrl
        : null;
    return connectWithProfile(
      userId: userId,
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
  }

  /// Selects a pre-signed token, or signs locally with current entitlements.
  @protected
  Future<String> createClientUserToken(String userId) async {
    try {
      return selectDemoUserToken(
        userId: userId,
        entitlements: _currentEntitlements,
      );
    } on DemoUserTokenException catch (error) {
      demoLog.note(error.message);
      rethrow;
    }
  }

  /// Shared connection path for Account, scenarios and profile edits.
  Future<OctopusResult<void, ClientUserError>> connectWithProfile({
    required String userId,
    String? nickname,
    String? bio,
    String? picture,
  }) async {
    // Reject expired/missing build tokens through the same result path on both
    // platforms, before a native connection can fall back to a guest session.
    if (octopusDemoUserTokens.isNotEmpty) {
      try {
        await createClientUserToken(userId);
      } on DemoUserTokenException catch (error) {
        final result = OctopusInvalidArguments<ClientUserError>([
          ClientUserInvalidTokenError(error.message),
        ]);
        _lastConnectError = describeConnectUserFailure(result);
        notifyListeners();
        return result;
      }
    }
    demoLog.apiCall('connectUser (tokenProvider)', {
      'userId': userId,
      'entitlements': _currentEntitlements.toList()..sort(),
      if (nickname != null) 'nickname': nickname,
      if (bio != null) 'bio': bio,
      if (picture != null) 'picture': '<set>',
    });
    final result = await octopus.connectUser(
      userId: userId,
      tokenProvider: () => createClientUserToken(userId),
      nickname: nickname,
      bio: bio,
      picture: picture,
    );
    _lastConnectError = describeConnectUserFailure(result);
    if (_lastConnectError == null) {
      await noteConnectedProfile(
        userId: userId,
        nickname: nickname,
        bio: bio,
        picture: picture,
        notify: false,
      );
    }
    notifyListeners();
    return result;
  }

  /// Disconnects the current user. Rethrows on failure. [userConnected] is
  /// derived from [connectionState] which emits independently.
  Future<void> disconnectUser() async {
    demoLog.apiCall('disconnectUser');
    await octopus.disconnectUser();
    await _clearConnectedProfile();
    // Native debug overrides belong to the SDK instance and survive logout.
    _lastConnectError = null;
    notifyListeners();
  }

  /// Switches the SDK to a different community (API key) at runtime.
  ///
  /// Updates [activeApiKey] on success so the rest of the sample reflects the
  /// new community immediately. Rethrows on failure (the active key is left
  /// untouched in that case).
  ///
  /// [appManagedFields] defaults to the same empty list `initialize()` uses —
  /// see the comment block in [start] for why hardcoding `[NICKNAME]` here
  /// would conflict with the `NO_MANAGED_FIELDS_…` demo keys. Override only
  /// when you specifically want to demo per-community managed-field shapes.
  ///
  /// [apiServer] defaults to the host the active [config]'s server environment
  /// resolves to — otherwise a switch from a non-prod init would silently fall
  /// back to prod and produce a host↔community mismatch.
  Future<void> switchToCommunity(
    String apiKey, {
    List<ProfileField> appManagedFields = const [],
    ApiServer? apiServer,
  }) async {
    final resolvedServer = apiServer ?? _config?.apiServer;
    await octopus.switchCommunity(
      apiKey: apiKey,
      appManagedFields: appManagedFields,
      apiServer: resolvedServer,
    );
    if (_hasDifferentCommunityTarget(apiKey, resolvedServer)) {
      // Storage is user-scoped; snapshots from a previous community must not
      // become the baseline after the next restart either.
      await _clearConnectedProfile(allUsers: true);
    } else {
      _connectedProfileGeneration++;
      _connectedProfile = null;
    }
    _activeApiKey = apiKey;
    _activeApiServer = resolvedServer;
    _onCommunityTargeted();
    // A switch fetches the new community's config; re-pose the override on
    // top of it rather than trusting the native side to carry it over.
    await _applyExposeClientUserIdOverride();
    notifyListeners();
  }

  bool _hasDifferentCommunityTarget(String apiKey, ApiServer? server) =>
      _activeApiKey != apiKey ||
      (_activeApiServer?.host ?? productionHost) !=
          (server?.host ?? productionHost) ||
      (_activeApiServer?.port ?? 443) != (server?.port ?? 443);

  /// Changes the app's light/dark choice from Settings → Appearance, without
  /// going back through Config.
  ///
  /// Persists it on the live [DemoConfig] so the pick survives a relaunch, and
  /// re-poses the SDK theme: [effectiveOctopusTheme] resolves its quadruple
  /// against the forced brightness, so a preset picked in light mode still
  /// hands the SDK its dark colors once Dark is pinned.
  void setThemeChoice(AppThemeChoice choice) {
    final config = configurationChoices;
    if (_config != null && config.theme == choice) return;
    _config = config.copyWith(theme: choice);
    unawaited(_persistDemoConfig(_config!));
    notifyListeners();
  }

  /// Settings presets replace any temporary scenario theme and persist.
  void setThemePreset(bool navy) {
    final config = configurationChoices;
    _config = config.copyWith(octopusNavyTheme: navy);
    _activeOctopusThemeBuilder = null;
    _activeThemeLabel = navy ? 'Octopus navy' : 'SDK default';
    unawaited(_persistDemoConfig(_config!));
    notifyListeners();
  }

  /// The current state of the two feature toggles — [FeatureToggles.defaults] until a
  /// config is loaded, so every read-only read-out has something truthful to show.
  FeatureToggles get featureToggles =>
      _config?.featureToggles ?? FeatureToggles.defaults;

  /// Flips one feature toggle, from the header of its Scenarios section.
  ///
  /// The **only** writer. Ported iso from Android's `executeSetFeatureToggle`, including
  /// the two behaviours that make the flip observable rather than merely stored:
  /// - the SDK config is rebuilt and persisted, and the Debug console gets one line
  ///   naming the toggle and what it now does, so a tester reading the log later can see
  ///   why the app changed behaviour mid-session;
  /// - turning **push registration on registers this device's token immediately**,
  ///   through [onPushRegistrationEnabled], which also opens the notification
  ///   permission gate if it has not fired yet. A toggle whose effect only shows up at
  ///   the next launch is a toggle a tester flips twice and reports as broken.
  Future<void> setFeatureToggle(FeatureToggle toggle, bool enabled) async {
    final config = _config;
    if (config == null || config.featureToggles[toggle] == enabled) return;
    _config = config.copyWith(
      featureToggles: config.featureToggles.withToggle(toggle, enabled),
    );
    unawaited(_persistDemoConfig(_config!));
    demoLog.note('feature toggled → SDK config rebuilt', {
      toggle.label: enabled ? 'on' : 'off',
      'effect': toggle.effectLine(enabled),
    });
    notifyListeners();

    if (toggle == FeatureToggle.pushRegistration && enabled) {
      await onPushRegistrationEnabled?.call();
    }
  }

  /// Registers this device's push token now and, the first time push registration is
  /// on with the SDK initialised, asks for the OS notification permission (the toggle
  /// lives on the post-init Scenarios tab, so this is the path for a config persisted
  /// with it off). Set by `main.dart`, which owns the single registration funnel and
  /// the permission gate; `null` in tests and on hosts without push.
  Future<void> Function()? onPushRegistrationEnabled;

  /// Overrides the SDK UI locale (Locale scenario + Settings picker).
  Future<void> _localeUpdates = Future<void>.value();

  Future<void> _queueLocaleUpdate(Future<void> Function() update) {
    final result = _localeUpdates.then((_) => update());
    // A failed request is reported to its caller without blocking later choices.
    _localeUpdates = result.catchError((Object _) {});
    return result;
  }

  Future<void> setLocale(LocaleChoice choice) => _queueLocaleUpdate(() async {
    if (_initialized) {
      demoLog.apiCall('overrideDefaultLocale', {'locale': choice.label});
      await octopus.overrideDefaultLocale(choice.locale);
    }
    _localeChoice = choice;
    _localeTagOverride = null;
    await _persistLocale();
    notifyListeners();
  });

  /// A locale tag typed by hand in the Locale scenario's Customize editor, when
  /// it is not one [LocaleChoice] can spell. `null` whenever [localeChoice] is
  /// the whole truth.
  ///
  /// `overrideDefaultLocale` takes any tag; the enum only lists the two the
  /// presets use. Keeping the typed value here rather than widening the enum
  /// means every read-out shows what was actually sent — a screen claiming
  /// "System" while the SDK renders in `de` is the one outcome worth avoiding.
  String? _localeTagOverride;

  /// What every locale read-out shows.
  String get localeLabel => _localeTagOverride ?? _localeChoice.label;

  /// The tag the Customize field starts from — `''` meaning the system locale.
  String get localeTag =>
      _localeTagOverride ??
      (_localeChoice == LocaleChoice.system ? '' : _localeChoice.label);

  /// Overrides the SDK locale with a raw BCP-47 tag; blank resets to system.
  Future<void> setLocaleTag(String tag) async {
    final trimmed = tag.trim();
    final choice = switch (trimmed) {
      '' => LocaleChoice.system,
      'fr' => LocaleChoice.fr,
      'en' => LocaleChoice.en,
      _ => null,
    };
    if (choice != null) {
      await setLocale(choice);
      return;
    }
    await _queueLocaleUpdate(() async {
      if (_initialized) {
        demoLog.apiCall('overrideDefaultLocale', {'locale': trimmed});
        await octopus.overrideDefaultLocale(Locale(trimmed));
      }
      // No enum member spells this one; read-outs show the actual override.
      _localeChoice = LocaleChoice.system;
      _localeTagOverride = trimmed;
      await _persistLocale();
      notifyListeners();
    });
  }

  Future<void> _persistLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(sdkLocalePreferenceKey, localeTag)) {
        demoLog.note('Language preference could not be saved');
      }
    } catch (_) {
      demoLog.note('Language preference save failed');
    }
  }

  Future<void> restoreSdkLocale() => _queueLocaleUpdate(() async {
    String? tag;
    try {
      final prefs = await SharedPreferences.getInstance();
      tag = prefs.getString(sdkLocalePreferenceKey);
    } catch (_) {
      demoLog.note('Language preference restore failed');
      return;
    }
    if (tag == null) return;
    _localeChoice = switch (tag) {
      'en' => LocaleChoice.en,
      'fr' => LocaleChoice.fr,
      _ => LocaleChoice.system,
    };
    _localeTagOverride = tag.isEmpty || tag == 'en' || tag == 'fr' ? null : tag;
    // iOS requires initialize before overrideDefaultLocale. Bootstrap restores
    // the local choice; start applies it before mounting any community view.
    if (_initialized) await _sendSdkLocale();
    notifyListeners();
  });

  Future<void> _applySdkLocale() => _queueLocaleUpdate(_sendSdkLocale);

  Future<void> _sendSdkLocale() async {
    if (!_initialized) return;
    await octopus.overrideDefaultLocale(
      localeTag.isEmpty ? null : Locale(localeTag),
    );
  }

  /// Whether the host wires `onNavigateToProfile` on the embedded Community
  /// view — the Unified Profile activation switch.
  ///
  /// Off by default, like Android's HostCallbacks. The Unified Profile
  /// scenario enables the handler together with the backend flag override.
  ///
  /// Activation is an AND gate: this alone does nothing unless the community is
  /// also configured to expose client user ids.
  bool _unifiedProfileWired = false;
  bool get unifiedProfileWired => _unifiedProfileWired;

  /// Wires / unwires the host's profile-tap handling.
  ///
  /// The flag is **mount-time** — it rides in the embedded view's creation
  /// params, which are read once — so the Community tab folds it into its
  /// [ValueKey] to force a fresh PlatformView. Deliberately does NOT bump
  /// [navEpoch]: that would also yank the user onto the Community tab, which is
  /// reserved for a push deep-link.
  void setUnifiedProfileWired(bool wired) {
    if (_unifiedProfileWired == wired) return;
    _unifiedProfileWired = wired;
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  /// The other half of the Unified Profile AND gate: the community flag
  /// `exposeClientUserId`, set per community on the backend.
  /// [ExposeClientUserIdOverride.backend] (the default) keeps the server value;
  /// Force active overrides it locally so the host profile can be
  /// exercised on any community. In-memory, like [unifiedProfileWired].
  ExposeClientUserIdOverride _exposeClientUserIdOverride =
      ExposeClientUserIdOverride.backend;
  ExposeClientUserIdOverride get exposeClientUserIdOverride =>
      _exposeClientUserIdOverride;

  /// Last effective community config read back from the SDK (server value
  /// with any override applied), or `null` while unknown.
  OctopusDebugCommunityConfig? _communityConfig;
  OctopusDebugCommunityConfig? get communityConfig => _communityConfig;

  /// `false` once the platform answered that it cannot read the config (iOS
  /// through Swift Package Manager), so the UI can say so instead of "unknown".
  bool _communityConfigReadable = true;
  bool get communityConfigReadable => _communityConfigReadable;

  /// Changes the override and, when the SDK is up, applies it right away.
  Future<void> setExposeClientUserIdOverride(
    ExposeClientUserIdOverride choice,
  ) async {
    if (_exposeClientUserIdOverride == choice) return;
    _exposeClientUserIdOverride = choice;
    notifyListeners();
    await _applyExposeClientUserIdOverride();
  }

  Future<void> _applyExposeClientUserIdOverride() async {
    if (!_initialized) return;
    final enabled = _exposeClientUserIdOverride.enabled;
    try {
      demoLog.apiCall('debugOverrideExposeClientUserId', {
        'enabled': '$enabled',
      });
      await octopus.debugOverrideExposeClientUserId(enabled);
    } catch (e) {
      demoLog.apiCall('debugOverrideExposeClientUserId failed', {
        'error': '$e',
      });
    }
    await refreshCommunityConfig();
  }

  /// Re-reads the effective community config for the read-outs that show it.
  Future<void> refreshCommunityConfig() async {
    if (!_initialized) return;
    final session = communitySession;
    try {
      final config = await octopus.debugGetCommunityConfig();
      if (_disposed || !_initialized || session != communitySession) return;
      _communityConfig = config;
      _communityConfigReadable = true;
    } on PlatformException catch (e) {
      if (_disposed || !_initialized || session != communitySession) return;
      _communityConfig = null;
      _communityConfigReadable = e.code != 'UNSUPPORTED_PLATFORM';
    } catch (_) {
      if (_disposed || !_initialized || session != communitySession) return;
      // Any other failure is transient: "unknown", never "unreadable" — only
      // UNSUPPORTED_PLATFORM means this integration path cannot read it at all.
      // Resetting here keeps an earlier verdict from going stale.
      _communityConfig = null;
      _communityConfigReadable = true;
    }
    notifyListeners();
  }

  /// One-line read-out of the flag for Debug info and the scenario hint:
  /// the effective value, then where it comes from.
  String get exposeClientUserIdSummary {
    final source = _exposeClientUserIdOverride.label;
    if (!_communityConfigReadable) return 'unreadable here · $source';
    final config = _communityConfig;
    if (config == null) return 'unknown · $source';
    return '${config.exposeClientUserId ? 'on' : 'off'} · $source';
  }

  bool _hostGroupAccessWired = true;
  bool get hostGroupAccessWired => _hostGroupAccessWired;
  void setHostGroupAccessWired(bool value) {
    _hostGroupAccessWired = value;
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  bool _hostProfileEditWired = true;
  bool get hostProfileEditWired => _hostProfileEditWired;
  HostUrlHandling _hostUrlHandling = HostUrlHandling.sdk;
  HostUrlHandling get hostUrlHandling => _hostUrlHandling;

  void setHostProfileEditWired(bool value) {
    _hostProfileEditWired = value;
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  void setHostUrlHandling(HostUrlHandling value) {
    _hostUrlHandling = value == HostUrlHandling.sampleRule
        ? HostUrlHandling.sdk
        : value;
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  void _installContentCallback() {
    _cancelNavigateCallback?.call();
    _cancelNavigateCallback = null;
    if (!onNavigateToContentWired) return;
    _cancelNavigateCallback = OctopusSDK.setNavigateToClientObjectCallback((
      objectId,
    ) {
      demoLog.apiCall('navigateToClientObject', {'objectId': objectId});
      _lastNavigateObjectId = objectId;
      _navigateFireCount += 1;
      notifyListeners();
    });
  }

  Future<void> _persistHostIntegration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        'host_integration_v1',
        jsonEncode({
          'profile': unifiedProfileWired,
          'edit': hostProfileEditWired,
          'group': hostGroupAccessWired,
          'login': onAuthenticationRequiredWired,
          'content': onNavigateToContentWired,
          'url': hostUrlHandling.name,
        }),
      );
      if (!saved) {
        demoLog.note('Host integration preferences could not be saved');
      }
    } catch (error) {
      demoLog.note(
        'Host integration preference save failed: ${error.runtimeType}',
      );
    }
  }

  Future<void> restoreHostIntegration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('host_integration_v1');
      if (raw == null) return;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        // Parse before assigning so a malformed field cannot partially restore.
        final profile = map['profile'] as bool? ?? false;
        final edit = map['edit'] as bool? ?? true;
        final group = map['group'] as bool? ?? true;
        final login = map['login'] as bool? ?? true;
        final content = map['content'] as bool? ?? true;
        final url = HostUrlHandling.values.byName(
          map['url'] as String? ?? 'sdk',
        );
        _unifiedProfileWired = profile;
        _hostProfileEditWired = edit;
        _hostGroupAccessWired = group;
        _onAuthenticationRequiredWired = login;
        _onNavigateToContentWired = content;
        _hostUrlHandling = url == HostUrlHandling.sampleRule
            ? HostUrlHandling.sdk
            : url;
      } catch (error) {
        _unifiedProfileWired = false;
        _hostProfileEditWired = true;
        _hostGroupAccessWired = true;
        _onAuthenticationRequiredWired = true;
        _onNavigateToContentWired = true;
        _hostUrlHandling = HostUrlHandling.sdk;
        demoLog.note(
          'Malformed host integration preferences dropped: ${error.runtimeType}',
        );
        if (!await prefs.remove('host_integration_v1')) {
          demoLog.note(
            'Malformed host integration preferences could not be removed',
          );
        }
      } finally {
        if (!_disposed) notifyListeners();
      }
    } catch (error) {
      demoLog.note(
        'Host integration preference restore failed: ${error.runtimeType}',
      );
    }
  }

  // The content and login flags control real host callbacks. The remaining
  // legacy flags have no corresponding optional mount callback in the plugin
  // and are never offered as editable Settings controls.
  bool _onNavigateToContentWired = true;
  bool _onAuthenticationRequiredWired = true;
  bool _onPushNotificationTappedWired = true;
  bool _onUnreadCountChangedWired = true;
  bool _onEventWired = false;
  bool _onErrorWired = false;

  bool get onNavigateToContentWired => _onNavigateToContentWired;
  bool get onAuthenticationRequiredWired => _onAuthenticationRequiredWired;
  bool get onPushNotificationTappedWired => _onPushNotificationTappedWired;
  bool get onUnreadCountChangedWired => _onUnreadCountChangedWired;
  bool get onEventWired => _onEventWired;
  bool get onErrorWired => _onErrorWired;

  void setOnNavigateToContentWired(bool v) {
    _onNavigateToContentWired = v;
    _installContentCallback();
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  void setOnAuthenticationRequiredWired(bool v) {
    _onAuthenticationRequiredWired = v;
    unawaited(_persistHostIntegration());
    notifyListeners();
  }

  void setOnPushNotificationTappedWired(bool v) {
    _onPushNotificationTappedWired = v;
    notifyListeners();
  }

  void setOnUnreadCountChangedWired(bool v) {
    _onUnreadCountChangedWired = v;
    notifyListeners();
  }

  void setOnEventWired(bool v) {
    _onEventWired = v;
    notifyListeners();
  }

  void setOnErrorWired(bool v) {
    _onErrorWired = v;
    notifyListeners();
  }

  List<(String, bool)> get hostCallbacks => [
    ('onNavigateToProfile', unifiedProfileWired),
    ('onNavigateToProfileEdit (onModifyUser)', hostProfileEditWired),
    ('onGroupAccessDenied', hostGroupAccessWired),
    ('onNavigateToLogin', onAuthenticationRequiredWired),
    ('onNavigateToClientObject', onNavigateToContentWired),
  ];

  int get wiredHostCallbackCount => hostCallbacks.where((row) => row.$2).length;

  String get hostCallbacksSummary => [
    for (final (name, wired) in hostCallbacks)
      if (wired) name,
    'onNavigateToUrl (${hostUrlHandling.label})',
  ].join(', ');

  /// Sets the custom [OctopusTheme] applied to the embedded Community view.
  ///
  /// [build] takes the brightness the theme is being applied under, so a preset
  /// picked in light mode still hands the SDK its dark quadruple once the
  /// Config screen pins Dark. `null` means "no preset" and falls back to the
  /// brand theme — see [effectiveOctopusTheme].
  void setActiveOctopusTheme(OctopusThemeBuilder? build, String label) {
    _activeOctopusThemeBuilder = build;
    _activeThemeLabel = label;
    notifyListeners();
  }

  /// Whether the persistent production warning banner must show right now.
  ///
  /// Build-gated exactly as before ([octopusIsInternalBuild] — a client
  /// integrating the SDK nominally runs against production and must not see
  /// it), but the *environment* half is now read off the live config rather
  /// than the build: with a runtime server picker, picking **Prod** on an
  /// internal build has to raise the banner even though the build injected a
  /// demo host. Before a config exists (Config screen, splash) it falls back
  /// to the build-time fail-safe.
  bool get showsProductionWarning {
    if (!octopusIsInternalBuild) return false;
    final config = _config;
    return config == null ? octopusIsProdServer : config.pointsAtProduction;
  }

  /// Tab index the shell should show, when something outside the shell asks
  /// for one (a Community status band's action, a scenario's "Verify in
  /// Community"). Consumed by the shell through [navEpoch].
  int _requestedTab = SampleTab.scenarios.index;
  int get requestedTab => _requestedTab;

  /// The last place the tester was that was not part of the Settings tree —
  /// "Scenarios › connection", "Community".
  ///
  /// Send feedback is opened from Settings, so without this the one field a
  /// defect report cannot be reconstructed without would read "Settings" every
  /// time.
  String _lastContentBreadcrumb = 'Scenarios';
  String get lastContentBreadcrumb => _lastContentBreadcrumb;

  /// Records [where] as the current content location. Deliberately does not
  /// notify: it is read once, when the feedback sheet opens, and notifying
  /// would rebuild the whole shell on every tab tap.
  void noteBreadcrumb(String where) {
    _lastContentBreadcrumb = where;
  }

  /// Asks the shell to switch to [index] in [SampleTab] order.
  void requestTab(int index) {
    _requestedTab = index;
    _navEpoch++;
    notifyListeners();
  }

  String? _requestedScenariosSection;

  /// Asks the shell to open the Scenarios tab on the section [sectionId]
  /// (`scenarios-section-<id>`): unfolded and scrolled into view.
  void requestScenariosSection(String sectionId) {
    _requestedScenariosSection = sectionId;
    requestTab(SampleTab.scenarios.index);
  }

  /// Hands the section asked for by [requestScenariosSection] to the Scenarios
  /// tab, and forgets it: a request is honoured once, so a later rebuild or a
  /// return to the tab leaves the list where the user left it. Deliberately
  /// does not notify — reading a request is not a state change anyone shows.
  String? takeRequestedScenariosSection() {
    final id = _requestedScenariosSection;
    _requestedScenariosSection = null;
    return id;
  }

  /// Asks the shell to switch to the Community tab, optionally deep-linked to
  /// the content referenced by [notification] (push tap).
  void requestCommunityTab(OctopusNotification? notification) {
    _requestedTab = SampleTab.community.index;
    _pendingCommunityNotification = notification;
    _navEpoch++;
    notifyListeners();
  }

  /// Discards an unhandled push (for example during a reset).
  void clearPendingNotification() {
    if (_pendingCommunityNotification == null) return;
    _pendingCommunityNotification = null;
    notifyListeners();
  }

  /// Scenario reset keeps the selected community, persisted configuration and
  /// debug overrides, matching the native SDK instance that stays initialized.
  Future<void> resetSessionForScenario() async {
    await octopus.reset();
    await _clearConnectedProfile();
    _profile = null;
    _connectionState = null;
    _currentEntitlements = const {};
    _notSeenCount = null;
    _hasAccess = null;
    _accessDeniedReason = null;
    _hasAccessDeniedReason = false;
    notifyListeners();
  }

  /// Stop while retaining the configuration so the scenario can start it again.
  Future<void> stopForScenario() async {
    await octopus.stop();
    _connectedProfileGeneration++;
    _connectedProfile = null;
    _debugScenarioOverrides = DebugScenarioOverrides();
    _initialized = false;
    _stopped = true;
    _isInitialised = false;
    _profile = null;
    _connectionState = null;
    _groups = const [];
    _currentEntitlements = const {};
    _notSeenCount = null;
    _hasAccess = null;
    _accessDeniedReason = null;
    _hasAccessDeniedReason = false;
    _communityConfig = null;
    _pendingCommunityNotification = null;
    _communityNotification = null;
    notifyListeners();
  }

  /// Restarts the last live community, including a scenario's runtime switch.
  Future<void> restartForScenario() async {
    var config = _config;
    if (config == null) {
      throw StateError('Configure the SDK in Settings first.');
    }
    final activeKey = _activeApiKey;
    if (activeKey != null && activeKey != config.effectiveApiKey) {
      InjectedApiKey? selectedKey;
      for (final key in injectedApiKeys) {
        if (key.key == activeKey) {
          selectedKey = key;
          break;
        }
      }
      config = config.copyWith(
        apiKeySource: selectedKey == null
            ? ApiKeySource.custom
            : ApiKeySource.demo,
        customApiKey: selectedKey == null ? activeKey : '',
        selectedInjectedKey: selectedKey,
        clearSelectedInjectedKey: selectedKey == null,
      );
    }
    if (config.effectiveApiKey.trim().isEmpty) {
      throw StateError('Configure the SDK in Settings first.');
    }
    if (_initialized) await stopForScenario();
    await start(config);
  }

  /// Settings reset stops the SDK and clears saved configuration and session
  /// state. The shell stays open; Configuration then opens with fresh choices.
  ///
  /// Awaits [OctopusSDK.stop] before clearing local state — the SDK instance
  /// this session held is fully torn down, not just abandoned in memory.
  /// Also nulls the fields mirrored from the SDK's static streams
  /// ([_profile], [_groups], [_connectionState], [_isInitialised],
  /// [_notSeenCount], [_hasAccess], [_accessDeniedReason]) rather than waiting on each of them to
  /// emit a final post-stop value — belt and suspenders, since nothing in
  /// their contract guarantees one.
  Future<void> reset() async {
    await _localeUpdates;
    await octopus.stop();
    await _clearConnectedProfile(allUsers: true);
    _debugScenarioOverrides = DebugScenarioOverrides();
    _config = null;
    // The permanent shell remains; fresh choices come from the build config.
    _restoredConfig = null;
    _activeApiKey = null;
    _activeApiServer = null;
    _initialized = false;
    _stopped = false;
    _initError = null;
    _activeOctopusThemeBuilder = null;
    _activeThemeLabel = 'Octopus navy';
    _localeChoice = LocaleChoice.system;
    _localeTagOverride = null;
    _pendingCommunityNotification = null;
    _communityNotification = null;
    _communitySession++;
    _communityNavigation = CommunityNavigation.inTab;
    _profile = null;
    _groups = const [];
    _connectionState = null;
    _isInitialised = false;
    _notSeenCount = null;
    _hasAccess = null;
    _accessDeniedReason = null;
    _hasAccessDeniedReason = false;
    _currentEntitlements = const {};
    _communityConfig = null;
    _communityConfigReadable = true;
    // The next launch uses the build's initial configuration.
    await _clearPersistedDemoConfig();
    for (final key in [
      communityNavigationPreferenceKey,
      sdkLocalePreferenceKey,
      'host_integration_v1',
    ]) {
      await _removeSamplePreference(key);
    }
    _unifiedProfileWired = false;
    _hostProfileEditWired = true;
    _hostGroupAccessWired = true;
    _onAuthenticationRequiredWired = true;
    _onNavigateToContentWired = true;
    _hostUrlHandling = HostUrlHandling.sdk;
    _installContentCallback();
    notifyListeners();
  }

  String _redactKey(String key) => key.isEmpty ? '<empty>' : '<redacted>';

  @override
  void dispose() {
    _disposed = true;
    _countSub?.cancel();
    _accessSub?.cancel();
    _accessDeniedReasonSub?.cancel();
    _profileSub?.cancel();
    _groupsSub?.cancel();
    _connectionStateSub?.cancel();
    _isInitialisedSub?.cancel();
    _cancelNavigateCallback?.call();
    _cancelNavigateCallback = null;
    // AppState owns the checker (it constructs it), so it also disposes it —
    // its listeners are the Home update card's.
    updateChecker.dispose();
    super.dispose();
  }
}

/// Exposes [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.notifier!;
  }

  /// [of] without the assert — for a screen that must also render outside the
  /// app shell (the Config screen, pumped on its own by its widget test).
  static AppState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
}
