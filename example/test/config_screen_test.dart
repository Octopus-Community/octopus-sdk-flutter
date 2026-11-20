import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/api_key_registry.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/config/user_id_registry.dart';
import 'package:octopus_sdk_flutter_example/octopus_demo_config.dart';
import 'package:octopus_sdk_flutter_example/settings/settings_choices.dart';

class _StartingApp extends AppState {
  _StartingApp({super.buildConfig});
  final completion = Completer<void>();
  DemoConfig? applied;
  var startCalls = 0;

  @override
  Future<void> start(DemoConfig config) {
    applied = config;
    startCalls++;
    return completion.future;
  }
}

void main() {
  const namedKeys = [
    InjectedApiKey(id: 'fixture-a', label: 'Fixture A', key: 'fixture-key-a'),
    InjectedApiKey(id: 'fixture-b', label: 'Fixture B', key: 'fixture-key-b'),
  ];
  for (final (server, customHost, buildHost, expectedHost) in [
    (ServerEnv.demo, '', 'build.example.test', 'build.example.test'),
    (ServerEnv.demo, '', '', productionHost),
    (ServerEnv.prod, '', 'build.example.test', 'build.example.test'),
    (
      ServerEnv.custom,
      'saved.example.test',
      'build.example.test',
      'saved.example.test',
    ),
  ]) {
    testWidgets('$server to Custom prefills $expectedHost', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = _StartingApp(
        buildConfig: buildInitialDemoConfig(host: buildHost, userId: 'fixture'),
      );
      app.completion.complete();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            home: ConfigScreen(
              anchor: ConfigSection.server,
              initialConfig: DemoConfig(
                apiKeySource: ApiKeySource.custom,
                customApiKey: 'fixture-only',
                userId: 'fixture',
                theme: AppThemeChoice.system,
                serverEnv: server,
                customHost: customHost,
                buildHost: 'stale-build.example.test',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      final host = find.widgetWithText(TextField, 'Host');
      expect(tester.widget<TextField>(host).controller!.text, expectedHost);
      final apply = find.widgetWithText(FilledButton, 'Apply');
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(app.applied!.resolvedHost, expectedHost);
      expect(app.applied!.serverEnv, ServerEnv.custom);
    });
  }
  for (final source in ['Demo', 'Named key', 'Custom']) {
    testWidgets('server-only Apply preserves the $source key choice', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final initialConfig = DemoConfig(
        apiKeySource: source == 'Custom'
            ? ApiKeySource.custom
            : ApiKeySource.demo,
        customApiKey: source == 'Custom' ? 'fixture-custom-key' : '',
        selectedInjectedKey: source == 'Named key' ? namedKeys.last : null,
        userId: 'fixture',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.custom,
        customHost: 'custom.example.test',
        customPort: 8443,
      );
      final app = _StartingApp();
      app.completion.complete();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            home: ConfigScreen(
              anchor: ConfigSection.server,
              initialConfig: initialConfig,
              injectedKeys: namedKeys,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Edit only the server section; the community section stays collapsed.
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      final applied = app.applied!;
      expect(applied.serverEnv, ServerEnv.demo);
      expect(applied.apiKeySource, initialConfig.apiKeySource);
      expect(
        applied.selectedInjectedKey,
        same(initialConfig.selectedInjectedKey),
      );
      expect(applied.effectiveApiKey, initialConfig.effectiveApiKey);
      expect(applied.apiKeyLabel, initialConfig.apiKeyLabel);
      expect(applied.communityLabel, initialConfig.communityLabel);
    });
  }

  testWidgets('community picker explicitly selects a named key or Demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = _StartingApp();
    app.completion.complete();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(
          home: ConfigScreen(
            anchor: ConfigSection.community,
            injectedKeys: namedKeys,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byType(SettingsChoices<String>);
    expect(tester.widget<SettingsChoices<String>>(picker).selected, isEmpty);
    expect(find.textContaining('No demo key injected'), findsOneWidget);
    await tester.tap(find.text('Fixture B'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No demo key injected'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(app.applied!.selectedInjectedKey, same(namedKeys.last));
    expect(app.applied!.effectiveApiKey, namedKeys.last.key);
    expect(app.applied!.apiKeyLabel, 'Named key (--dart-define)');

    await tester.tap(find.text('Demo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No demo key injected'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsChoices<String>>(picker).selected, isEmpty);
    expect(app.applied!.apiKeySource, ApiKeySource.demo);
    expect(app.applied!.selectedInjectedKey, isNull);
    expect(
      app.applied!.effectiveApiKey,
      app.configurationChoices.effectiveApiKey,
    );
    expect(app.applied!.apiKeyLabel, app.configurationChoices.apiKeyLabel);
    expect(app.applied!.communityLabel, 'Demo community');
  });

  for (final initialServer in [ServerEnv.custom, ServerEnv.demo]) {
    testWidgets('Apply Demo repairs a stale $initialServer endpoint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = _StartingApp(
        buildConfig: buildInitialDemoConfig(
          host: 'current-build.example.test',
          userId: 'fixture',
        ),
      );
      app.completion.complete();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            home: ConfigScreen(
              anchor: ConfigSection.server,
              initialConfig: DemoConfig(
                apiKeySource: ApiKeySource.custom,
                customApiKey: 'fixture-only',
                userId: 'fixture',
                theme: AppThemeChoice.system,
                serverEnv: initialServer,
                customHost: 'stale.example.test',
                customPort: 8443,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(app.applied!.serverEnv, ServerEnv.demo);
      expect(app.applied!.resolvedHost, 'current-build.example.test');
      expect(app.applied!.apiServer!.port, 443);
      expect(app.applied!.toJson()['customHost'], isEmpty);
    });
  }

  testWidgets(
    'a removed Config route cannot handle Back after Start completes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final app = _StartingApp();
      addTearDown(app.dispose);
      final navigator = GlobalKey<NavigatorState>();
      var rootBacks = 0;
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            navigatorKey: navigator,
            home: PopScope<void>(
              canPop: false,
              onPopInvokedWithResult: (_, __) => rootBacks++,
              child: const Scaffold(body: Text('Host root')),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const ConfigScreen(
            anchor: ConfigSection.community,
            initialConfig: DemoConfig(
              apiKeySource: ApiKeySource.custom,
              userId: 'test-user',
              theme: AppThemeChoice.system,
              serverEnv: ServerEnv.demo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(FilledButton, 'Apply');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.enterText(
        find.ancestor(
          of: find.text('Custom API key'),
          matching: find.byType(TextField),
        ),
        'unit-test-placeholder',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.tap(apply);
      await tester.pump();
      expect(app.startCalls, 1);
      // Config remains mounted during its exit transition, while the host root
      // has already become current. Completion must not reach the shell's Back.
      navigator.currentState!.pop();
      expect(find.byType(ConfigScreen), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      app.completion.complete();
      await tester.pumpAndSettle();
      expect(app.startCalls, 1);
      expect(rootBacks, 0);
      expect(find.text('Host root'), findsOneWidget);
      expect(find.byType(ConfigScreen), findsNothing);
    },
  );
  testWidgets(
    'a covered Config route stays in the stack after Start completes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final app = _StartingApp();
      addTearDown(app.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Host root')),
          ),
        ),
      );
      final configRoute = MaterialPageRoute<void>(
        builder: (_) => const ConfigScreen(
          anchor: ConfigSection.community,
          initialConfig: DemoConfig(
            apiKeySource: ApiKeySource.custom,
            customApiKey: 'unit-test-placeholder',
            userId: 'test-user',
            theme: AppThemeChoice.system,
            serverEnv: ServerEnv.demo,
          ),
        ),
      );
      unawaited(navigator.currentState!.push(configRoute));
      await tester.pumpAndSettle();
      final configState = tester.state(find.byType(ConfigScreen));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();
      expect(app.startCalls, 1);
      expect(app.completion.isCompleted, isFalse);

      final coveringRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      );
      unawaited(navigator.currentState!.push(coveringRoute));
      // Settle the push before completing Start, while Config remains mounted.
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isTrue);
      expect(configRoute.isCurrent, isFalse);
      expect(configRoute.isActive, isTrue);
      expect(configState.mounted, isTrue);
      app.completion.complete();
      await tester.pumpAndSettle();

      expect(app.startCalls, 1);
      expect(find.text('Covering route'), findsOneWidget);
      expect(coveringRoute.isCurrent, isTrue);
      expect(configRoute.isActive, isTrue);
      expect(
        tester.state(find.byType(ConfigScreen, skipOffstage: false)),
        same(configState),
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(configRoute.isCurrent, isTrue);
      expect(find.byType(ConfigScreen), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
    },
  );
  testWidgets(
    'stopped Configuration uses Apply without an SSO restart notice',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));
      expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
      expect(find.textContaining('The restart drops'), findsNothing);
    },
  );

  testWidgets('SSO labels render without Markdown backticks', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ConfigScreen(anchor: ConfigSection.auth)),
    );
    await tester.pumpAndSettle();

    expect(find.text('User id (SSO sub)'), findsOneWidget);
    expect(find.textContaining('`'), findsNothing);
  });

  testWidgets(
    'tapping a User ID quick-pick chip fills the field and parks the caret '
    'at the end',
    (tester) async {
      // Render the Config screen on its own — AppScope is only consulted by
      // the Apply button (which this test never taps), so the
      // chip-fills-field contract can be exercised without the host
      // ChangeNotifier.
      // The form scrolls: give it a tall surface so the Authentication
      // (SSO) section sits on screen, where taps and enterText reach it.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: ConfigScreen(anchor: ConfigSection.auth)),
      );

      // Pick a chip that is NOT the seed (which already pre-fills the
      // field) so the assertion proves the chip actually overwrote the
      // field, not that it happened to match the initial value.
      expect(
        pickerUserIds.length,
        greaterThanOrEqualTo(2),
        reason: 'Need at least two picker entries to test override',
      );
      final initial = pickerUserIds.first;
      final target = pickerUserIds.firstWhere((id) => id != initial);

      // Sanity: the field starts on the seed.
      final inputFinder = find.bySemanticsIdentifier('config-userId-input');
      expect(inputFinder, findsOneWidget);
      TextEditingController readController() => tester
          .widget<TextField>(
            find.descendant(of: inputFinder, matching: find.byType(TextField)),
          )
          .controller!;
      expect(readController().text, initial);

      // Find and tap the target chip. `bySemanticsIdentifier` walks the
      // resolved SemanticsNode tree, and ActionChip's own button semantics
      // can absorb a `container: false` Semantics wrapper around it — so
      // locate the ActionChip by its label text instead, which always
      // renders into a discoverable Text widget.
      final chipFinder = find.widgetWithText(ActionChip, target);
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      final controller = readController();
      expect(controller.text, target);
      expect(controller.selection.baseOffset, target.length);
      expect(controller.selection.extentOffset, target.length);
    },
  );

  testWidgets(
    'a restored config seeds every field it still carries — the key is not '
    'one of them',
    (tester) async {
      // What `AppState.bootstrap` hands over when it refuses to auto-start a
      // config (custom key: never persisted, so it resolves to no key). The
      // user should get their other choices back and re-enter only the key.
      const restored = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'restored-user',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );

      // The form scrolls: in the default 800x600 test viewport the lower
      // fields sit below the fold. Give it a tall surface so every section —
      // including Authentication (SSO) — is on screen.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfigScreen(
            initialConfig: restored,
            anchor: ConfigSection.community,
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(ExpansionTile, 'Connect your users (SSO)'),
      );
      await tester.pumpAndSettle();
      final inputFinder = find.bySemanticsIdentifier('config-userId-input');
      final userIdField = tester.widget<TextField>(
        find.descendant(of: inputFinder, matching: find.byType(TextField)),
      );
      expect(userIdField.controller!.text, 'restored-user');
      expect(
        userIdField.controller!.text,
        isNot(pickerUserIds.first),
        reason: 'must be the restored id, not the default seed',
      );

      // The pasted key is gone: every other text field on the screen (the
      // custom-key input) comes up empty. Assert the count first — without
      // it the loop below would pass vacuously if the custom-key field ever
      // stopped being rendered.
      expect(find.byType(TextField), findsNWidgets(2));
      final otherFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((f) => f.controller != userIdField.controller);
      for (final field in otherFields) {
        expect(field.controller!.text, isEmpty);
      }
    },
  );

  testWidgets(
    'Apply stays disabled until a custom key is pasted, and enables on typing',
    (tester) async {
      // The state a restored custom-key config lands in. Starting from here
      // would initialise the SDK with an empty key against production, so the
      // button must wait for the paste.
      const restored = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'restored-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.prod,
      );

      // The commit button is anchored outside the scroll view, but the form
      // above it is tall; give the test a roomy surface so nothing overflows
      // while the custom-key field is being filled.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfigScreen(
            initialConfig: restored,
            anchor: ConfigSection.community,
          ),
        ),
      );

      // Located by label, not by `config-start-button`: the button sits under
      // a MergeSemantics, which folds the identifier into the button's own
      // node, so a descendant-of-identifier finder comes back empty.
      FilledButton readStartButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );

      expect(
        readStartButton().onPressed,
        isNull,
        reason: 'no key pasted yet — Apply must be inert',
      );

      final customField = find.ancestor(
        of: find.text('Custom API key'),
        matching: find.byType(TextField),
      );
      expect(customField, findsOneWidget);
      await tester.enterText(customField, 'example-pasted-key');
      await tester.pump();

      expect(readStartButton().onPressed, isNotNull);
    },
  );

  testWidgets('the server environment defaults to Demo, never production', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ConfigScreen(anchor: ConfigSection.server)),
    );

    final selector = find.byType(SettingsChoices<ServerEnv>);
    expect(selector, findsOneWidget);
    expect(
      tester.widget<SettingsChoices<ServerEnv>>(selector).selected,
      ServerEnv.demo,
      reason: 'a fresh install must not land on the production server',
    );
    // And the picker is a real runtime control, not a build-time readout.
    expect(
      tester.widget<SettingsChoices<ServerEnv>>(selector).onChanged,
      isNotNull,
    );
  });
}
