import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/consent_texts_scenario.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('octopus_sdk_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Completer<void>? pending;
  String? failingMethod;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    pending = null;
    failingMethod = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == failingMethod) {
        throw PlatformException(code: 'OVERRIDE_ERROR');
      }
      if (call.method.startsWith('debugOverride')) await pending?.future;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets(
    'eight native presets and clear carry exact modes and unchanged texts',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: ConsentTextsScenario()),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < consentTextsPresets.length; i++) {
        final preset = consentTextsPresets[i];
        calls.clear();
        await tester.tap(
          find.bySemanticsIdentifier('qa-preset-consentTexts-${i + 1}'),
        );
        await tester.pumpAndSettle();
        expect(calls.map((e) => e.method), [
          'debugOverrideTermsAcceptanceMode',
          'debugOverrideConsentTexts',
        ]);
        expect(calls[0].arguments, {'mode': preset.mode.toNativeValue()});
        expect(calls[1].arguments, {'texts': preset.texts.toMap()});
        expect(app.debugScenarioOverrides.consentTexts?.value, preset.texts);
        expect(
          find.bySemanticsIdentifier('consentTexts-result'),
          findsOneWidget,
        );
      }
      expect(
        consentTextsPresets[6].texts,
        const OctopusConsentTexts.singleCheckbox(label: '', belowText: '   '),
      );
      expect(
        consentTextsPresets[7].mode,
        TermsAcceptanceMode.explicitMultiCheckbox,
      );
      expect(
        consentTextsPresets[7].texts.mode,
        OctopusConsentTextsMode.implicit,
      );
      for (var i = 0; i < 2; i++) {
        calls.clear();
        await tester.tap(
          find.bySemanticsIdentifier('qa-preset-consentTexts-clear'),
        );
        await tester.pumpAndSettle();
        expect(calls.map((e) => e.method), [
          'debugOverrideConsentTexts',
          'debugOverrideTermsAcceptanceMode',
        ]);
        expect(calls[0].arguments, {'texts': null});
        expect(calls[1].arguments, {'mode': null});
        expect(app.debugScenarioOverrides.consentTexts, isNull);
        expect(app.debugScenarioOverrides.termsAcceptance, isNull);
      }
    },
  );

  test(
    'holder preserves disconnect, clears stop, and rejects late completion',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      final preset = consentTextsPresets.first;
      await app.applyConsentTexts(preset.texts, preset.mode, preset.label);
      await app.disconnectUser();
      expect(app.debugScenarioOverrides.consentTexts?.value, preset.texts);
      pending = Completer<void>();
      final apply = app.applyConsentTexts(
        preset.texts,
        preset.mode,
        preset.label,
      );
      await Future<void>.delayed(Duration.zero);
      await app.stopForScenario();
      pending!.complete();
      await apply;
      expect(app.debugScenarioOverrides.consentTexts, isNull);
      expect(app.debugScenarioOverrides.termsAcceptance, isNull);
    },
  );

  test(
    'failed second call records only the applied mode; clear failure records cleared texts',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      final preset = consentTextsPresets.first;
      failingMethod = 'debugOverrideConsentTexts';
      await expectLater(
        app.applyConsentTexts(preset.texts, preset.mode, preset.label),
        throwsA(isA<PlatformException>()),
      );
      expect(app.debugScenarioOverrides.termsAcceptance?.value, preset.mode);
      expect(app.debugScenarioOverrides.consentTexts, isNull);
      failingMethod = null;
      await app.applyConsentTexts(preset.texts, preset.mode, preset.label);
      failingMethod = 'debugOverrideTermsAcceptanceMode';
      await expectLater(
        app.applyConsentTexts(null, null, 'Clear'),
        throwsA(isA<PlatformException>()),
      );
      expect(app.debugScenarioOverrides.consentTexts, isNull);
      expect(app.debugScenarioOverrides.termsAcceptance?.value, preset.mode);
    },
  );
}
