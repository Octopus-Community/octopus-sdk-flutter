import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'auth/client_user_token_signer.dart';
import 'branding.dart';
import 'config/api_key_registry.dart';
import 'octopus_demo_config.dart';

/// Where the API key passed to the SDK comes from.
enum ApiKeySource {
  /// A key injected at build time via `--dart-define` — either the generic
  /// `OCTOPUS_API_KEY` or one of the named picker keys (see
  /// [DemoConfig.selectedInjectedKey]).
  demo,

  /// A key the developer pastes into the Config screen (consumer flow).
  custom,
}

/// Backend environment the sample documents it is pointing at.
///
/// Fixed at build time: [start] routes the SDK to the host injected via
/// `--dart-define=OCTOPUS_API_HOST` (see [octopusApiHost]) when one is set,
/// otherwise the native SDK's default (production) host. The Config-screen
/// picker is therefore display-only — recorded for the Settings card and
/// cross-platform Config parity, not a runtime host switch.
enum ServerEnv { custom, prod }

/// Material brightness chosen on the Config screen.
enum AppThemeChoice { system, light, dark }

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

  const DemoConfig({
    required this.apiKeySource,
    this.customApiKey = '',
    this.selectedInjectedKey,
    required this.userId,
    required this.theme,
    required this.serverEnv,
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
  /// NOTE: for [ApiKeySource.custom], `customApiKey` IS persisted verbatim to
  /// plaintext on-device prefs. That's acceptable here — a sample where the
  /// consumer knowingly pastes their own key — but do NOT copy this pattern
  /// into a production integration expecting the stored key to be protected.
  Map<String, dynamic> toJson() => {
    'apiKeySource': apiKeySource.name,
    'customApiKey': customApiKey,
    'selectedInjectedKeyId': selectedInjectedKey?.id,
    'userId': userId,
    'theme': theme.name,
    'serverEnv': serverEnv.name,
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
        customApiKey: (json['customApiKey'] as String?) ?? '',
        selectedInjectedKey: injected,
        userId: resolvedUserId,
        theme: AppThemeChoice.values.byName(json['theme'] as String),
        serverEnv: ServerEnv.values.byName(json['serverEnv'] as String),
      );
    } catch (_) {
      return null;
    }
  }
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

  /// SharedPreferences key for the persisted [DemoConfig] (versioned so a
  /// future schema change can bump it without colliding with stale blobs).
  static const String _configPrefsKey = 'octopus_demo_config_v1';

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
  /// !state.isGuest`). Note the documented platform asymmetry: iOS never sets
  /// `isGuest`, so there a guest still reads as connected.
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

  OctopusTheme? _activeOctopusTheme;
  OctopusTheme? get activeOctopusTheme => _activeOctopusTheme;

  /// Resolves the [OctopusTheme] to apply to the embedded SDK surface,
  /// combining the Theme-scenario brand theme (if any) with the host's
  /// Light/Dark/System choice from the Config screen so the SDK content
  /// tracks the same light/dark mode as the surrounding Flutter chrome.
  ///
  /// - **System** — returns the active brand theme as-is (or `null` when no
  ///   brand is set), so the native SDK falls back to its own system-trait
  ///   observation (Compose `isSystemInDarkTheme()` on Android,
  ///   `UITraitCollection` on iOS) — same behaviour as Flutter's
  ///   `MaterialApp.themeMode = system`.
  /// - **Light / Dark** — forces [OctopusThemeMode] on the active brand
  ///   theme (or on an empty [OctopusTheme] when no brand is set), so the
  ///   SDK renders in the chosen mode regardless of the device setting.
  ///   Without this propagation, picking "Light" on a dark device would
  ///   leave the SDK rendering dark (it observes the system) while the
  ///   Flutter chrome flips light — a visible mismatch.
  OctopusTheme? effectiveOctopusTheme() {
    final forced = _config?.forcedBrightness;
    if (forced == null) return _activeOctopusTheme;
    final mode = forced == Brightness.dark
        ? OctopusThemeMode.dark
        : OctopusThemeMode.light;
    return (_activeOctopusTheme ?? const OctopusTheme()).copyWith(
      themeMode: mode,
    );
  }

  String _activeThemeLabel = 'SDK default';
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
    // Restore the last config and auto-start so a relaunch lands straight back
    // in the app instead of the Config screen — and so a cold-start push tap
    // can deep-link (the main shell, which routes the pending notification,
    // only mounts once a config exists). `start` is null-safe and swallows its
    // own init errors. Reconfigure via Settings → Reset (which clears this).
    final restored = await _loadPersistedConfig();
    _restoringConfig = false;
    if (restored != null) {
      await start(restored);
    } else {
      notifyListeners();
    }
  }

  /// Loads the persisted [DemoConfig] (null if none / corrupt / schema drift).
  Future<DemoConfig?> _loadPersistedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      return DemoConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Persists [config] so the next launch auto-restores it. Best-effort: a
  /// storage failure logs but never blocks the run.
  Future<void> _persistConfig(DemoConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configPrefsKey, jsonEncode(config.toJson()));
    } catch (e) {
      demoLog.apiCall('persistConfig failed', {'error': '$e'});
    }
  }

  /// Clears the persisted config (Settings → Reset → first-launch flow).
  Future<void> _clearPersistedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configPrefsKey);
    } catch (_) {}
  }

  /// Applies [config] and initialises the SDK (host-managed / SSO auth).
  Future<void> start(DemoConfig config) async {
    _config = config;
    _initError = null;
    _initialized = false;
    notifyListeners();

    try {
      // Route the SDK to a non-production host when one was injected at build
      // time via `--dart-define=OCTOPUS_API_HOST`; the published native SDK
      // defaults to prod (`api.8pus.io`) when no apiServer is passed, so an
      // internal QA build must steer the SDK to its backend explicitly via
      // `ApiServer`. Empty host → prod default. The host value is injected at
      // build time and never committed.
      final apiServer = octopusApiHost.trim().isNotEmpty
          ? ApiServer(host: octopusApiHost.trim())
          : null;
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
      unawaited(_persistConfig(config));

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
  /// Rethrows so callers can surface the error. The reactive
  /// [connectionState] stream — the source of truth for [userConnected] —
  /// emits independently on success.
  Future<void> connectDemoUser({Set<String> entitlements = const {}}) async {
    _currentEntitlements = Set.unmodifiable(entitlements);
    final userId = effectiveUserId;
    if (hasInjectedSsoSecret) {
      demoLog.apiCall('connectUser (tokenProvider)', {
        'userId': userId,
        'entitlements': _currentEntitlements.toList()..sort(),
      });
      await octopus.connectUser(
        userId: userId,
        tokenProvider: () async => ClientUserTokenSigner.signClientUserToken(
          userId: userId,
          entitlements: _currentEntitlements,
        ),
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
      await octopus.connectUser(
        userId: userId,
        tokenProvider: () async => octopusUserToken,
      );
    }
    notifyListeners();
  }

  /// Disconnects the current user. Rethrows on failure. [userConnected] is
  /// derived from [connectionState] which emits independently.
  Future<void> disconnectUser() async {
    demoLog.apiCall('disconnectUser');
    await octopus.disconnectUser();
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
  /// [apiServer] defaults to the same host routing [start] applies (the host
  /// injected via `--dart-define=OCTOPUS_API_HOST`, if any) — otherwise a
  /// switch from a non-prod init would silently fall back to prod and produce
  /// a host↔community mismatch.
  Future<void> switchToCommunity(
    String apiKey, {
    List<ProfileField> appManagedFields = const [],
    ApiServer? apiServer,
  }) async {
    final resolvedServer =
        apiServer ??
        (octopusApiHost.trim().isNotEmpty
            ? ApiServer(host: octopusApiHost.trim())
            : null);
    await octopus.switchCommunity(
      apiKey: apiKey,
      appManagedFields: appManagedFields,
      apiServer: resolvedServer,
    );
    _activeApiKey = apiKey;
    notifyListeners();
  }

  /// Overrides the SDK UI locale (Locale scenario + Settings picker).
  Future<void> setLocale(LocaleChoice choice) async {
    demoLog.apiCall('overrideDefaultLocale', {'locale': choice.label});
    await octopus.overrideDefaultLocale(choice.locale);
    _localeChoice = choice;
    notifyListeners();
  }

  /// Sets the custom [OctopusTheme] applied to the embedded Community view.
  void setActiveOctopusTheme(OctopusTheme? theme, String label) {
    _activeOctopusTheme = theme;
    _activeThemeLabel = label;
    notifyListeners();
  }

  /// Asks the shell to switch to the Community tab, optionally deep-linked to
  /// the content referenced by [notification] (push tap).
  void requestCommunityTab(OctopusNotification? notification) {
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

  /// Returns to the Config screen (first-launch flow) and clears session state.
  /// [userConnected] follows [connectionState] — the SDK emits the
  /// not-connected state on disconnect; no need to mirror it here.
  void reset() {
    _config = null;
    _activeApiKey = null;
    _initialized = false;
    _initError = null;
    _activeOctopusTheme = null;
    _activeThemeLabel = 'SDK default';
    _localeChoice = LocaleChoice.system;
    _pendingCommunityNotification = null;
    // Forget the saved config so the next launch shows the first-launch flow.
    unawaited(_clearPersistedConfig());
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
}
