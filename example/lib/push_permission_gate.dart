/// Asks for the OS notification permission once per process, and only after the
/// SDK is initialised with push registration on.
///
/// Push setup runs at startup, before the Config screen's Start initialises the
/// SDK, so asking there showed the Android 13+ `POST_NOTIFICATIONS` prompt (and
/// the iOS authorization alert) over a cold start that had not reached the
/// community yet. The Android sample asks once `isSdkInitialized` is true and the
/// React Native one right after `initialize`; this is the same first moment. Unlike
/// Android, which asks again on each re-init while the permission is missing, this
/// asks once per process.
///
/// Push registration off means the app has decided Octopus should not learn this
/// device, so there is nothing to ask for yet. Turning it on later, with the SDK
/// already initialised, asks then. A switchCommunity re-init never asks twice.
class PushPermissionGate {
  PushPermissionGate(this._request);

  final Future<void> Function() _request;
  bool _requested = false;

  /// Whether the request has been fired in this process.
  bool get requested => _requested;

  /// Call on every signal that can open the gate: an init emission and the push
  /// registration toggle turning on.
  Future<void> onSignal({
    required bool initialised,
    required bool registrationEnabled,
  }) async {
    if (_requested || !initialised || !registrationEnabled) return;
    _requested = true;
    await _request();
  }
}
