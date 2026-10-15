import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/settings/debug_info_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/sdk_summary.dart';

class _SummaryApp extends AppState {
  _SummaryApp(this.config, this.connectionState);
  @override
  final DemoConfig config;
  @override
  final OctopusConnectionState connectionState;
  @override
  String get effectiveUserId => config.userId;
  @override
  int get notSeenCount => 3;
}

void main() {
  for (final (host, label) in [
    ('', 'Demo (SDK default)'),
    ('build.example.test', 'Demo'),
  ]) {
    testWidgets('Settings Server identifies Demo on $host', (tester) async {
      final app = _SummaryApp(
        DemoConfig(
          apiKeySource: ApiKeySource.demo,
          userId: 'fixture-user',
          theme: AppThemeChoice.system,
          serverEnv: ServerEnv.demo,
          buildHost: host,
        ),
        const OctopusNotConnected(),
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            home: Scaffold(body: CommunitySettingsSummary(app: app)),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget);
    });
  }

  for (final (connection, expected) in [
    (const OctopusConnected(), 'Connected · fixture-user'),
    (const OctopusConnected(isGuest: true), 'Guest'),
    (const OctopusNotConnected(), 'Not connected'),
  ]) {
    testWidgets('Debug info displays and copies $expected', (tester) async {
      final app = _SummaryApp(
        const DemoConfig(
          apiKeySource: ApiKeySource.demo,
          userId: 'fixture-user',
          theme: AppThemeChoice.system,
          serverEnv: ServerEnv.demo,
          buildHost: '',
        ),
        connection,
      );
      addTearDown(app.dispose);
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: DebugInfoScreen()),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Unread notifications'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, contains('Connection: $expected'));
      expect(copied, contains('Unread notifications: 3'));
      expect(copied, contains('onNavigateToProfileEdit (onModifyUser): Wired'));
      expect(copied, contains('Server environment: Demo (SDK default)'));
    });
  }
}
