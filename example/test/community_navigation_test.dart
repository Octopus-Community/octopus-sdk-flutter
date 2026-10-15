import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/auth/login_page.dart';
import 'package:octopus_sdk_flutter_example/auth/profile_edit_page.dart';
import 'package:octopus_sdk_flutter_example/community/client_profile_page.dart';
import 'package:octopus_sdk_flutter_example/community/community_navigation.dart';
import 'package:octopus_sdk_flutter_example/community/present_community.dart';
import 'package:octopus_sdk_flutter_example/config/host_integration.dart';
import 'package:octopus_sdk_flutter_example/sample_tab.dart';
import 'package:octopus_sdk_flutter_example/settings/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sample_shell_test.dart' show pumpShell, selectTab;

class _App extends AppState {
  bool ready = true;
  OctopusProfile? identity;
  bool connected = true;

  @override
  bool get initialized => ready;
  @override
  bool get userConnected => connected;
  @override
  OctopusProfile? get profile => identity;

  void setReady() {
    ready = true;
    notifyListeners();
  }

  void setIdentity(String id) {
    identity = OctopusProfile(clientUserId: id);
    notifyListeners();
  }

  void setConnected(bool value) {
    connected = value;
    notifyListeners();
  }
}

const _push = OctopusNotification(
  title: 'Demo',
  body: '',
  linkPath: 'post/demo-post',
  rawPayload: {'link_path': 'post/demo-post'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final creations = <Map<Object?, Object?>>[];
  final visibility = <int, bool>{};
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    creations.clear();
    visibility.clear();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockStreamHandler(
      const EventChannel('octopus_sdk_flutter/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'resize') {
        final args = call.arguments as Map;
        return {'width': args['width'], 'height': args['height']};
      }
      if (call.method == 'create') {
        final viewId = (call.arguments as Map)['id'];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              MethodChannel('octopus_sdk_flutter/native_view/$viewId'),
              (call) async {
                visibility[viewId as int] = call.arguments as bool;
                return null;
              },
            );
        final args = call.arguments as Map;
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(args['params'] as Uint8List),
        );
        creations.add(Map<Object?, Object?>.from(params as Map));
        return creations.length;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      null,
    );
  });

  void navigationTest(
    String name,
    Future<void> Function(WidgetTester tester) body, {
    TargetPlatform platform = TargetPlatform.android,
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  List<Map<Object?, Object?>> targets(String path) => creations.where((params) {
    if (params['linkPath'] == path) return true;
    final initial = params['initialScreen'];
    return initial is Map &&
        switch (path.split('/').first) {
          'group' =>
            initial['type'] == 'group' &&
                initial['groupId'] == path.split('/').last,
          'member' =>
            initial['type'] == 'activity' &&
                (initial['member'] as Map?)?['id'] == path.split('/').last,
          _ => false,
        };
  }).toList();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in ['modal', 'sheet']) {
      navigationTest(
        '$platform $mode shortcut mounts once and closes back to Scenarios',
        (tester) async {
          await pumpShell(tester, state: _App(), platform: platform);
          final shortcut = find.bySemanticsIdentifier(
            'open-community-$mode-button',
          );
          await tester.ensureVisible(shortcut);
          await tester.tap(shortcut);
          await tester.pumpAndSettle();
          expect(find.byType(OctopusHomeScreen), findsOneWidget);
          expect(find.byType(NavigationBar).hitTestable(), findsNothing);
          expect(creations, hasLength(1));
          final surface = tester.element(find.byType(OctopusHomeScreen));
          if (mode == 'sheet') {
            final rect = tester.getRect(find.byType(BottomSheet));
            await tester.dragFrom(
              Offset(rect.center.dx, rect.top + 12),
              const Offset(0, 900),
            );
          } else {
            tester
                .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
                .onBack!();
          }
          await tester.pumpAndSettle();
          expect(surface.mounted, isFalse);
          expect(find.byType(OctopusHomeScreen), findsNothing);
          expect(find.text('Open the community'), findsOneWidget);
        },
        platform: platform,
      );
    }
    navigationTest(
      '$platform URL opening policy controls native interception',
      (tester) async {
        final app = _App();
        await pumpShell(tester, state: app);
        await selectTab(tester, SampleTab.community);
        expect(
          tester
              .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
              .onNavigateToUrl,
          isNull,
        );
        expect(creations.last['interceptUrls'], isFalse);
        app.setHostUrlHandling(HostUrlHandling.inApp);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
              .onNavigateToUrl,
          isNotNull,
        );
        expect(creations.last['interceptUrls'], isTrue);
        app.setHostUrlHandling(HostUrlHandling.sdk);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
              .onNavigateToUrl,
          isNull,
        );
        expect(creations.last['interceptUrls'], isFalse);
      },
      platform: platform,
    );
  }

  navigationTest('mode picker persists Full screen across a new app instance', (
    tester,
  ) async {
    final app = _App();
    await pumpShell(tester, state: app);
    await selectTab(tester, SampleTab.community);
    expect(app.communityNavigation, CommunityNavigation.inTab);
    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(app.communityNavigation, CommunityNavigation.fullScreen);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    final surface = tester.widget<OctopusHomeScreen>(
      find.byType(OctopusHomeScreen),
    );
    expect(surface.navBarLeadingAction, OctopusNavBarLeadingAction.back);
    surface.onBack!();
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    final restarted = _App();
    await restarted.restoreCommunityNavigation();
    expect(restarted.communityNavigation, CommunityNavigation.fullScreen);
    restarted.dispose();
    await tester.tap(find.text('In tab'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    final again = _App();
    await again.restoreCommunityNavigation();
    expect(again.communityNavigation, CommunityNavigation.inTab);
    again.dispose();
  });

  navigationTest('missing or obsolete preference defaults to In tab', (
    tester,
  ) async {
    for (final saved in [null, 'obsolete']) {
      SharedPreferences.setMockInitialValues({
        if (saved != null) communityNavigationPreferenceKey: saved,
      });
      final app = _App();
      await app.restoreCommunityNavigation();
      expect(app.communityNavigation, CommunityNavigation.inTab);
      app.dispose();
    }
  });

  navigationTest(
    'tab switches preserve view and only a retap resets the feed',
    (tester) async {
      await pumpShell(tester, state: _App());
      expect(creations, isEmpty);
      await selectTab(tester, SampleTab.community);
      final view = tester.element(find.byType(OctopusHomeScreen));
      final count = creations.length;
      expect(count, 1);
      await selectTab(tester, SampleTab.settings);
      await selectTab(tester, SampleTab.community);
      expect(tester.element(find.byType(OctopusHomeScreen)), same(view));
      expect(creations.length, count);
      await selectTab(tester, SampleTab.community);
      expect(tester.element(find.byType(OctopusHomeScreen)), isNot(same(view)));
      expect(creations.length, count + 1);
      expect(creations.last['linkPath'], isNull);
    },
  );

  navigationTest(
    'only SDK retarget invalidates; identity and metadata do not',
    (tester) async {
      final app = _App();
      app.setIdentity('demo-user-a');
      await pumpShell(tester, state: app);
      await selectTab(tester, SampleTab.community);
      await selectTab(tester, SampleTab.settings);
      final count = creations.length;
      // Mock channel only: no network and no community content is touched.
      await app.switchToCommunity('demo-test-key');
      await tester.pumpAndSettle();
      expect(creations.length, count + 1);
      await selectTab(tester, SampleTab.community);
      expect(creations.length, count + 1);
      app.setIdentity('demo-user-b');
      await tester.pumpAndSettle();
      expect(creations.length, count + 1);
      app.setIdentity('demo-user-b');
      app.setConnected(false);
      app.noteConnectFailure('Demo failure');
      await tester.pumpAndSettle();
      expect(creations.length, count + 1);
      await app.setCommunityNavigation(CommunityNavigation.inTab);
      await tester.pumpAndSettle();
      expect(creations.length, count + 1);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    navigationTest(
      '$platform In tab picker sits below the SDK header and surface',
      (tester) async {
        await pumpShell(tester, state: _App(), platform: platform);
        await selectTab(tester, SampleTab.community);
        final surface = tester.getRect(find.byType(OctopusHomeScreen));
        final picker = tester.getRect(
          find.byType(SegmentedButton<CommunityNavigation>),
        );
        expect(picker.top, greaterThanOrEqualTo(surface.bottom));
        expect(find.byType(AppBar), findsNothing);
      },
      platform: platform,
    );

    for (final mode in CommunityNavigation.values) {
      navigationTest(
        '$platform $mode cold push survives delayed identity and connection',
        (tester) async {
          final app = _App()..connected = false;
          await app.setCommunityNavigation(mode);
          app.requestCommunityTab(_push);
          await pumpShell(tester, state: app, platform: platform);
          final view = tester.element(find.byType(OctopusHomeScreen));
          final count = creations.length;
          final rootEpoch = app.communityRootEpoch;
          expect(targets(_push.linkPath), hasLength(1));
          app.setIdentity('host-user');
          await tester.pumpAndSettle();
          expect(tester.element(find.byType(OctopusHomeScreen)), same(view));
          app.setConnected(true);
          await tester.pumpAndSettle();
          expect(tester.element(find.byType(OctopusHomeScreen)), same(view));
          expect(creations.length, count);
          expect(app.communityRootEpoch, rootEpoch);
          expect(creations.last['linkPath'], _push.linkPath);
          expect(targets(_push.linkPath), hasLength(1));
        },
        platform: platform,
      );
    }
  }

  for (final mode in CommunityNavigation.values) {
    for (final timing in ['cold', 'warm', 'pending']) {
      navigationTest('$mode $timing push opens its target once', (
        tester,
      ) async {
        final app = _App();
        await app.setCommunityNavigation(mode);
        if (timing == 'cold') app.requestCommunityTab(_push);
        if (timing == 'pending') app.ready = false;
        await pumpShell(tester, state: app);
        if (timing == 'warm') {
          await selectTab(tester, SampleTab.community);
          await tester.pumpAndSettle();
          // Return to the shell when using Full screen.
          if (mode == CommunityNavigation.fullScreen) {
            tester
                .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
                .onBack!();
            await tester.pumpAndSettle();
          }
        }
        if (timing != 'cold') {
          app.requestCommunityTab(_push);
          await tester.pump();
          if (timing == 'pending') {
            expect(targets(_push.linkPath), isEmpty);
            expect(app.pendingCommunityNotification, same(_push));
            app.setReady();
          }
          await tester.pumpAndSettle();
        }
        expect(targets(_push.linkPath), hasLength(1));
        expect(app.pendingCommunityNotification, isNull);
        expect(find.byType(AppBar), findsNothing);
        app.noteConnectFailure('Unrelated rebuild');
        await tester.pumpAndSettle();
        expect(targets(_push.linkPath), hasLength(1));
        if (mode == CommunityNavigation.fullScreen) {
          tester
              .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
              .onBack!();
          await tester.pumpAndSettle();
        }
        await selectTab(tester, SampleTab.settings);
        await selectTab(tester, SampleTab.community);
        expect(targets(_push.linkPath), hasLength(1));
      });
    }

    for (final presentation in ['modal', 'sheet']) {
      navigationTest('$mode push dismisses an already open $presentation', (
        tester,
      ) async {
        final app = _App();
        await app.setCommunityNavigation(mode);
        await pumpShell(tester, state: app);
        final context = tester.element(find.byType(NavigationBar));
        if (presentation == 'modal') {
          openCommunityModal(context);
        } else {
          openCommunitySheet(context);
        }
        await tester.pumpAndSettle();
        final previous = tester.element(find.byType(OctopusHomeScreen));
        expect(creations.last['linkPath'], isNull);
        app.requestCommunityTab(_push);
        await tester.pumpAndSettle();
        expect(previous.mounted, isFalse);
        expect(targets(_push.linkPath), hasLength(1));
        expect(find.byType(OctopusHomeScreen), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
      });
    }

    for (final callback in ['login', 'profileEdit', 'profile']) {
      navigationTest('$mode $callback uses root, Back preserves SDK stack', (
        tester,
      ) async {
        final app = _App();
        app.setUnifiedProfileWired(true);
        await app.setCommunityNavigation(mode);
        app.requestCommunityTab(_push);
        await pumpShell(tester, state: app);
        final view = tester.element(find.byType(OctopusHomeScreen));
        final count = creations.length;
        final rootEpoch = app.communityRootEpoch;
        final sdk = tester.widget<OctopusHomeScreen>(
          find.byType(OctopusHomeScreen),
        );
        switch (callback) {
          case 'login':
            sdk.onNavigateToLogin!();
          case 'profileEdit':
            sdk.onModifyUser!('nickname');
          case 'profile':
            sdk.onNavigateToProfile!('host-user');
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(switch (callback) {
            'login' => LoginPage,
            'profileEdit' => ProfileEditPage,
            _ => ClientProfilePage,
          }),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(visibility.values, everyElement(isFalse));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(OctopusHomeScreen), findsOneWidget);
        expect(tester.element(find.byType(OctopusHomeScreen)), same(view));
        expect(visibility.values, contains(isTrue));
        expect(creations.length, count);
        expect(app.communityRootEpoch, rootEpoch);
        expect(creations.last['linkPath'], _push.linkPath);
        expect(targets(_push.linkPath), hasLength(1));
      });
    }
  }

  for (final path in [
    'post/demo-post',
    'group/demo-group',
    'member/demo-member',
    'profile/demo-profile',
  ]) {
    navigationTest(
      'push opens $path once through its supported native entry point',
      (tester) async {
        final app = _App();
        await pumpShell(tester, state: app);
        final notification = OctopusNotification(
          title: '',
          body: '',
          linkPath: path,
          rawPayload: {'link_path': path, 'is_octopus_notification': 'true'},
        );
        app.requestCommunityTab(notification);
        await tester.pumpAndSettle();
        expect(targets(path), hasLength(1));
        if (path.startsWith('group/') || path.startsWith('member/')) {
          expect(creations.last['linkPath'], isNull);
          expect(creations.last['initialScreen'], isNotNull);
          tester
              .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
              .onBack!();
          await tester.pumpAndSettle();
          expect(creations.last['initialScreen'], isNull);
        } else {
          expect(
            creations.last['notificationUserInfo'],
            notification.rawPayload,
          );
        }
        // Even another tap of the same target is a new request, consumed once.
        app.requestCommunityTab(notification);
        await tester.pumpAndSettle();
        expect(targets(path), hasLength(2));
        await selectTab(tester, SampleTab.community);
        expect(creations.last['linkPath'], isNull);
        await selectTab(tester, SampleTab.settings);
        await selectTab(tester, SampleTab.community);
        expect(targets(path), hasLength(2));
      },
    );
  }

  navigationTest('Full screen shortcut is independent of the preference', (
    tester,
  ) async {
    final app = _App();
    await pumpShell(tester, state: app);
    await tester.tap(
      find.bySemanticsIdentifier('open-community-fullscreen-button'),
    );
    await tester.pumpAndSettle();
    expect(app.communityNavigation, CommunityNavigation.inTab);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    tester.widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen)).onBack!();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Open the community'), findsOneWidget);
  });

  navigationTest('remounting for a theme never replays a consumed push', (
    tester,
  ) async {
    final app = _App()..requestCommunityTab(_push);
    await pumpShell(tester, state: app);
    final count = creations.length;
    app.setActiveOctopusTheme((_) => const OctopusTheme(), 'Demo theme');
    await tester.pumpAndSettle();
    expect(creations.length, count + 1);
    expect(creations.last['linkPath'], isNull);
    expect(targets(_push.linkPath), hasLength(1));
  });

  navigationTest('host callback remount never replays a consumed push target', (
    tester,
  ) async {
    final app = _App()..requestCommunityTab(_push);
    await pumpShell(tester, state: app);
    final count = creations.length;
    app.setHostProfileEditWired(false);
    await tester.pumpAndSettle();
    expect(creations.length, count + 1);
    expect(creations.last['linkPath'], isNull);
    expect(targets(_push.linkPath), hasLength(1));
    expect(
      tester
          .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
          .onModifyUser,
      isNull,
    );
  });

  navigationTest('Community Connect keeps the newly opened Account page', (
    tester,
  ) async {
    final app = _App()..connected = false;
    await pumpShell(tester, state: app);
    await selectTab(tester, SampleTab.community);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      SampleTab.settings.index,
    );
  });

  navigationTest('a hidden SDK surface cannot push a host page', (
    tester,
  ) async {
    await pumpShell(tester, state: _App());
    await selectTab(tester, SampleTab.community);
    final sdk = tester.widget<OctopusHomeScreen>(
      find.byType(OctopusHomeScreen),
    );
    await selectTab(tester, SampleTab.settings);
    sdk.onNavigateToLogin!();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  navigationTest('latest pending push wins while a sheet is closing', (
    tester,
  ) async {
    final app = _App();
    await pumpShell(tester, state: app);
    openCommunitySheet(tester.element(find.byType(NavigationBar)));
    await tester.pumpAndSettle();
    app.requestCommunityTab(_push);
    await tester.pump();
    const latest = OctopusNotification(
      title: '',
      body: '',
      linkPath: 'post/latest-demo-post',
    );
    app.requestCommunityTab(latest);
    await tester.pumpAndSettle();
    expect(targets(_push.linkPath), isEmpty);
    expect(targets(latest.linkPath), hasLength(1));
    expect(app.pendingCommunityNotification, isNull);
  });

  for (final mode in CommunityNavigation.values) {
    navigationTest(
      'iOS $mode has one native header and preserves SDK stack after host page',
      (tester) async {
        final app = _App();
        await app.setCommunityNavigation(mode);
        app.requestCommunityTab(_push);
        await pumpShell(tester, state: app, platform: TargetPlatform.iOS);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(UiKitView), findsOneWidget);
        final sdk = tester.widget<OctopusHomeScreen>(
          find.byType(OctopusHomeScreen),
        );
        expect(sdk.titleCentered, isTrue);
        expect(sdk.navigationMode, OctopusNavigationMode.navigationStack);
        sdk.onModifyUser!('nickname');
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        expect(targets(_push.linkPath), hasLength(1));
        expect(creations.last['linkPath'], _push.linkPath);
      },
      platform: TargetPlatform.iOS,
    );
  }
}
