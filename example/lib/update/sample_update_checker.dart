import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_update/in_app_update.dart';

import '../app_log.dart';
import 'sample_update_status.dart';

/// Play error codes that all mean the same thing to a tester: Play does not own
/// this install, so it has nothing to offer. Values read off
/// `com.google.android.play:app-update:2.1.0`; the Android sample folds the
/// same three.
const int _errorInstallNotAllowed = -6;
const int _errorPlayStoreNotFound = -9;
const int _errorAppNotOwned = -10;

/// `InstallException.getMessage()` reaches Dart as the message of a
/// `PlatformException('TASK_FAILURE')` — the plugin passes it through verbatim
/// and does not expose the numeric code. Play formats it as
/// `Install Error(-10): ...`, so the code is recoverable, but only by reading
/// the string.
final RegExp _installErrorCodePattern = RegExp(r'\((-\d+)\)');

/// Recovers the Play error code from a failed check, or null when the message
/// is not in the shape Play produces.
///
/// This is a string parse, and it is the one fragile point of the Flutter leg —
/// the Android sample gets the same number as an `Int`. It is written to fail
/// towards the safe answer: an unrecognised message yields null, which reports
/// a retryable failure rather than silently claiming the build is not from
/// Play. A tester told to retry loses a tap; a tester told the wrong story
/// loses the session.
int? parseInstallErrorCode(String? message) {
  if (message == null) return null;
  final match = _installErrorCodePattern.firstMatch(message);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// Maps what Play answered. Pure, so it is testable without a device — the part
/// worth testing is which outcome each combination reports, not the plugin
/// plumbing.
SampleUpdateStatus resolveUpdateStatus({
  required UpdateAvailability availability,
  required bool immediateAllowed,
  int? availableVersionCode,
}) {
  if (availability != UpdateAvailability.updateAvailable) {
    return const UpdateUpToDate();
  }
  if (!immediateAllowed) return const UpdateNotInstallable();
  return UpdateAvailableStatus(availableVersionCode);
}

/// Maps a failed check.
SampleUpdateStatus resolveFailureStatus(String? message) {
  final code = parseInstallErrorCode(message);
  if (code == _errorInstallNotAllowed ||
      code == _errorPlayStoreNotFound ||
      code == _errorAppNotOwned) {
    return const UpdateNotFromPlayStore();
  }
  return UpdateCheckFailed(code);
}

/// Owns the sample's update state and the one call that produces it.
///
/// Trigger, per the shared contract: once at start-up, once whenever the tester
/// asks, and once when the update flow hands control back — a cancelled update
/// must leave the card offering it again. Deliberately NOT wired to
/// `AppLifecycleState.resumed`: unlike Android's `ON_START`, `resumed` also
/// fires after every dialog, permission sheet and app-switcher glance, so
/// binding to it would re-check several times per foregrounding for no new
/// information.
class SampleUpdateChecker extends ChangeNotifier {
  /// [isSupported] defaults to "this is Android" and is injectable only so a
  /// test can exercise the unsupported branch without a platform override.
  SampleUpdateChecker({bool? isSupported})
    : isSupported = isSupported ?? (!kIsWeb && Platform.isAndroid);

  final bool isSupported;

  SampleUpdateStatus _status = const UpdateUnknown();
  SampleUpdateStatus get status =>
      isSupported ? _status : const UpdateUnsupported();

  /// The versionCode the tester was last told about, so the same build is not
  /// re-announced on every check.
  int? _lastNotifiedVersionCode;

  bool _inFlight = false;

  Future<void> check() async {
    if (!isSupported || _inFlight) return;
    _inFlight = true;
    _status = const UpdateChecking();
    notifyListeners();
    try {
      final info = await InAppUpdate.checkForUpdate();
      _status = resolveUpdateStatus(
        availability: info.updateAvailability,
        immediateAllowed: info.immediateUpdateAllowed,
        availableVersionCode: info.availableVersionCode,
      );
    } on PlatformException catch (e) {
      _status = resolveFailureStatus(e.message);
    } catch (e) {
      // A MissingPluginException on a platform that slipped past [isSupported],
      // or anything else: never let the check take the app down with it.
      demoLog.apiCall('InAppUpdate.checkForUpdate', {'error': '$e'});
      _status = const UpdateCheckFailed(null);
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  /// Returns the versionCode to announce once, or null if there is nothing new
  /// to say. Records it, so a tester who dismisses the announcement is not
  /// shown it again for the same build.
  int? acknowledgeNewVersion() {
    final status = _status;
    if (status is! UpdateAvailableStatus) return null;
    final version = status.availableVersionCode;
    if (version == null || version == _lastNotifiedVersionCode) return null;
    _lastNotifiedVersionCode = version;
    return version;
  }

  /// Starts Play's flow. Only ever called from a tap — nothing in this class
  /// launches it on its own, which is the rule the shared contract actually
  /// binds. Re-checks afterwards rather than assuming what Play left behind.
  Future<void> startUpdate() async {
    if (!isSupported) return;
    try {
      await InAppUpdate.performImmediateUpdate();
    } on PlatformException catch (e) {
      demoLog.apiCall('InAppUpdate.performImmediateUpdate', {'error': e.code});
    }
    await check();
  }
}
