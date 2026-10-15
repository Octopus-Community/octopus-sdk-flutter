import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/api_key_registry.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/settings/debug_info_screen.dart';

class _ConfiguredApp extends AppState {
  _ConfiguredApp(this.config);

  @override
  final DemoConfig? config;
}

void main() {
  const demoConfig = DemoConfig(
    apiKeySource: ApiKeySource.demo,
    userId: 'test-user',
    theme: AppThemeChoice.system,
    serverEnv: ServerEnv.demo,
  );
  const customConfig = DemoConfig(
    apiKeySource: ApiKeySource.custom,
    customApiKey: 'test-key-placeholder',
    userId: 'test-user',
    theme: AppThemeChoice.system,
    serverEnv: ServerEnv.prod,
  );
  const namedConfig = DemoConfig(
    apiKeySource: ApiKeySource.demo,
    selectedInjectedKey: InjectedApiKey(
      id: 'client-a',
      label: 'Client A',
      key: 'test-key-placeholder',
    ),
    userId: 'test-user',
    theme: AppThemeChoice.system,
    serverEnv: ServerEnv.prod,
  );

  for (final (name, config, community) in <(String, DemoConfig?, String)>[
    ('no configuration', null, '—'),
    ('demo community', demoConfig, 'Demo community'),
    ('custom community', customConfig, 'Custom community'),
    ('named community', namedConfig, 'Client A'),
  ]) {
    testWidgets('Debug info shows and copies Community for $name', (
      tester,
    ) async {
      final app = _ConfiguredApp(config);
      addTearDown(app.dispose);
      String? copiedText;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
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
      final communityRow = find.widgetWithText(SampleKeyValue, 'Community');
      await tester.ensureVisible(communityRow);
      expect(
        find.descendant(of: communityRow, matching: find.text(community)),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copiedText, isNotNull);
      expect(copiedText!.split('\n'), contains('Community: $community'));
      if (config != null) {
        expect(copiedText, contains('API key source: ${config.apiKeyLabel}'));
        expect(copiedText, isNot(contains('test-key-placeholder')));
      }
    });
  }
}
