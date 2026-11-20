import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/auth/profile_edit_page.dart';
import 'package:octopus_sdk_flutter_example/auth/client_user_token_signer.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SigningApp extends AppState {
  @override
  Future<String> createClientUserToken(String userId) async =>
      ClientUserTokenSigner.signWith(
        secret: 'demo-test-secret',
        userId: userId,
        entitlements: currentEntitlements,
        exp: 9999999999,
      );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        '$brightness Bio icon aligns with Nickname at text scale $textScale',
        (tester) async {
          tester.view.physicalSize = const Size(500, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: const ProfileEditPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final nickname = find.widgetWithText(TextFormField, 'Nickname');
          final bio = find.widgetWithText(TextFormField, 'Bio');
          final nicknameIcon = find.descendant(
            of: nickname,
            matching: find.byIcon(Icons.person),
          );
          final bioIcon = find.descendant(
            of: bio,
            matching: find.byIcon(Icons.description),
          );

          void expectAlignedIcons() {
            expect(
              tester.getCenter(bioIcon).dx - tester.getTopLeft(bio).dx,
              closeTo(
                tester.getCenter(nicknameIcon).dx -
                    tester.getTopLeft(nickname).dx,
                0.1,
              ),
            );
            expect(
              tester.getCenter(bioIcon).dy - tester.getTopLeft(bio).dy,
              closeTo(
                tester.getCenter(nicknameIcon).dy -
                    tester.getTopLeft(nickname).dy,
                0.1,
              ),
            );
            expect(tester.takeException(), isNull);
          }

          expectAlignedIcons();
          await tester.enterText(bio, 'First line\nSecond line\nThird\nFourth');
          await tester.pumpAndSettle();
          expectAlignedIcons();
        },
      );
    }
  }

  group('saving host-managed profile fields', () {
    const channel = MethodChannel('octopus_sdk_flutter');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final tokenReplies = <Map>[];
    late AppState app;
    late Map<String, Object> response;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Sample',
        packageName: 'sample',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      response = {'type': 'success'};
      calls.clear();
      tokenReplies.clear();
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'connectUser') calls.add(call);
        if (call.method == 'provideClientUserToken') {
          tokenReplies.add(call.arguments as Map);
        }
        return response;
      });
      app = _SigningApp();
      app.setTestProfile(
        nickname: 'Connected name',
        bio: 'Connected bio',
        avatarUrl: 'https://example.com/avatar.png',
      );
      await app.connectDemoUser(sendTestProfile: true);
      calls.clear();
    });

    tearDown(() async {
      await app.octopus.disconnectUser();
      app.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        null,
      );
    });

    Future<void> openEditor(WidgetTester tester, {String? fieldToEdit}) async {
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditPage(fieldToEdit: fieldToEdit),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Map<String, Object?> sentProfile() {
      final arguments = calls.last.arguments as Map;
      expect(arguments['userId'], app.effectiveUserId);
      return {
        for (final field in ['nickname', 'bio', 'picture'])
          field: arguments[field],
      };
    }

    Future<void> coldStart(WidgetTester tester, {String? userId}) async {
      final restoredId = userId ?? app.effectiveUserId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        demoConfigPrefsKey,
        jsonEncode(
          buildInitialDemoConfig(host: '', userId: restoredId).toJson(),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      calls.clear();
      await tester.runAsync(() async {
        app = AppState(
          buildConfig: buildInitialDemoConfig(
            host: 'build.example.test',
            userId: 'build-user',
          ),
        );
        await app.bootstrap();
      });
      expect(app.effectiveUserId, restoredId);
      expect(calls, isEmpty, reason: 'restoring must not call connectUser');
    }

    test('connectDemoUser notifies exactly once on success', () async {
      var notifications = 0;
      app.addListener(() => notifications++);

      final result = await app.connectDemoUser();

      expect(result, isA<OctopusSuccess<void, ClientUserError>>());
      expect(notifications, 1);
      expect(calls, hasLength(1));
      expect(app.connectedProfile?.userId, app.effectiveUserId);
    });

    testWidgets(
      'saving retains a live entitlement provider and notifies once',
      (tester) async {
        app.setCurrentEntitlements({'premium'});
        await openEditor(tester, fieldToEdit: 'BIO');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Bio'),
          'Updated bio',
        );
        var notifications = 0;
        app.addListener(() => notifications++);
        await save(tester);
        expect(notifications, 1);
        expect(app.currentEntitlements, {'premium'});
        final providerId = (calls.last.arguments as Map)['providerId'];

        Future<Map<String, dynamic>> requestToken(String requestId) async {
          OctopusSDK.handleNativeEvent({
            'event': 'clientUserTokenRequest',
            'providerId': providerId,
            'requestId': requestId,
          });
          await tester.pumpAndSettle();
          expect(tokenReplies.last['requestId'], requestId);
          final token = tokenReplies.last['token'] as String;
          return jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
        }

        final initial = await requestToken('initial-profile-save');
        expect(initial['sub'], app.effectiveUserId);
        expect(initial['entitlements'], ['premium']);
        app.setCurrentEntitlements({'premium', 'moderator'});
        final refreshed = await requestToken('refresh-after-profile-save');
        expect(refreshed['sub'], app.effectiveUserId);
        expect(refreshed['entitlements'], ['moderator', 'premium']);
        expect(calls, hasLength(1));
      },
    );

    testWidgets(
      'cold start restores a snapshot and a bio-only save persists it',
      (tester) async {
        await coldStart(tester);
        expect(app.connectedProfile?.nickname, 'Connected name');
        expect(app.connectedProfile?.picture, 'https://example.com/avatar.png');
        await openEditor(tester, fieldToEdit: 'BIO');
        final bio = find.widgetWithText(TextFormField, 'Bio');
        expect(
          tester.widget<TextFormField>(bio).controller!.text,
          'Connected bio',
        );
        await tester.enterText(bio, 'Cold-start bio');
        await save(tester);
        expect(sentProfile(), {
          'nickname': 'Connected name',
          'bio': 'Cold-start bio',
          'picture': 'https://example.com/avatar.png',
        });
        await coldStart(tester);
        expect(app.connectedProfile?.bio, 'Cold-start bio');
        expect(app.connectedProfile?.nickname, 'Connected name');
        expect(app.connectedProfile?.picture, 'https://example.com/avatar.png');
      },
    );

    testWidgets(
      'cold start without a snapshot sends defaults, never null clears',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await coldStart(tester);
        expect(app.connectedProfile, isNull);
        await openEditor(tester, fieldToEdit: 'BIO');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Bio'),
          'New bio',
        );
        await save(tester);
        expect(sentProfile(), {
          'nickname': app.effectiveUserId,
          'bio': 'New bio',
          'picture': 'https://i.pravatar.cc/150',
        });
      },
    );

    testWidgets('a restored empty profile preserves unedited fields', (
      tester,
    ) async {
      await app.connectDemoUser();
      await coldStart(tester);
      expect(app.connectedProfile, isNotNull);
      expect(app.connectedProfile?.nickname, isNull);
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'New bio',
      );
      await save(tester);
      expect(sentProfile(), {
        'nickname': null,
        'bio': 'New bio',
        'picture': null,
      });
    });

    testWidgets('sign-out removes the snapshot before the next cold start', (
      tester,
    ) async {
      await app.disconnectUser();
      await coldStart(tester);
      expect(app.connectedProfile, isNull);
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'New bio',
      );
      await save(tester);
      expect(sentProfile()['nickname'], app.effectiveUserId);
      expect(sentProfile()['picture'], 'https://i.pravatar.cc/150');
    });

    testWidgets('cold start isolates snapshots per user id', (tester) async {
      final originalId = app.effectiveUserId;
      await coldStart(tester, userId: 'other-user');
      expect(app.connectedProfile, isNull);
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'Other bio',
      );
      await save(tester);
      expect(sentProfile(), {
        'nickname': 'other-user',
        'bio': 'Other bio',
        'picture': 'https://i.pravatar.cc/150',
      });
      await coldStart(tester, userId: originalId);
      expect(app.connectedProfile?.nickname, 'Connected name');
      expect(app.connectedProfile?.bio, 'Connected bio');
      expect(app.connectedProfile?.picture, 'https://example.com/avatar.png');
      await coldStart(tester, userId: 'other-user');
      expect(app.connectedProfile?.bio, 'Other bio');
    });

    testWidgets('a rejected edit leaves the persisted snapshot unchanged', (
      tester,
    ) async {
      response = {'type': 'failure', 'kind': 'noNetwork'};
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'Rejected bio',
      );
      await save(tester);
      await coldStart(tester);
      expect(app.connectedProfile?.bio, 'Connected bio');
      expect(app.connectedProfile?.nickname, 'Connected name');
      expect(app.connectedProfile?.picture, 'https://example.com/avatar.png');
    });

    testWidgets('bio-only edit preserves the connected nickname and avatar', (
      tester,
    ) async {
      // Account inputs are drafts until reconnecting: they must not replace
      // the values already connected when editing a different field.
      app.setTestProfile(
        nickname: 'Unsent name',
        bio: 'Unsent bio',
        avatarUrl: 'https://example.com/unsent.png',
      );
      await openEditor(tester, fieldToEdit: 'BIO');
      final bio = find.widgetWithText(TextFormField, 'Bio');
      expect(
        tester.widget<TextFormField>(bio).controller!.text,
        'Connected bio',
      );
      expect(find.widgetWithText(TextFormField, 'Nickname'), findsNothing);
      await tester.enterText(bio, ' Updated bio ');
      await save(tester);
      expect(calls, hasLength(1));
      expect(sentProfile(), {
        'nickname': 'Connected name',
        'bio': 'Updated bio',
        'picture': 'https://example.com/avatar.png',
      });
    });

    testWidgets('successive single-field edits keep the latest saved values', (
      tester,
    ) async {
      await openEditor(tester, fieldToEdit: 'NICKNAME');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname'),
        'Updated name',
      );
      await save(tester);
      expect(sentProfile(), {
        'nickname': 'Updated name',
        'bio': 'Connected bio',
        'picture': 'https://example.com/avatar.png',
      });
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'Updated bio',
      );
      await save(tester);
      expect(sentProfile(), {
        'nickname': 'Updated name',
        'bio': 'Updated bio',
        'picture': 'https://example.com/avatar.png',
      });
    });

    testWidgets('multi-field edit sends both edits and preserves the avatar', (
      tester,
    ) async {
      await openEditor(tester);
      final nickname = find.widgetWithText(TextFormField, 'Nickname');
      expect(
        tester.widget<TextFormField>(nickname).controller!.text,
        'Connected name',
      );
      await tester.enterText(nickname, ' Updated name ');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        ' Updated bio ',
      );
      await save(tester);
      expect(sentProfile(), {
        'nickname': 'Updated name',
        'bio': 'Updated bio',
        'picture': 'https://example.com/avatar.png',
      });
    });

    testWidgets(
      'an explicitly empty bio clears it while keeping other fields',
      (tester) async {
        await openEditor(tester, fieldToEdit: 'BIO');
        await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), '  ');
        await save(tester);
        expect(sentProfile(), {
          'nickname': 'Connected name',
          'bio': '',
          'picture': 'https://example.com/avatar.png',
        });
        expect(app.connectedProfile?.bio, '');
      },
    );

    testWidgets('a refused save leaves the connected profile unchanged', (
      tester,
    ) async {
      response = {
        'type': 'failure',
        'kind': 'statusError',
        'code': 400,
        'description': 'Rejected profile',
      };
      await openEditor(tester, fieldToEdit: 'BIO');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio'),
        'Rejected bio',
      );
      await save(tester);
      expect(find.byType(ProfileEditPage), findsOneWidget);
      expect(app.connectedProfile?.bio, 'Connected bio');
      expect(app.connectedProfile?.nickname, 'Connected name');
      expect(app.connectedProfile?.picture, 'https://example.com/avatar.png');
    });

    test('a refused reconnect does not replace the connected values', () async {
      app.setTestProfile(nickname: 'Rejected name');
      response = {'type': 'failure', 'kind': 'noNetwork'};
      await app.connectDemoUser(sendTestProfile: true);
      expect(app.connectedProfile?.nickname, 'Connected name');
    });

    test(
      'disconnect forgets the connected profile but keeps the draft',
      () async {
        await app.disconnectUser();
        expect(app.connectedProfile, isNull);
        expect(app.testNickname, 'Connected name');
      },
    );
  });
}
