import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/api_key_registry.dart';
import 'package:octopus_sdk_flutter_example/octopus_demo_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only access to the plugin's backend; declared under `dev_dependencies`
// in example/pubspec.yaml, not a production dependency (#377).
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Locks the persistence contract behind config save/restore (see
/// `AppState.bootstrap` / `start`). A `DemoConfig` is serialised to prefs on
/// `start` and rebuilt on launch; a round-trip must preserve the choices, and
/// a stale / corrupt blob must degrade to `null` (fall back to the Config
/// screen) rather than crash startup.
///
/// It also locks the safety half of that contract: no API key VALUE is ever
/// written to prefs, so a relaunch can never re-enter the SDK — production by
/// default, see [octopusApiHost] — with a key someone pasted once. `bootstrap`
/// keys its auto-start decision off [DemoConfig.effectiveApiKey] being
/// non-empty after trim, so dropping the key is what sends a custom-key config
/// back to the Config screen instead of silently starting it.
void main() {
  // SharedPreferences' in-memory mock store needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DemoConfig.toJson / fromJson', () {
    test('never persists the pasted custom key, keeps every other choice', () {
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'example-custom-key',
        userId: 'qa-tester-1',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );

      final json = config.toJson();
      expect(
        json.containsKey('customApiKey'),
        isFalse,
        reason: 'a pasted key must never reach on-device prefs',
      );
      expect(json.values, isNot(contains('example-custom-key')));

      final restored = DemoConfig.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.apiKeySource, ApiKeySource.custom);
      expect(restored.customApiKey, isEmpty);
      // …which is exactly what stops `bootstrap` from auto-starting it.
      expect(restored.effectiveApiKey, isEmpty);
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

    test('a named key is persisted by id and re-resolved by value, never '
        'stored verbatim', () {
      const slot = InjectedApiKey(id: 'slot-a', label: 'Slot A', key: 'k-a');
      const config = DemoConfig(
        apiKeySource: ApiKeySource.demo,
        selectedInjectedKey: slot,
        userId: 'flutter-sample-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.custom,
      );

      // The value the SDK gets comes from the build-time define…
      expect(config.effectiveApiKey, 'k-a');
      // …and only the id is written down.
      final json = config.toJson();
      expect(json['selectedInjectedKeyId'], 'slot-a');
      expect(json.values, isNot(contains('k-a')));
      // Home's "API key source" names the source kind; the slot label is
      // already its "Community" row (#430).
      expect(config.apiKeyLabel, 'Named key (--dart-define)');
      expect(config.apiKeyLabel, isNot(contains(slot.label)));
    });

    test('legacy blob carrying a plaintext custom key → key ignored', () {
      // Written by a build from before the key stopped being persisted. The
      // restored config must not carry it forward (AppState also rewrites the
      // blob without it on load, stripping it from storage).
      final restored = DemoConfig.fromJson({
        'apiKeySource': 'custom',
        'customApiKey': 'legacy-key',
        'userId': 'qa-tester-1',
        'theme': 'light',
        'serverEnv': 'custom',
      });
      expect(restored, isNotNull);
      expect(restored!.customApiKey, isEmpty);
      expect(restored.effectiveApiKey, isEmpty);
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

    test(
      'legacy blob carrying octopusTealTheme: false → octopusNavyTheme restores false',
      () {
        // Blob written by a pre-navy-rollout build, before the field was
        // renamed octopusNavyTheme. fromJson must still honour a persisted
        // "SDK default" choice (false) rather than silently resetting it to
        // the navy default (true) just because the new key is absent.
        final restored = DemoConfig.fromJson({
          'apiKeySource': 'custom',
          'userId': 'qa-tester-1',
          'theme': 'light',
          'serverEnv': 'custom',
          'octopusTealTheme': false,
        });
        expect(restored, isNotNull);
        expect(restored!.octopusNavyTheme, isFalse);
      },
    );

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

  /// What actually leaves (or doesn't leave) a pasted key on the device.
  ///
  /// The `fromJson` group above only proves the key is ignored *in memory* on
  /// restore — every one of those tests would still pass if the storage
  /// rewrite were deleted and the plaintext key stayed in prefs forever. These
  /// assert on the raw stored blob instead.
  group('loadPersistedDemoConfig', () {
    test('strips a legacy plaintext key from storage on first load', () async {
      SharedPreferences.setMockInitialValues({
        demoConfigPrefsKey: jsonEncode({
          'apiKeySource': 'custom',
          'customApiKey': 'legacy-key',
          'userId': 'qa-tester-1',
          'theme': 'light',
          'serverEnv': 'custom',
        }),
      });

      final restored = await loadPersistedDemoConfig();

      // Every other choice survives — only the key is dropped, so the user
      // re-enters nothing else on the Config screen.
      expect(restored, isNotNull);
      expect(restored!.userId, 'qa-tester-1');
      expect(restored.theme, AppThemeChoice.light);
      expect(restored.effectiveApiKey, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(demoConfigPrefsKey);
      expect(stored, isNotNull, reason: 'the config itself must be kept');
      expect(stored, isNot(contains('legacy-key')));
      expect(stored, isNot(contains('customApiKey')));
      expect(jsonDecode(stored!)['userId'], 'qa-tester-1');
    });

    test('drops a blob this build can no longer parse', () async {
      SharedPreferences.setMockInitialValues({
        demoConfigPrefsKey: jsonEncode({
          'apiKeySource': 'not_a_source', // schema drift
          'customApiKey': 'legacy-key',
          'userId': 'qa-tester-1',
          'theme': 'light',
          'serverEnv': 'custom',
        }),
      });

      expect(await loadPersistedDemoConfig(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(demoConfigPrefsKey),
        isNull,
        reason:
            'an unparsable blob sends the app back to the Config screen '
            'either way, and may still hold a plaintext key',
      );
    });

    test('keeps a valid stored blob when the prefs read fails', () async {
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'qa-tester-1',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );
      final blob = jsonEncode(config.toJson());
      const storageKey = 'flutter.$demoConfigPrefsKey';
      final disk = <String, Object>{storageKey: blob};
      final calls = <String>[];
      var failNextRead = true;
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final previousStore = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = previousStore;
      });

      // setMockInitialValues bypasses the channel. Reset the cached instance
      // and explicitly select the channel backend, regardless of test order.
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance =
          MethodChannelSharedPreferencesStore();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'getAll':
            // Fail once: an erroneous cleanup must be able to read and remove
            // the blob, otherwise a persistent failure would mask that bug.
            if (failNextRead) {
              failNextRead = false;
              throw PlatformException(code: 'transient_read_failure');
            }
            return Map<String, Object>.from(disk);
          case 'remove':
            disk.remove((call.arguments as Map)['key']);
            return true;
          case 'clear':
            disk.clear();
            return true;
          default:
            throw StateError('Unexpected prefs call: ${call.method}');
        }
      });

      expect(await loadPersistedDemoConfig(), isNull);
      expect(calls, [
        'getAll',
      ], reason: 'a read failure must not trigger cleanup');
      expect(disk[storageKey], blob);

      // The retry reads the same backing store, without resetting or reseeding.
      final prefs = await SharedPreferences.getInstance();
      expect(calls, ['getAll', 'getAll']);
      expect(prefs.getString(demoConfigPrefsKey), blob);
      final restored = await loadPersistedDemoConfig();
      expect(restored, isNotNull);
      expect(restored!.userId, config.userId);
      expect(restored.theme, config.theme);
    });

    test('leaves a blob written by this build untouched', () async {
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'example-custom-key',
        userId: 'qa-tester-1',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );
      // Equivalent JSON with reversed key order makes a toJson rewrite visible,
      // even when it would preserve every configuration value.
      final blob = jsonEncode(
        Map<String, dynamic>.fromEntries(
          config.toJson().entries.toList().reversed,
        ),
      );
      expect(blob, isNot(jsonEncode(config.toJson())));
      SharedPreferences.setMockInitialValues({demoConfigPrefsKey: blob});

      final restored = await loadPersistedDemoConfig();

      expect(restored, isNotNull);
      expect(restored!.userId, 'qa-tester-1');
      expect(restored.theme, AppThemeChoice.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(demoConfigPrefsKey), blob);
    });

    test('nothing stored → null, and nothing written', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await loadPersistedDemoConfig(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(demoConfigPrefsKey), isNull);
    });
  });
}
