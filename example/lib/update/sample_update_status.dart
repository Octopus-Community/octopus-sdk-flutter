/// Result of asking Play whether a newer sample build is available.
///
/// Mirrors `AppUpdateChecker.Status` in the Android sample deliberately: one
/// behaviour reached through three bindings, and the states are the part a QA
/// lane reads. Keep the two in step.
sealed class SampleUpdateStatus {
  const SampleUpdateStatus();
}

/// Not Android — the iOS build is distributed by TestFlight, which prompts for
/// a newer build in the OS before the app even runs. The card is absent, not
/// empty: a second in-app prompt would be a worse copy of a working one.
class UpdateUnsupported extends SampleUpdateStatus {
  const UpdateUnsupported();
}

/// No check has run yet.
class UpdateUnknown extends SampleUpdateStatus {
  const UpdateUnknown();
}

class UpdateChecking extends SampleUpdateStatus {
  const UpdateChecking();
}

class UpdateUpToDate extends SampleUpdateStatus {
  const UpdateUpToDate();
}

class UpdateAvailableStatus extends SampleUpdateStatus {
  const UpdateAvailableStatus(this.availableVersionCode);

  final int? availableVersionCode;
}

/// A newer build exists, but Play refuses the in-place flow for it. Rare, and
/// deliberately NOT reported as [UpdateUpToDate]: telling a tester their stale
/// build is current is the one answer this feature must never give — it is
/// worse than having no card at all, because it ends the investigation.
class UpdateNotInstallable extends SampleUpdateStatus {
  const UpdateNotInstallable();
}

/// Play does not own this install — a sideloaded APK, a `flutter run` build, an
/// emulator image with no Play Store. The single most common answer in this
/// sample's whole lifetime, and a normal outcome rather than a failure.
class UpdateNotFromPlayStore extends SampleUpdateStatus {
  const UpdateNotFromPlayStore();
}

/// A genuine transient failure. Retryable, and carries the Play error code when
/// one could be read, so a QA report can quote it instead of describing it.
class UpdateCheckFailed extends SampleUpdateStatus {
  const UpdateCheckFailed(this.errorCode);

  final int? errorCode;
}
