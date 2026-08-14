import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import 'app_log.dart';
import 'app_state.dart';
import 'branding.dart';
import 'community/community_screen.dart';
import 'config/config_screen.dart';
import 'debug/debug_log.dart';
import 'debug/debug_tab.dart';
import 'home/home_screen.dart';
import 'octopus_demo_config.dart';
import 'scenarios/scenarios_screen.dart';
import 'settings/settings_screen.dart';
import 'widgets/production_warning_banner.dart';

/// MethodChannel the iOS AppDelegate uses to forward the APNs token + taps.
const MethodChannel _pushChannel = MethodChannel(
  'octopus_sdk_flutter_example/push',
);

/// Lets push handlers act outside a widget build context (cold-start handling).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Renders incoming Octopus pushes as system notifications. Octopus sends
/// **data-only** FCM messages, which Android does not auto-display, and in a
/// Flutter app the `firebase_messaging` plugin (not the native Octopus
/// `MessagingService`) receives the message — so the host app must build and
/// show the notification itself. Consumers wiring push must do the same.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _octopusChannel = AndroidNotificationChannel(
  'octopus-sdk',
  'Octopus Community',
  importance: Importance.high,
);

/// Initialises the local-notifications plugin in the current isolate (the app
/// isolate and the FCM background isolate each need their own init). Pass
/// [onTap] in the app isolate to route taps; the background isolate omits it
/// (a tap there relaunches the app and is delivered via launch details).
Future<void> _initLocalNotifications({
  DidReceiveNotificationResponseCallback? onTap,
}) async {
  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: onTap,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_octopusChannel);
}

/// Shows a system notification for an Octopus push payload (no-op for
/// non-Octopus payloads). Pure parse + display, so it is safe to call from the
/// FCM background isolate. The notification carries the Octopus keys as its
/// `payload` so a tap can reconstruct and deep-link them.
Future<void> showOctopusPushNotification(Map<String, Object?> payload) async {
  if (!OctopusSDK.isOctopusNotification(payload)) return;
  final n = OctopusSDK.getOctopusNotification(payload);
  if (n == null) return;
  await _localNotifications.show(
    n.linkPath.hashCode,
    n.title.isEmpty ? 'Octopus Community' : n.title,
    n.body.isEmpty ? null : n.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _octopusChannel.id,
        _octopusChannel.name,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(n.rawPayload),
  );
}

/// Flattens an FCM message to the flat map the Octopus parser expects, folding
/// any `notification` title/body into the data keys.
Map<String, Object?> _flatFcmData(RemoteMessage message) {
  final data = <String, Object?>{...message.data};
  final n = message.notification;
  if (n?.title != null) data.putIfAbsent('title', () => n!.title as Object);
  if (n?.body != null) data.putIfAbsent('body', () => n!.body as Object);
  return data;
}

/// FCM background-isolate handler — must be top-level and `vm:entry-point`.
/// Displays the Octopus notification when the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> octopusFcmBackgroundHandler(RemoteMessage message) async {
  await _initLocalNotifications();
  await showOctopusPushNotification(_flatFcmData(message));
}

/// Public showcase entrypoint. The QA/debug build uses
/// `lib/debug/internal/main_debug.dart`, which installs the Debug console then
/// calls [runOctopusDemo].
Future<void> main() => runOctopusDemo();

/// Boots the sample app. Shared by the public and debug entrypoints.
Future<void> runOctopusDemo() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start the persistent debug recorder before the SDK can emit anything, so
  // the Debug tab (a public bottom-nav tab) and the Events scenario capture the
  // whole session. Both `OctopusSDK.eventStream` and the typed `events` stream
  // are non-replaying broadcasts — a late subscriber misses prior emissions —
  // so we subscribe once, here, at launch, and route the sample's API-call log
  // into the same recorder. Idempotent with the debug entrypoint's
  // `installDebugConsole()` (which additionally installs the internal-only
  // Settings → "Open debug console" sheet).
  debugLog.start();
  demoLog = debugLog;
  // Firebase Messaging powers the Android push path. iOS uses the native APNs
  // wiring in AppDelegate.swift; Firebase is not initialized on iOS here (no
  // GoogleService-Info.plist bundled). The Android init is best-effort: without
  // a google-services.json it throws, which we swallow so the app still runs.
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      // Render Octopus pushes that arrive while the app is backgrounded /
      // terminated (data-only FCM → not auto-displayed by the system).
      FirebaseMessaging.onBackgroundMessage(octopusFcmBackgroundHandler);
    } catch (e) {
      debugPrint('[Push] Firebase.initializeApp failed: $e');
    }
  }
  runApp(const OctopusDemoApp());
}

/// Root widget: owns [AppState], wires push notifications, and chooses between
/// the Config screen and the main bottom-nav shell.
class OctopusDemoApp extends StatefulWidget {
  const OctopusDemoApp({super.key});

  @override
  State<OctopusDemoApp> createState() => _OctopusDemoAppState();
}

class _OctopusDemoAppState extends State<OctopusDemoApp> {
  late final AppState _app;

  /// Latest push token (FCM on Android, APNs on iOS); (re)registered with the
  /// SDK once it is initialised.
  String? _pushToken;
  StreamSubscription<bool>? _pushInitSub;
  StreamSubscription<OctopusConnectionState>? _pushConnSub;

  @override
  void initState() {
    super.initState();
    _app = AppState()..addListener(_onAppChanged);
    _app.bootstrap();
    _setupPush();
  }

  void _onAppChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pushInitSub?.cancel();
    _pushConnSub?.cancel();
    _app.removeListener(_onAppChanged);
    _app.dispose();
    super.dispose();
  }

  // ── Push notifications ────────────────────────────────────────────────────

  Future<void> _setupPush() async {
    // Both platforms: (re)register the push token on every init signal (incl.
    // switchCommunity re-init). Registration only sticks once the SDK is
    // initialised — see [_registerPushTokenIfReady].
    _pushInitSub = OctopusSDK.isInitialisedFlow.listen((initialised) {
      if (initialised) _registerPushTokenIfReady();
    });
    // Also re-register when the connection changes (e.g. guest → logged-in
    // user): the token must be tied to the currently-connected user so the
    // backend routes that user's notifications to this device.
    _pushConnSub = OctopusSDK.connectionState.listen(
      (_) => _registerPushTokenIfReady(),
    );
    if (Platform.isIOS) {
      _pushChannel.setMethodCallHandler(_onPushChannelCall);
      await _drainInitialIosNotification();
    } else if (Platform.isAndroid) {
      await _setupFirebaseMessaging();
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission();
      // Keep the latest FCM token and (re)register it with the SDK only once
      // the SDK is initialised. `registerPushNotificationToken` reaches the
      // native `registerNotificationsToken`, which requires an initialised SDK
      // (it throws if `sdkScope` isn't set yet). Push setup runs at startup —
      // before the Config screen's "Start" initialises the SDK — so registering
      // here unconditionally silently drops the token and delivery never
      // starts. Register on every init signal (incl. switchCommunity re-init)
      // and on token refresh instead.
      _pushToken = await messaging.getToken();
      messaging.onTokenRefresh.listen((token) {
        _pushToken = token;
        _registerPushTokenIfReady();
      });
      _registerPushTokenIfReady();

      // Display + tap routing. Octopus FCM messages are data-only, so the host
      // builds the system notification itself ([showOctopusPushNotification]);
      // tapping it deep-links via [_onNotifTap].
      await _initLocalNotifications(onTap: _onNotifTap);
      FirebaseMessaging.onMessage.listen(
        (m) => showOctopusPushNotification(_payloadFromFcm(m)),
      );
      // A notification-block FCM tapped from background routes straight through.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _handleNotification(_payloadFromFcm(m)),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleNotification(_payloadFromFcm(initial));
      // Cold start from tapping a notification this app rendered itself.
      final launch = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final response = launch!.notificationResponse;
        if (response != null) _onNotifTap(response);
      }
    } catch (e) {
      debugPrint('[Push] Firebase messaging setup failed: $e');
    }
  }

  /// Routes a tapped local notification to the deep-link handler, decoding the
  /// Octopus keys stored in the notification payload.
  void _onNotifTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) _handleNotification(decoded);
    } catch (e) {
      debugPrint('[Push] could not decode tapped notification payload: $e');
    }
  }

  /// Registers the latest FCM token with the SDK, but only when the SDK is
  /// initialised — a pre-init call throws natively and silently drops the
  /// token, so push delivery never starts. Idempotent: safe to call on each
  /// init / token-refresh signal.
  ///
  /// Reads `OctopusSDK.isInitialised` directly rather than `_app.isInitialised`
  /// to avoid a listener-ordering race: `_app.isInitialised` is updated by
  /// AppState's own subscription to `isInitialisedFlow`, and Dart does not
  /// guarantee firing order between two listeners on the same stream. The
  /// static getter reflects the value set **before** subscribers are notified
  /// (see `octopus_sdk.dart:151`), so reading it here is race-free.
  void _registerPushTokenIfReady() {
    final token = _pushToken;
    if (token == null || token.isEmpty || !OctopusSDK.isInitialised) return;
    _app.octopus
        .registerPushNotificationToken(token)
        .then((_) => debugPrint('[Push] push token registered with the SDK'))
        .catchError(
          (e) => debugPrint('[Push] registerPushNotificationToken failed: $e'),
        );
  }

  Future<void> _drainInitialIosNotification() async {
    try {
      final raw = await _pushChannel.invokeMethod('getInitialNotification');
      if (raw is Map) _handleNotification(raw);
    } catch (e) {
      debugPrint('[Push] getInitialNotification failed: $e');
    }
  }

  Future<dynamic> _onPushChannelCall(MethodCall call) async {
    switch (call.method) {
      case 'apnsToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          // Same init-gating as Android: store and (re)register once the SDK is
          // initialised, so an APNs token arriving before the Config "Start"
          // isn't dropped by the native pre-init guard.
          _pushToken = token;
          _registerPushTokenIfReady();
        }
      case 'notificationTapped':
        final raw = call.arguments;
        if (raw is Map) _handleNotification(raw);
    }
    return null;
  }

  /// Merges an FCM `RemoteMessage` into the flat map shape the SDK parses,
  /// folding `notification.title`/`body` into the `data` keys.
  Map<String, Object?> _payloadFromFcm(RemoteMessage message) {
    final payload = <String, Object?>{...message.data};
    final notification = message.notification;
    if (notification != null) {
      final title = notification.title;
      final body = notification.body;
      if (title != null) payload.putIfAbsent('title', () => title);
      if (body != null) payload.putIfAbsent('body', () => body);
    }
    return payload;
  }

  /// Deep-links a tapped Octopus notification into the Community tab.
  void _handleNotification(Map payload) {
    if (!OctopusSDK.isOctopusNotification(payload)) return;
    final notification = OctopusSDK.getOctopusNotification(payload);
    if (notification != null) _app.requestCommunityTab(notification);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  ThemeMode get _themeMode => switch (_app.config?.theme) {
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark => ThemeMode.dark,
    AppThemeChoice.system || null => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _app,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Octopus SDK Sample',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: _themeMode,
        // Pin the production/client-env warning above every route. The banner
        // consumes the top inset, so the routed content drops it to avoid a
        // double status-bar gap; when the banner is hidden the route keeps its
        // normal padding.
        builder: (context, child) => Column(
          children: [
            const ProductionWarningBanner(),
            Expanded(
              child: octopusIsProdServer
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: child!,
                    )
                  : child!,
            ),
          ],
        ),
        // While bootstrap restores a persisted config, show a splash so a saved
        // session doesn't flash the Config screen before auto-starting back in.
        home: _app.restoringConfig
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : (_app.config == null
                  ? ConfigScreen(initialConfig: _app.restoredConfig)
                  : MainScreen(app: _app)),
      ),
    );
  }
}

/// Main bottom-navigation shell (Home / Scenarios / Community / Settings).
class MainScreen extends StatefulWidget {
  final AppState app;

  const MainScreen({super.key, required this.app});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int _communityIndex = 2;
  static const int _debugIndex = 4;
  // Land directly on Community when there's a pending deep link from a push.
  // A cold-start tap on a notification calls `requestCommunityTab` BEFORE this
  // screen mounts, so the `navEpoch` diff in `_onAppChanged` can't trip — the
  // bump already happened by the time `_seenNavEpoch` is initialised below.
  // Read the pending notification synchronously here to honour the deep link.
  late int _index = widget.app.pendingCommunityNotification != null
      ? _communityIndex
      : 0;
  late int _seenNavEpoch = widget.app.navEpoch;

  static const _titles = [
    'Home',
    'Scenarios',
    'Community',
    'Settings',
    'Debug',
  ];

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  void _onAppChanged() {
    // A push tap bumps navEpoch — jump to the Community tab when it changes.
    if (widget.app.navEpoch != _seenNavEpoch) {
      _seenNavEpoch = widget.app.navEpoch;
      if (mounted) {
        // Pop any pushed routes (Modal / Fullscreen / Sheet scenarios, login
        // page, profile editor, …) so the bottom-nav shell — and the Community
        // tab now hosting the deep link — actually becomes visible. Without
        // this, `_index = _communityIndex` still updates the shell but the
        // user sees nothing because the pushed route covers it. The pushed
        // mode/scenario is dismissed by design: a push always wins routing.
        Navigator.maybeOf(
          context,
          rootNavigator: true,
        )?.popUntil((route) => route.isFirst);
        setState(() => _index = _communityIndex);
      }
    }
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onTap(int index) {
    setState(() => _index = index);
    // Leaving Community discards a consumed deep link so it isn't reopened.
    if (index != _communityIndex) {
      widget.app.clearPendingNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = const [
      HomeTab(),
      ScenariosTab(),
      CommunityTab(),
      SettingsTab(),
      DebugTab(),
    ][_index];

    // The Community tab embeds the SDK with its own native top bar
    // (`OctopusHomeScreen` on both platforms) — drop the Flutter shell
    // `AppBar` to avoid stacking. The other tabs keep their host `AppBar`.
    //
    // We could use `OctopusHomeContent` on Android (no-navbar variant) and
    // re-show the Flutter `AppBar` so the title matches the other tabs, but
    // iOS doesn't yet have an `OctopusHomeContent` equivalent
    // (tracked internally). Keeping both platforms on
    // `OctopusHomeScreen` aligns them; the non-embedded integration modes
    // (Modal / Fullscreen / Sheet) are demonstrated by their respective
    // scenarios in the Scenarios tab — each gives the SDK a chrome-clean
    // surface without embedding.
    //
    // The Debug tab carries its own `Scaffold` + `AppBar` (Copy / Clear
    // actions) — drop the shell `AppBar` here too to avoid double headers.
    final isCommunityTab = _index == _communityIndex;
    final isDebugTab = _index == _debugIndex;
    final hasOwnAppBar = isCommunityTab || isDebugTab;

    return Scaffold(
      appBar: hasOwnAppBar ? null : AppBar(title: Text(_titles[_index])),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'home-tab',
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'scenarios-tab',
              child: const Icon(Icons.science),
            ),
            label: 'Scenarios',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'community-tab',
              child: const Icon(Icons.people),
            ),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'settings-tab',
              child: const Icon(Icons.settings),
            ),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'debug-tab',
              child: const Icon(Icons.bug_report),
            ),
            label: 'Debug',
          ),
        ],
      ),
    );
  }
}
