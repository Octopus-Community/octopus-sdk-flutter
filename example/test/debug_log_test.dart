import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_log.dart';

/// Tests for [RealDebugLog]'s persistent typed-event buffer — the fix that lets
/// the Events scenario show events fired *before* it was opened.
///
/// [OctopusSDK.events] is a non-replaying broadcast derived from
/// [OctopusSDK.eventStream]. We drive the deterministic
/// [OctopusSDK.handleNativeEvent] seam (same pattern as the SDK's own tests)
/// rather than the async EventChannel, and verify the recorder captures typed
/// events into a session-long buffer and exposes clear semantics.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel('octopus_sdk_flutter/events');

  // No-op EventChannel mock so the lazy subscription start() triggers does not
  // log channel errors.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(onListen: (arguments, sink) {}),
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  late RealDebugLog log;

  setUp(() => log = RealDebugLog()..start());
  tearDown(() => log.dispose());

  // Pump enough event-loop turns for a value to flow through the broadcast
  // eventStream → where → map → typedEvents listener chain.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Map<String, dynamic> postCreated(String id) => {
    'event': 'sdkEvent',
    'type': 'postCreated',
    'postId': id,
    'content': <String>['text'],
    'topicId': 't1',
    'textLength': 5,
  };

  test('captures a typed sdkEvent into the persistent buffer', () async {
    OctopusSDK.handleNativeEvent(postCreated('p1'));
    await settle();

    expect(log.typedEvents, hasLength(1));
    final event = log.typedEvents.single;
    expect(event, isA<PostCreatedEvent>());
    expect((event as PostCreatedEvent).postId, 'p1');

    // The raw event also lands in the merged entries feed (Debug tab surface).
    expect(log.entries.any((e) => e.kind == DebugEntryKind.event), isTrue);
  });

  test('non-sdkEvents reach entries but not the typed buffer', () async {
    OctopusSDK.handleNativeEvent({
      'event': 'notSeenNotificationsCountChanged',
      'count': 3,
    });
    await settle();

    expect(log.typedEvents, isEmpty);
    expect(log.entries, isNotEmpty);
  });

  test('buffer is FIFO-capped at maxTypedEvents (oldest dropped)', () async {
    for (var i = 0; i < RealDebugLog.maxTypedEvents + 3; i++) {
      OctopusSDK.handleNativeEvent(postCreated('p$i'));
    }
    await settle();

    expect(log.typedEvents, hasLength(RealDebugLog.maxTypedEvents));
    // Oldest-first: the first 3 (p0..p2) were trimmed, so p3 is now the head.
    expect((log.typedEvents.first as PostCreatedEvent).postId, 'p3');
    expect(
      (log.typedEvents.last as PostCreatedEvent).postId,
      'p${RealDebugLog.maxTypedEvents + 2}',
    );
  });

  test(
    'clearTypedEvents() empties the typed buffer, leaving entries',
    () async {
      OctopusSDK.handleNativeEvent(postCreated('p1'));
      await settle();
      expect(log.typedEvents, isNotEmpty);
      final entriesBefore = log.entries.length;

      log.clearTypedEvents();

      expect(log.typedEvents, isEmpty);
      expect(log.entries, hasLength(entriesBefore));
    },
  );

  test('notifies listeners when a typed event arrives', () async {
    var notified = 0;
    log.addListener(() => notified++);

    OctopusSDK.handleNativeEvent(postCreated('p1'));
    await settle();

    expect(notified, greaterThan(0));
  });
}
