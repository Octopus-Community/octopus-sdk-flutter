import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/push_permission_gate.dart';

/// The notification permission prompt used to appear at cold start, over the
/// Config screen, because push setup asked before the SDK was initialised. The
/// gate is what holds it back — these pin when it opens and that it opens once.
void main() {
  late int requests;
  late PushPermissionGate gate;

  setUp(() {
    requests = 0;
    gate = PushPermissionGate(() async => requests++);
  });

  test('does not ask before the SDK is initialised', () async {
    await gate.onSignal(initialised: false, registrationEnabled: true);

    expect(requests, 0);
    expect(gate.requested, isFalse);
  });

  test('asks on the first initialisation with push registration on', () async {
    await gate.onSignal(initialised: false, registrationEnabled: true);
    await gate.onSignal(initialised: true, registrationEnabled: true);

    expect(requests, 1);
    expect(gate.requested, isTrue);
  });

  test('asks only once across re-initialisations', () async {
    await gate.onSignal(initialised: true, registrationEnabled: true);
    // switchCommunity re-init, then a toggle-on signal.
    await gate.onSignal(initialised: true, registrationEnabled: true);
    await gate.onSignal(initialised: true, registrationEnabled: true);

    expect(requests, 1);
  });

  test('waits for push registration to be turned on', () async {
    await gate.onSignal(initialised: true, registrationEnabled: false);
    expect(requests, 0);

    await gate.onSignal(initialised: true, registrationEnabled: true);
    expect(requests, 1);
  });

  test('two signals racing a pending request still ask once', () async {
    final pending = Completer<void>();
    var calls = 0;
    final racing = PushPermissionGate(() {
      calls++;
      return pending.future;
    });

    final first = racing.onSignal(initialised: true, registrationEnabled: true);
    final second = racing.onSignal(
      initialised: true,
      registrationEnabled: true,
    );
    pending.complete();
    await Future.wait([first, second]);

    expect(calls, 1);
  });
}
