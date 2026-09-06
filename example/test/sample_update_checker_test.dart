import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:octopus_sdk_flutter_example/update/sample_update_checker.dart';
import 'package:octopus_sdk_flutter_example/update/sample_update_status.dart';

/// Covers the two decisions the Flutter leg makes on Play's answer, plus the
/// string parse it needs and the Android sample does not (the plugin passes
/// `InstallException.getMessage()` through and drops the numeric code).
///
/// The stake is one-sided: reporting "up to date" to a tester holding a stale
/// build is the single answer that makes the card worse than not having it, so
/// every input that is not a plain "no update" is asserted to land elsewhere.
void main() {
  group('resolveUpdateStatus', () {
    test('no update available is up to date', () {
      expect(
        resolveUpdateStatus(
          availability: UpdateAvailability.updateNotAvailable,
          immediateAllowed: true,
        ),
        isA<UpdateUpToDate>(),
      );
    });

    test('unknown availability is up to date, not a failure', () {
      expect(
        resolveUpdateStatus(
          availability: UpdateAvailability.unknown,
          immediateAllowed: true,
        ),
        isA<UpdateUpToDate>(),
      );
    });

    test('an update Play will install carries its version code', () {
      final status = resolveUpdateStatus(
        availability: UpdateAvailability.updateAvailable,
        immediateAllowed: true,
        availableVersionCode: 1130042,
      );
      expect(status, isA<UpdateAvailableStatus>());
      expect((status as UpdateAvailableStatus).availableVersionCode, 1130042);
    });

    test('an update Play refuses is never reported as up to date', () {
      expect(
        resolveUpdateStatus(
          availability: UpdateAvailability.updateAvailable,
          immediateAllowed: false,
          availableVersionCode: 1130042,
        ),
        isA<UpdateNotInstallable>(),
      );
    });
  });

  group('parseInstallErrorCode', () {
    test('reads the code out of the message Play produces', () {
      expect(parseInstallErrorCode('Install Error(-10): App not owned'), -10);
    });

    test('a message in no recognisable shape yields null', () {
      expect(parseInstallErrorCode('something went wrong'), isNull);
      expect(parseInstallErrorCode(null), isNull);
    });

    test('a positive number in parentheses is not an error code', () {
      expect(parseInstallErrorCode('Retried (3) times'), isNull);
    });
  });

  group('resolveFailureStatus', () {
    test('the three no-ownership codes all read as not from Play Store', () {
      for (final code in const [-6, -9, -10]) {
        expect(
          resolveFailureStatus('Install Error($code): nope'),
          isA<UpdateNotFromPlayStore>(),
          reason: 'error code $code',
        );
      }
    });

    test('an internal Play error stays retryable and keeps its code', () {
      final status = resolveFailureStatus('Install Error(-100): internal');
      expect(status, isA<UpdateCheckFailed>());
      expect((status as UpdateCheckFailed).errorCode, -100);
    });

    test('an unreadable failure is retryable, not "not from Play"', () {
      // Failing this way round is deliberate: a tester told to retry loses a
      // tap, a tester told the wrong story loses the session.
      final status = resolveFailureStatus('connection reset');
      expect(status, isA<UpdateCheckFailed>());
      expect((status as UpdateCheckFailed).errorCode, isNull);
    });
  });

  group('acknowledgeNewVersion', () {
    test('says nothing when there is no update', () {
      expect(SampleUpdateChecker().acknowledgeNewVersion(), isNull);
    });

    test('reports nothing on an unsupported platform', () {
      final checker = SampleUpdateChecker(isSupported: false);
      expect(checker.status, isA<UpdateUnsupported>());
      expect(checker.acknowledgeNewVersion(), isNull);
    });
  });
}
