import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/api_key_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _config = DemoConfig(
  apiKeySource: ApiKeySource.demo,
  selectedInjectedKey: InjectedApiKey(
    id: 'fixture',
    label: 'Fixture',
    key: 'fixture-only',
  ),
  userId: 'first-user',
  theme: AppThemeChoice.system,
  serverEnv: ServerEnv.custom,
  customHost: 'fixture.example.test',
);

const ConnectedDemoProfile _firstProfile = (
  userId: 'first-user',
  nickname: 'First name',
  bio: 'First bio',
  picture: 'https://example.com/first.png',
);
const ConnectedDemoProfile _secondProfile = (
  userId: 'second-user',
  nickname: 'Second name',
  bio: '',
  picture: null,
);

String _storageKey(String userId) => 'octopus_host_profile_v1:$userId';

String _encodeProfile(ConnectedDemoProfile profile) => jsonEncode({
  'userId': profile.userId,
  'nickname': profile.nickname,
  'bio': profile.bio,
  'picture': profile.picture,
});

Future<void> _noteProfile(AppState app, ConnectedDemoProfile profile) =>
    app.noteConnectedProfile(
      userId: profile.userId,
      nickname: profile.nickname,
      bio: profile.bio,
      picture: profile.picture,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sdkChannel = MethodChannel('octopus_sdk_flutter');
  const eventsChannel = EventChannel('octopus_sdk_flutter/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late AppState app;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      _storageKey(_firstProfile.userId): _encodeProfile(_firstProfile),
      _storageKey(_secondProfile.userId): _encodeProfile(_secondProfile),
    });
    calls.clear();
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      calls.add(call);
      return null;
    });
    app = AppState(buildConfig: _config);
  });

  tearDown(() async {
    await app.octopus.stop();
    app.dispose();
    messenger.setMockMethodCallHandler(sdkChannel, null);
    messenger.setMockStreamHandler(eventsChannel, null);
  });

  void expectNoConnection() {
    expect(
      calls.where((call) => call.method.startsWith('connectUser')),
      isEmpty,
      reason: 'restoring a host snapshot must not connect the SDK user',
    );
  }

  void usePreferencesBackend(Future<Object?> Function(MethodCall) handler) {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final previousStore = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previousStore;
    });
  }

  test('stop and restart restore the complete host snapshot', () async {
    await app.start(_config);
    expect(app.initialized, isTrue);
    expect(app.connectedProfile, _firstProfile);
    expect(app.connectedProfile?.userId, _firstProfile.userId);

    await app.stopForScenario();
    expect(app.stopped, isTrue);
    expect(app.connectedProfile, isNull);
    expect(app.effectiveUserId, _firstProfile.userId);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_storageKey(_firstProfile.userId)),
      _encodeProfile(_firstProfile),
    );

    await app.restartForScenario();
    expect(app.initialized, isTrue);
    expect(app.stopped, isFalse);
    expect(app.initError, isNull);
    expect(app.connectedProfile, _firstProfile);
    expect(app.profileForEditing, _firstProfile);
    expect(calls.where((call) => call.method == 'initialize'), hasLength(2));
    expect(calls.where((call) => call.method == 'stop'), hasLength(1));
    expectNoConnection();
  });

  test(
    'another user late note preserves the completed active restore',
    () async {
      await app.start(_config);
      expect(app.profileForEditing, _firstProfile);

      await _noteProfile(app, _secondProfile);
      expect(app.connectedProfile, _firstProfile);
      expect(app.connectedProfile?.userId, _firstProfile.userId);
      expect(app.profileForEditing, _firstProfile);

      await app.disconnectUser();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
      expect(
        prefs.getString(_storageKey(_secondProfile.userId)),
        _encodeProfile(_secondProfile),
      );
      expectNoConnection();
    },
  );

  for (final target in ['key', 'host', 'port']) {
    test(
      'starting a different community $target after stop clears snapshots',
      () async {
        await app.start(_config);
        await app.stopForScenario();
        await app.start(
          _config.copyWith(
            apiKeySource: target == 'key'
                ? ApiKeySource.custom
                : _config.apiKeySource,
            customApiKey: target == 'key' ? 'other-fixture' : '',
            customHost: target == 'host'
                ? 'other.example.test'
                : _config.customHost,
            customPort: target == 'port' ? 8443 : _config.customPort,
          ),
        );
        expect(app.initialized, isTrue);
        expect(app.connectedProfile, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
        expect(prefs.getString(_storageKey(_secondProfile.userId)), isNull);
        expectNoConnection();
      },
    );

    test(
      'switching community $target clears snapshots before restart',
      () async {
        await app.start(_config);
        await app.switchToCommunity(
          target == 'key' ? 'other-fixture' : _config.effectiveApiKey,
          apiServer: ApiServer(
            host: target == 'host'
                ? 'other.example.test'
                : _config.resolvedHost,
            port: target == 'port' ? 8443 : 443,
          ),
        );
        expect(app.connectedProfile, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
        expect(prefs.getString(_storageKey(_secondProfile.userId)), isNull);
        await app.stopForScenario();
        await app.restartForScenario();
        expect(app.connectedProfile, isNull);
        expect(app.profileForEditing.nickname, _firstProfile.userId);
        expectNoConnection();
      },
    );
  }

  test('a refused community switch keeps the profile baseline', () async {
    await app.start(_config);
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      if (call.method == 'switchCommunity') {
        throw PlatformException(code: 'fixture_failure');
      }
      return null;
    });
    await expectLater(
      app.switchToCommunity('other-fixture'),
      throwsA(isA<PlatformException>()),
    );
    expect(app.connectedProfile, _firstProfile);
  });

  test(
    'Change Configuration restores each selected user while running',
    () async {
      await app.start(_config);
      expect(app.connectedProfile, _firstProfile);
      await app.start(_config.copyWith(userId: _secondProfile.userId));
      expect(app.initialized, isTrue);
      expect(app.initError, isNull);
      expect(app.connectedProfile, _secondProfile);
      expect(app.profileForEditing, _secondProfile);

      await app.start(_config);
      expect(app.connectedProfile, _firstProfile);
      expect(calls.where((call) => call.method == 'initialize'), hasLength(1));
      expect(
        calls.where((call) => call.method == 'switchCommunity'),
        hasLength(2),
      );
      expectNoConnection();
    },
  );

  test(
    'disconnect during Change Configuration preserves the previous user snapshot',
    () async {
      await app.start(_config);
      expect(app.connectedProfile, _firstProfile);
      final switchStarted = Completer<void>();
      final releaseSwitch = Completer<void>();
      messenger.setMockMethodCallHandler(sdkChannel, (call) async {
        calls.add(call);
        if (call.method == 'switchCommunity') {
          switchStarted.complete();
          await releaseSwitch.future;
        }
        return null;
      });

      final switchUser = app.start(
        _config.copyWith(userId: _secondProfile.userId),
      );
      await switchStarted.future;
      try {
        // The active user is B while the private snapshot still belongs to A:
        // the native switch has not completed or restored B's snapshot yet.
        expect(app.effectiveUserId, _secondProfile.userId);
        expect(app.connectedProfile, isNull);
        await app.disconnectUser();
      } finally {
        releaseSwitch.complete();
        await switchUser;
      }

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_storageKey(_firstProfile.userId)),
        _encodeProfile(_firstProfile),
      );
      expect(prefs.getString(_storageKey(_secondProfile.userId)), isNull);
      expect(app.initError, isNull);
      expect(app.connectedProfile, isNull);
      expectNoConnection();
    },
  );

  test(
    'successful late connect notifies that the stale error cleared',
    () async {
      await app.start(_config);
      app.noteConnectFailure('Previous connect failed');
      final connectStarted = Completer<void>();
      final releaseConnect = Completer<Map<String, Object>>();
      messenger.setMockMethodCallHandler(sdkChannel, (call) async {
        if (call.method == 'connectUser') {
          connectStarted.complete();
          return releaseConnect.future;
        }
        return null;
      });
      final connect = app.connectWithProfile(
        userId: _firstProfile.userId,
        nickname: 'Late name',
      );
      await connectStarted.future;
      final observedErrors = <String?>[];
      app.addListener(() => observedErrors.add(app.lastConnectError));
      try {
        await app.start(_config.copyWith(userId: _secondProfile.userId));
        expect(app.connectedProfile, _secondProfile);
        expect(app.lastConnectError, 'Previous connect failed');
        observedErrors.clear();
      } finally {
        releaseConnect.complete({'type': 'success'});
      }

      expect(await connect, isA<OctopusSuccess<void, ClientUserError>>());
      expect(app.lastConnectError, isNull);
      expect(observedErrors, [null]);
      expect(app.connectedProfile, _secondProfile);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(_storageKey(_firstProfile.userId))!), {
        'userId': _firstProfile.userId,
        'nickname': 'Late name',
        'bio': null,
        'picture': null,
      });
    },
  );

  test('Settings reset clears snapshots for all users', () async {
    await app.start(_config);
    // Reset must also drain a pending write before removing all snapshots.
    final write = _noteProfile(app, _firstProfile);
    await app.reset();
    await write;
    expect(app.connectedProfile, isNull);
    expect(app.config, isNull);
    expect(app.initialized, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
    expect(prefs.getString(_storageKey(_secondProfile.userId)), isNull);

    for (final userId in [_firstProfile.userId, _secondProfile.userId]) {
      await app.start(_config.copyWith(userId: userId));
      expect(app.connectedProfile, isNull);
      expect(app.profileForEditing.nickname, userId);
    }
    expectNoConnection();
  });

  test(
    'a snapshot noted during storage restore supersedes the disk value',
    () async {
      final readStarted = Completer<void>();
      final read = Completer<Map<String, Object>>();
      final releaseWrite = Completer<bool>();
      final newer = (
        userId: _firstProfile.userId,
        nickname: 'New name',
        bio: 'New bio',
        picture: 'https://example.com/new.png',
      );
      late Future<void> newerWrite;
      usePreferencesBackend((call) async {
        if (call.method == 'getAll') {
          readStarted.complete();
          return read.future;
        }
        if (call.method == 'setString' &&
            call.arguments['key'] ==
                'flutter.${_storageKey(_secondProfile.userId)}') {
          // Keep the newer write queued so the preference cache still holds
          // the old first-user snapshot when the restore resumes.
          return releaseWrite.future;
        }
        return true;
      });

      final start = app.start(_config);
      await readStarted.future;
      final write = _noteProfile(app, _secondProfile);
      // Note before releasing the read, independently of the plugin's
      // getInstance/setString continuation order.
      newerWrite = _noteProfile(app, newer);
      read.complete({
        'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
          _firstProfile,
        ),
      });
      try {
        await start;
        expect(app.initError, isNull);
        expect(app.connectedProfile, newer);
        expect(app.profileForEditing, newer);
      } finally {
        releaseWrite.complete(true);
        await write;
        await newerWrite;
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_storageKey(newer.userId)), _encodeProfile(newer));
      expectNoConnection();
    },
  );

  test('noting another user does not cancel the active user restore', () async {
    final readStarted = Completer<void>();
    final read = Completer<Map<String, Object>>();
    final releaseWrite = Completer<bool>();
    usePreferencesBackend((call) async {
      if (call.method == 'getAll') {
        readStarted.complete();
        return read.future;
      }
      if (call.method == 'setString' &&
          call.arguments['key'] ==
              'flutter.${_storageKey(_secondProfile.userId)}') {
        return releaseWrite.future;
      }
      return true;
    });

    final start = app.start(_config);
    await readStarted.future;
    final write = _noteProfile(app, _secondProfile);
    read.complete({
      'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
        _firstProfile,
      ),
    });
    try {
      await start;
      expect(app.initError, isNull);
      expect(app.effectiveUserId, _firstProfile.userId);
      expect(app.connectedProfile, _firstProfile);
      expect(app.profileForEditing, _firstProfile);
    } finally {
      releaseWrite.complete(true);
      await write;
    }
    expect(app.connectedProfile, _firstProfile);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_storageKey(_firstProfile.userId)),
      _encodeProfile(_firstProfile),
    );
    expect(
      prefs.getString(_storageKey(_secondProfile.userId)),
      _encodeProfile(_secondProfile),
    );
    expectNoConnection();
  });

  test('a newer restore supersedes a read waiting for writes', () async {
    final writeStarted = Completer<void>();
    final secondWriteStarted = Completer<void>();
    final releaseFirstWrite = Completer<bool>();
    final releaseSecondWrite = Completer<bool>();
    var writes = 0;
    usePreferencesBackend((call) async {
      if (call.method == 'getAll') {
        return {
          'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
            _firstProfile,
          ),
        };
      }
      if (call.method == 'setString' &&
          call.arguments['key'] ==
              'flutter.${_storageKey(_secondProfile.userId)}') {
        if (++writes == 1) {
          writeStarted.complete();
          return releaseFirstWrite.future;
        }
        secondWriteStarted.complete();
        return releaseSecondWrite.future;
      }
      return true;
    });

    final firstWrite = _noteProfile(app, _secondProfile);
    await writeStarted.future;
    final olderStart = app.start(_config);
    final secondWrite = _noteProfile(app, _secondProfile);
    // Same user: effectiveUserId alone cannot reject the older restore.
    final newerStart = app.start(_config);
    releaseFirstWrite.complete(true);
    await secondWriteStarted.future;
    try {
      await olderStart;
      expect(app.connectedProfile, isNull);
    } finally {
      releaseSecondWrite.complete(true);
      await firstWrite;
      await secondWrite;
      await newerStart;
    }
    expect(app.connectedProfile, _firstProfile);
    expect(app.profileForEditing, _firstProfile);
    expectNoConnection();
  });

  test('clearing the active user supersedes a pending storage read', () async {
    final writeStarted = Completer<void>();
    final readStarted = Completer<void>();
    final read = Completer<Map<String, Object>>();
    final releaseFirstWrite = Completer<bool>();
    final releaseSecondWrite = Completer<bool>();
    var reads = 0;
    var writes = 0;
    usePreferencesBackend((call) async {
      if (call.method == 'getAll') {
        if (++reads == 1) {
          return {
            'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
              _firstProfile,
            ),
          };
        }
        readStarted.complete();
        return read.future;
      }
      if (call.method == 'setString' &&
          call.arguments['key'] ==
              'flutter.${_storageKey(_secondProfile.userId)}') {
        if (++writes == 1) {
          writeStarted.complete();
          return releaseFirstWrite.future;
        }
        return releaseSecondWrite.future;
      }
      return true;
    });

    final firstWrite = _noteProfile(app, _secondProfile);
    await writeStarted.future;
    // A fresh preferences read lets us hold getInstance after the restore
    // has cleared the other user's in-memory snapshot.
    SharedPreferences.resetStatic();
    final start = app.start(_config);
    final secondWrite = _noteProfile(app, _secondProfile);
    releaseFirstWrite.complete(true);
    await readStarted.future;
    final clear = app.disconnectUser();
    await pumpEventQueue(times: 1);
    read.complete({
      'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
        _firstProfile,
      ),
    });
    // The clear is queued behind the second write, so it cannot remove the
    // cached disk value and mask a missing generation check in the restore.
    try {
      await start;
      expect(app.connectedProfile, isNull);
      expect(app.profileForEditing.nickname, _firstProfile.userId);
    } finally {
      releaseSecondWrite.complete(true);
      await firstWrite;
      await secondWrite;
      await clear;
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
    expectNoConnection();
  });

  test('an all-users clear supersedes a pending storage read', () async {
    final readStarted = Completer<void>();
    final read = Completer<Map<String, Object>>();
    final releaseWrite = Completer<bool>();
    usePreferencesBackend((call) async {
      if (call.method == 'getAll') {
        readStarted.complete();
        return read.future;
      }
      if (call.method == 'setString' &&
          call.arguments['key'] ==
              'flutter.${_storageKey(_secondProfile.userId)}') {
        return releaseWrite.future;
      }
      return true;
    });

    final start = app.start(_config);
    await readStarted.future;
    final write = _noteProfile(app, _secondProfile);
    // The cached user differs from the restored user: only the global
    // invalidation for allUsers can supersede this restore.
    final reset = app.reset();
    await pumpEventQueue(times: 1);
    read.complete({
      'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
        _firstProfile,
      ),
    });
    try {
      await start;
      expect(app.effectiveUserId, _firstProfile.userId);
      expect(app.connectedProfile, isNull);
    } finally {
      releaseWrite.complete(true);
      await write;
      await reset;
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_storageKey(_firstProfile.userId)), isNull);
    expect(prefs.getString(_storageKey(_secondProfile.userId)), isNull);
    expectNoConnection();
  });

  test('stop supersedes a pending storage read without deleting it', () async {
    final readStarted = Completer<void>();
    final read = Completer<Map<String, Object>>();
    usePreferencesBackend((call) async {
      if (call.method == 'getAll') {
        readStarted.complete();
        return read.future;
      }
      return true;
    });

    final start = app.start(_config);
    await readStarted.future;
    await app.stopForScenario();
    read.complete({
      'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
        _firstProfile,
      ),
    });
    await start;
    expect(app.connectedProfile, isNull);
    expect(app.profileForEditing.nickname, _firstProfile.userId);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_storageKey(_firstProfile.userId)),
      _encodeProfile(_firstProfile),
    );
    expectNoConnection();
  });

  test(
    'a snapshot noted while restore waits for pending writes is retained',
    () async {
      final writeStarted = Completer<void>();
      final releaseFirstWrite = Completer<bool>();
      final releaseSecondWrite = Completer<bool>();
      var writes = 0;
      usePreferencesBackend((call) async {
        if (call.method == 'getAll') {
          return {
            'flutter.${_storageKey(_firstProfile.userId)}': _encodeProfile(
              _firstProfile,
            ),
          };
        }
        if (call.method == 'setString' &&
            call.arguments['key'] ==
                'flutter.${_storageKey(_secondProfile.userId)}') {
          if (++writes == 1) {
            writeStarted.complete();
            return releaseFirstWrite.future;
          }
          return releaseSecondWrite.future;
        }
        return true;
      });

      final firstWrite = _noteProfile(app, _secondProfile);
      await writeStarted.future;
      final start = app.start(_config);
      // Queue another blocked write ahead of the newer profile. The old
      // first-user disk snapshot then remains readable throughout restore.
      final secondWrite = _noteProfile(app, _secondProfile);
      final newer = (
        userId: _firstProfile.userId,
        nickname: 'New name',
        bio: 'New bio',
        picture: null,
      );
      final newerWrite = _noteProfile(app, newer);
      releaseFirstWrite.complete(true);
      try {
        await start;
        expect(app.connectedProfile, newer);
        expect(app.profileForEditing, newer);
      } finally {
        releaseSecondWrite.complete(true);
        await firstWrite;
        await secondWrite;
        await newerWrite;
      }
      expectNoConnection();
    },
  );
}
