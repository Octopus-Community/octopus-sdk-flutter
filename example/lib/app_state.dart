import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'auth/client_user_token_signer.dart';
import 'auth/connect_user_result.dart';
import 'branding.dart';
import 'config/api_key_registry.dart';
import 'octopus_demo_config.dart';
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
/// Enum order is the Config-screen order, and [demo] is the default —
/// a sample must never default to a client-facing backend.
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

/// Immutable choices captured on the Config screen before Start.
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

  /// Host typed on the Config screen for [ServerEnv.custom] — a hostname, not
  /// a credential, so unlike [customApiKey] it IS persisted.
  final String customHost;

  /// Which `OctopusTheme` the embedded SDK surface starts on (Config → Theme
  /// preset). `true` = the sample's Octopus-navy brand theme, `false` = the
  /// SDK's own default. A Theme scenario preset can still override it live.
  final bool octopusNavyTheme;

  const DemoConfig({
    required this.apiKeySource,
    this.customApiKey = '',
    this.selectedInjectedKey,
    required this.userId,
    required this.theme,
    required this.serverEnv,
    this.customHost = '',
    this.octopusNavyTheme = true,
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

  /// Human-readable description of the key choice (Home dashboard).
  String get apiKeyLabel => switch (apiKeySource) {
    ApiKeySource.custom => 'Custom',
    ApiKeySource.demo =>
      selectedInjectedKey?.label ??
          (hasInjectedApiKey
              ? 'Demo (--dart-define)'
              : 'Demo (no key injected)'),
  };

  /// The host the SDK is actually routed to for this configuration — empty
  /// means "pass no `ApiServer`", i.e. the native SDK's own default host
  /// (production).
  ///
  /// [ServerEnv.custom] with nothing typed falls back to the build-time
  /// injected host: that is the shape of a blob persisted by a build from
  /// before this picker existed (`serverEnv: custom`, no `customHost`), which
  /// meant exactly "the injected host". The Config screen refuses to Apply an
  /// empty custom host, so no new config lands here.
  String get resolvedHost => switch (serverEnv) {
    ServerEnv.demo => octopusDemoApiHost,
    ServerEnv.prod => '',
    ServerEnv.custom =>
      customHost.trim().isNotEmpty ? customHost.trim() : octopusDemoApiHost,
  };

  /// The `ApiServer` to hand `initialize` / `switchCommunity` (`null` = the
  /// SDK's default production host).
  ApiServer? get apiServer =>
      resolvedHost.isEmpty ? null : ApiServer(host: resolvedHost);

  /// Human-readable host for the Home / Settings summary rows.
  String get hostLabel =>
      resolvedHost.isEmpty ? '$productionHost (SDK default)' : resolvedHost;

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
    bool? octopusNavyTheme,
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
    octopusNavyTheme: octopusNavyTheme ?? this.octopusNavyTheme,
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
  /// the SOURCE (`custom`) is kept, so the Config screen can restore every
  /// other choice and ask for nothing but the key.
  Map<String, dynamic> toJson() => {
    'apiKeySource': apiKeySource.name,
    'selectedInjectedKeyId': selectedInjectedKey?.id,
    'userId': userId,
    'theme': theme.name,
    'serverEnv': serverEnv.name,
    'customHost': customHost,
    'octopusNavyTheme': octopusNavyTheme,
  };

  /// Rebuilds a config from [toJson] output. Returns `null` on any schema
  /// mismatch (enum renamed, missing field) so a stale persisted blob can never
  /// crash startup — the app just falls back to the Config screen.
  ///
  /// `userId` is back-filled from the build-time [octopusUserId] seed when
  /// missing (old blob written before the picker landed) or empty, so a
  /// pre-existing on-device config never blocks startup just because the
  /// new field isn't there yet.
  static DemoConfig? fromJson(Map<String, dynamic> json) {
    try {
      final injectedId = json['selectedInjectedKeyId'] as String?;
      InjectedApiKey? injected;
      for (final k in injectedApiKeys) {
        if (k.id == injectedId) {
          injected = k;
          break;
        }
      }
      final rawUserId = (json['userId'] as String?)?.trim() ?? '';
      final resolvedUserId = rawUserId.isEmpty ? octopusUserId : rawUserId;
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
        serverEnv: ServerEnv.values.byName(json['serverEnv'] as String),
        // Both fields post-date the first schema, so a blob written by an
        // older build carries neither — read them leniently rather than
        // sending the whole config back to the Config screen over a field
        // whose absence has a perfectly good default.
        customHost: (json['customHost'] as String?)?.trim() ?? '',
        // `octopusNavyTheme` was `octopusTealTheme` before the navy rollout —
        // a blob written by a pre-rename build still carries the old key, and
        // reading only the new one would silently reset an existing "SDK
        // default" (`false`) choice back to the navy default. Fall back to
        // the pre-navy key before the hardcoded default.
        octopusNavyTheme:
            json['octopusNavyTheme'] as bool? ??
            json['octopusTealTheme'] as bool? ??
            true,
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
/// app back to the Config screen either way, so keeping it buys nothing and it
/// may still hold that plaintext key.
///
/// A top-level function rather than a method on [AppState]: that strip is the
/// security-relevant half of the change, and reaching it through [AppState]
/// would mean standing up the SDK singleton and its channels just to assert on
/// a prefs entry — so it would have shipped untested.
@visibleForTesting
Future<DemoConfig?> loadPersistedDemoConfig() async {
  final raw = await _readPersistedConfigBlob();
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final restored = DemoConfig.fromJson(json);
    if (restored == null) {
      await _clearPersistedDemoConfig();
      return null;
    }
    if (json.containsKey('customApiKey')) {
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
Future<void> _persistDemoConfig(DemoConfig config) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(demoConfigPrefsKey, jsonEncode(config.toJson()));
  } catch (e) {
    demoLog.apiCall('persistConfig failed', {'error': '$e'});
  }
}

/// Clears the persisted config (Settings → Reset → first-launch flow).
Future<void> _clearPersistedDemoConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(demoConfigPrefsKey);
  } catch (_) {}
}

/// Shared, reactive app state for the whole sample.
///
/// A plain [ChangeNotifier] (a Flutter foundation type — no state-management
/// package) surfaced to the widget tree through [AppScope]. Owns the single
/// [OctopusSDK] instance, the chosen [DemoConfig], init/connection status, and
/// the SDK stream values that the Home dashboard and scenario result panels
/// read.
class AppState extends ChangeNotifier {
  final OctopusSDK octopus = OctopusSDK();

  DemoConfig? _config;
  DemoConfig? get config => _config;

  /// True while [bootstrap] is still restoring a persisted config. The app
  /// shows a splash during this window so a saved session doesn't flash the
  /// Config screen before auto-starting back into the app.
  bool _restoringConfig = true;
  bool get restoringConfig => _restoringConfig;

  /// The persisted config restored at bootstrap when it could NOT be
  /// auto-started — i.e. it resolves to no API key. That covers the
  /// [ApiKeySource.custom] case, now that the pasted key is never persisted
  /// (see [DemoConfig.toJson]), and also a build that ships no key at all
  /// (a bare `flutter run`, where the demo source resolves to nothing
  /// either). Seeds the Config screen so the user gets every other choice
  /// back and only re-enters the key.
  DemoConfig? _restoredConfig;
  DemoConfig? get restoredConfig => _restoredConfig;

  /// Live snapshot of the API key the SDK is currently initialized against.
  ///
  /// Distinct from [DemoConfig.effectiveApiKey] (which captures the user's
  /// initial Config-screen choice — a SOURCE, not a value). This field
  /// survives [switchToCommunity] so the rest of the sample can always tell
  /// which community the SDK is actually talking to right now.
  String? _activeApiKey;
  String? get activeApiKey => _activeApiKey;

  bool _bootstrapped = false;

  bool _initialized = false;
  bool get initialized => _initialized;

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
  String get activeThemeLabel => _activeThemeLabel;

  LocaleChoice _localeChoice = LocaleChoice.system;
  LocaleChoice get localeChoice => _localeChoice;

  OctopusNotification? _pendingCommunityNotification;
  OctopusNotification? get pendingCommunityNotification =>
      _pendingCommunityNotification;

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
    _cancelNavigateCallback = OctopusSDK.setNavigateToClientObjectCallback((
      objectId,
    ) {
      demoLog.apiCall('navigateToClientObject', {'objectId': objectId});
      _lastNavigateObjectId = objectId;
      _navigateFireCount += 1;
      notifyListeners();
    });
    _logoBase64 = await loadLogoBase64();
    final packageInfo = await PackageInfo.fromPlatform();
    _sampleVersionLabel = '${packageInfo.version}+${packageInfo.buildNumber}';
    // One check per launch, not awaited: it is a network round-trip to Play and
    // nothing downstream of bootstrap depends on its answer. The card renders
    // "checking" and then whatever came back.
    unawaited(updateChecker.check());
    // Restore the last config and auto-start so a relaunch lands straight back
    // in the app instead of the Config screen — and so a cold-start push tap
    // can deep-link (the main shell, which routes the pending notification,
    // only mounts once a config exists). `start` is null-safe and swallows its
    // own init errors. Reconfigure via Settings → Reset (which clears this).
    final restored = await loadPersistedDemoConfig();
    _restoringConfig = false;
    // D2③ (cadrage report 07, narrowed by report 18's D3): a build that
    // EXPLICITLY injects the real production host
    // (`--dart-define=OCTOPUS_API_HOST=api.8pus.io`) never auto-restores a
    // persisted config, unconditionally — mirrors Android's
    // `SampleApplication`, which clears any persisted env on a `prod`-flavor
    // launch regardless of which flavor wrote it. Flutter has no separate
    // flavor artifact, but the same on-device risk exists: demo and prod
    // builds share one bundle/application id, so installing a build pinned
    // to the real prod host over a demo-hostname one leaves the demo build's
    // persisted blob sitting in the same SharedPreferences file. Erase it
    // here rather than let it auto-start against the prod host with the
    // previous build's identity/key choices.
    //
    // Deliberately narrower than [octopusIsProdServer] (which is also true
    // for the empty-define case — a bare `flutter run`, or a keyless public
    // clone): that case has no explicit host opinion at all, so it must not
    // wipe a persisted config on every launch just because none was passed
    // this time. Only an explicit, exact match on the production literal
    // erases; the bundled SDK's own fail-safe (prod unless told otherwise)
    // still applies everywhere else and is unaffected by this check.
    if (octopusApiHost.trim() == 'api.8pus.io' && restored != null) {
      demoLog.apiCall('bootstrap', {
        'warning':
            'prod build — erasing persisted demo config, falling back to '
            'the blank Config screen (D2③)',
      });
      await _clearPersistedDemoConfig();
      _restoredConfig = null;
      notifyListeners();
      return;
    }
    // Only auto-start a config that still resolves to a key. A custom-key
    // config never does (the pasted key isn't persisted), and auto-starting it
    // would re-enter the SDK — production by default, see [octopusApiHost] —
    // on an empty key. Land on the Config screen instead, seeded with the
    // restored choices. Trimmed, like every other key check in the sample
    // (`_start` on the Config screen, [octopusApiHost] below): a build that
    // injects a whitespace-only key resolves to no usable key either.
    if (restored != null && restored.effectiveApiKey.trim().isNotEmpty) {
      await start(restored);
    } else {
      _restoredConfig = restored;
      notifyListeners();
    }
  }

  /// Applies [config] and initialises the SDK (host-managed / SSO auth).
  ///
  /// Branches on [_initialized]: a first Start (or one after [reset], which
  /// clears it) goes through the `initialize()` path below. A Start reached
  /// via [backToConfig] — SDK still mounted, [_initialized] still true —
  /// instead performs a live [switchToCommunity], the non-destructive half
  /// of D5 (see [backToConfig]'s doc comment; mirrors Android's
  /// `SampleApplication` reactive collector).
  Future<void> start(DemoConfig config) async {
    if (_initialized) {
      await _startViaSwitch(config);
      return;
    }
    _config = config;
    _initError = null;
    _initialized = false;
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
      _activeApiKey = config.effectiveApiKey;
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
  /// "Back to Config" round-trip) — switches community live instead of
  /// re-`initialize()`-ing, via the existing [switchToCommunity].
  Future<void> _startViaSwitch(DemoConfig config) async {
    _config = config;
    _initError = null;
    notifyListeners();
    try {
      demoLog.apiCall('switchCommunity (Back to Config → Start)', {
        'apiKey': _redactKey(config.effectiveApiKey),
      });
      // No explicit apiServer: [switchToCommunity] already defaults it to
      // the same --dart-define-resolved host [start] uses — computing it
      // again here would just duplicate that default and risk drifting
      // from it.
      await switchToCommunity(config.effectiveApiKey);
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
  /// — the SDK will re-invoke the provider on every refresh (e.g.
  /// `refreshEntitlements()`) so a change to [_currentEntitlements] takes
  /// effect without reconnecting. Falls back to a trivial provider returning
  /// the pre-baked [octopusUserToken] when no SSO secret was injected at build
  /// time (the signer can't sign anyway, but the pre-baked token is still
  /// useful for QA).
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
    final OctopusResult<void, ClientUserError> result;
    if (hasInjectedSsoSecret) {
      demoLog.apiCall('connectUser (tokenProvider)', {
        'userId': userId,
        'entitlements': _currentEntitlements.toList()..sort(),
        if (nickname != null) 'nickname': nickname,
        if (bio != null) 'bio': bio,
        if (picture != null) 'picture': '<set>',
      });
      result = await octopus.connectUser(
        userId: userId,
        tokenProvider: () async => ClientUserTokenSigner.signClientUserToken(
          userId: userId,
          entitlements: _currentEntitlements,
        ),
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
    } else {
      // Keyless / public build: no secret to sign with — connect with a
      // trivial provider returning the pre-baked JWT (from
      // `--dart-define=OCTOPUS_USER_TOKEN=…`). When that token is empty, the
      // SDK surfaces `RefreshEntitlementsNoClientTokenProviderError` on
      // refresh; that's the documented keyless-build behavior.
      demoLog.apiCall('connectUser (pre-baked token)', {
        'userId': userId,
        'token': octopusUserToken.isEmpty ? '<empty>' : '<redacted>',
      });
      result = await octopus.connectUser(
        userId: userId,
        tokenProvider: () async => octopusUserToken,
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
    }
    _lastConnectError = describeConnectUserFailure(result);
    notifyListeners();
    return result;
  }

  /// Disconnects the current user. Rethrows on failure. [userConnected] is
  /// derived from [connectionState] which emits independently.
  Future<void> disconnectUser() async {
    demoLog.apiCall('disconnectUser');
    await octopus.disconnectUser();
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
    _activeApiKey = apiKey;
    notifyListeners();
  }

  /// Changes the app's light/dark choice from Settings → Appearance, without
  /// going back through Config.
  ///
  /// Persists it on the live [DemoConfig] so the pick survives a relaunch, and
  /// re-poses the SDK theme: [effectiveOctopusTheme] resolves its quadruple
  /// against the forced brightness, so a preset picked in light mode still
  /// hands the SDK its dark colors once Dark is pinned.
  void setThemeChoice(AppThemeChoice choice) {
    final config = _config;
    if (config == null || config.theme == choice) return;
    _config = config.copyWith(theme: choice);
    unawaited(_persistDemoConfig(_config!));
    notifyListeners();
  }

  /// Overrides the SDK UI locale (Locale scenario + Settings picker).
  Future<void> setLocale(LocaleChoice choice) async {
    demoLog.apiCall('overrideDefaultLocale', {'locale': choice.label});
    await octopus.overrideDefaultLocale(choice.locale);
    _localeChoice = choice;
    notifyListeners();
  }

  /// Whether the host wires `onNavigateToProfile` on the embedded Community
  /// view — the Unified Profile activation switch.
  ///
  /// Off by default so the sample shows the SDK's native profile screens, which
  /// is what an existing integration sees. Flipping it on makes the host handle
  /// every profile tap instead. Mirrors the native samples' Config-screen
  /// "profile wired" toggle.
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
    notifyListeners();
  }

  /// The other 6 rows of Config → Host callbacks
  /// (`onNavigateToContent`, `onAuthenticationRequired`,
  /// `onPushNotificationTapped`, `onUnreadCountChanged`, `onEvent`,
  /// `onError`).
  ///
  /// **Known spec/SDK gap**: unlike [unifiedProfileWired]
  /// (`onNavigateToProfile`), the Flutter SDK does not yet expose a
  /// constructor parameter for any of these — `OctopusSDK`/`OctopusHomeScreen`
  /// only take `onNavigateToProfile` today. These 6 flags therefore do not
  /// change SDK behaviour; they exist so the Config screen can show the same
  /// 7-row layout as the other platforms (design parity) and so Debug info can
  /// report what the app *would* wire once the SDK grows the callback. Wiring
  /// real behaviour behind them is follow-up work, not part of this pass —
  /// flagged rather than silently faked.
  ///
  /// Defaults mirror the design spec: the 5 navigation/auth-flavoured
  /// callbacks default on, the 2 telemetry ones (`onEvent`, `onError`)
  /// default off.
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
    notifyListeners();
  }

  void setOnAuthenticationRequiredWired(bool v) {
    _onAuthenticationRequiredWired = v;
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

  /// Comma-separated summary of every wired host callback, for Debug info.
  ///
  /// Only [unifiedProfileWired] (`onNavigateToProfile`) actually reaches the
  /// Flutter binding today — the other six toggles are UI-only (see
  /// `ConfigScreen`'s Host callbacks section), so each is suffixed
  /// `(ui-only)` here too: a copied debug dump must not read as if the SDK
  /// received them.
  String get hostCallbacksSummary {
    final wired = <String>[
      if (unifiedProfileWired) 'onNavigateToProfile',
      if (onNavigateToContentWired) 'onNavigateToContent (ui-only)',
      if (onAuthenticationRequiredWired) 'onAuthenticationRequired (ui-only)',
      if (onPushNotificationTappedWired) 'onPushNotificationTapped (ui-only)',
      if (onUnreadCountChangedWired) 'onUnreadCountChanged (ui-only)',
      if (onEventWired) 'onEvent (ui-only)',
      if (onErrorWired) 'onError (ui-only)',
    ];
    return wired.isEmpty ? 'none' : wired.join(', ');
  }

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
  int _requestedTab = 0;
  int get requestedTab => _requestedTab;

  /// Asks the shell to switch to [index] (canonical order: Home 0, Scenarios
  /// 1, Community 2, Settings 3).
  void requestTab(int index) {
    _requestedTab = index;
    _navEpoch++;
    notifyListeners();
  }

  /// Asks the shell to switch to the Community tab, optionally deep-linked to
  /// the content referenced by [notification] (push tap).
  void requestCommunityTab(OctopusNotification? notification) {
    _requestedTab = 2;
    _pendingCommunityNotification = notification;
    _navEpoch++;
    notifyListeners();
  }

  /// Clears a consumed deep link so returning to Community shows its root.
  void clearPendingNotification() {
    if (_pendingCommunityNotification == null) return;
    _pendingCommunityNotification = null;
    notifyListeners();
  }

  /// Destructive reset (`settings-reset-button`, D5, cadrage report 07):
  /// unmounts the native SDK, clears the persisted config blob, and returns
  /// to a blank Config screen — the first-launch flow. Distinct from
  /// [backToConfig], the non-destructive sibling action: this one throws the
  /// persisted blob away (so the *next* launch also starts blank, not just
  /// this session) and clears [restoredConfig] rather than seeding it, so
  /// Config re-opens empty rather than pre-filled.
  ///
  /// Awaits [OctopusSDK.stop] before clearing local state — the SDK instance
  /// this session held is fully torn down, not just abandoned in memory.
  /// Also nulls the fields mirrored from the SDK's static streams
  /// ([_profile], [_groups], [_connectionState], [_isInitialised],
  /// [_notSeenCount], [_hasAccess]) rather than waiting on each of them to
  /// emit a final post-stop value — belt and suspenders, since nothing in
  /// their contract guarantees one.
  Future<void> reset() async {
    await octopus.stop();
    _config = null;
    // Reset means first-launch flow: don't re-seed the Config screen from the
    // config being thrown away.
    _restoredConfig = null;
    _activeApiKey = null;
    _initialized = false;
    _initError = null;
    _activeOctopusThemeBuilder = null;
    _activeThemeLabel = 'Octopus navy';
    _localeChoice = LocaleChoice.system;
    _pendingCommunityNotification = null;
    _profile = null;
    _groups = const [];
    _connectionState = null;
    _isInitialised = false;
    _notSeenCount = null;
    _hasAccess = null;
    _currentEntitlements = const {};
    // Forget the saved config so the next launch shows the first-launch flow.
    await _clearPersistedDemoConfig();
    notifyListeners();
  }

  /// Non-destructive "Back to Config" (`settings-reconfigure-button`, D5,
  /// cadrage report 07): returns to the Config screen *without* unmounting
  /// the SDK.
  ///
  /// Mirrors the Android sample's own "Back to Config" exactly: there,
  /// `onNavigateToConfig` is a plain navigation call
  /// (`ui/navigation/MainScaffold.kt`) — no `stop()`, no `reset()`. The
  /// non-destructive half of D5 is delivered entirely by `Start SDK`
  /// resolving to a live `OctopusSDK.switchCommunity(...)` instead of a
  /// fresh `initialize()` once the SDK is already up (Android's
  /// `SampleApplication`: `if (isInitialised) switchCommunity else
  /// initialize`) — "le socle existe", cadrage report 07 §D5. [start] below
  /// applies the same branch via the existing [switchToCommunity].
  ///
  /// Only [_config] changes here, to flip the root's routing (`main.dart`:
  /// `config == null` routes to [ConfigScreen]) — [_initialized],
  /// [_activeApiKey] and the streamed session values are left untouched
  /// because the underlying instance is still live and still theirs.
  /// [restoredConfig] is seeded with the config being left, so Config
  /// re-opens with every choice (server, theme, locale, user id, key
  /// source) still filled in — the distinction from [reset], which clears
  /// it instead.
  void backToConfig() {
    _restoredConfig = _config;
    _config = null;
    notifyListeners();
  }

  String _redactKey(String key) =>
      key.isEmpty ? '<empty>' : '${key.substring(0, key.length.clamp(0, 4))}…';

  @override
  void dispose() {
    _countSub?.cancel();
    _accessSub?.cancel();
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
