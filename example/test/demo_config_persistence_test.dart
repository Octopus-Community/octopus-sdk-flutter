import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/octopus_demo_config.dart';

/// Locks the persistence contract behind config save/restore (see
/// `AppState.bootstrap` / `start`). A `DemoConfig` is serialised to prefs on
/// `start` and rebuilt on launch; a round-trip must preserve the choices, and
/// a stale / corrupt blob must degrade to `null` (fall back to the Config
/// screen) rather than crash startup.
void main() {
  group('DemoConfig.toJson / fromJson', () {
    test('round-trips a custom-key config (with a picked user id)', () {
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'example-custom-key',
        userId: 'qa-tester-1',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );

      final restored = DemoConfig.fromJson(config.toJson());

      expect(restored, isNotNull);
      expect(restored!.apiKeySource, ApiKeySource.custom);
      expect(restored.customApiKey, 'example-custom-key');
      // No injected key picked on a build with an empty registry.
      expect(restored.selectedInjectedKey, isNull);
      expect(restored.userId, 'qa-tester-1');
      expect(restored.theme, AppThemeChoice.dark);
      expect(restored.serverEnv, ServerEnv.prod);
    });

    test('round-trips a demo-key config (injected id unresolved on a '
        'keyless test build → null, not a crash)', () {
      const config = DemoConfig(
        apiKeySource: ApiKeySource.demo,
        userId: 'flutter-sample-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.custom,
      );

      final json = config.toJson();
      expect(json['apiKeySource'], 'demo');
      expect(json['userId'], 'flutter-sample-user');
      expect(json['theme'], 'system');
      expect(json['serverEnv'], 'custom');

      final restored = DemoConfig.fromJson(json);
      expect(restored, isNotNull);
      expect(restored!.apiKeySource, ApiKeySource.demo);
      expect(restored.userId, 'flutter-sample-user');
      expect(restored.theme, AppThemeChoice.system);
      expect(restored.serverEnv, ServerEnv.custom);
    });

    test(
      'missing userId in a legacy blob → falls back to the build-time seed',
      () {
        // Blob written by an older sample build that didn't carry the userId
        // field; fromJson must accept it and back-fill rather than crash on
        // a null assert.
        final restored = DemoConfig.fromJson({
          'apiKeySource': 'custom',
          'customApiKey': 'legacy-key',
          'theme': 'light',
          'serverEnv': 'custom',
        });
        expect(restored, isNotNull);
        expect(restored!.userId, octopusUserId);
      },
    );

    test('whitespace-only userId in the blob → falls back to the seed', () {
      // The backfill also covers blobs where a previous build wrote an empty
      // or whitespace-only userId — the JWT signer must never see one.
      final restored = DemoConfig.fromJson({
        'apiKeySource': 'demo',
        'userId': '   ',
        'theme': 'system',
        'serverEnv': 'custom',
      });
      expect(restored, isNotNull);
      expect(restored!.userId, octopusUserId);
    });

    test('returns null on schema drift / corrupt blob', () {
      expect(DemoConfig.fromJson(<String, dynamic>{}), isNull);
      expect(
        DemoConfig.fromJson({
          'apiKeySource': 'not_a_source',
          'userId': 'flutter-sample-user',
          'theme': 'dark',
          'serverEnv': 'custom',
        }),
        isNull,
      );
      expect(
        DemoConfig.fromJson({
          'apiKeySource': 'demo',
          'userId': 'flutter-sample-user',
          'theme': 'lightish', // renamed/unknown enum value
          'serverEnv': 'custom',
        }),
        isNull,
      );
    });
  });
}
