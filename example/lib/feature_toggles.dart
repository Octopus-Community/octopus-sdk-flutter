/// The sample's two feature toggles, and the sentences that explain them.
///
/// Ported iso from the Android sample (`data/model/FeatureToggle.kt`, PR #488/#489).
///
/// **A toggle lives in the header of its Scenarios section, and nowhere else.** That is
/// the one rule the shared design contract states twice, and it is the reason this file
/// carries the copy rather than each screen: Home, the scenario screens, Developer tools
/// and Debug info all *read* these two switches, and Config never carries them. A second
/// switch for the same thing is a tester flipping one and watching the other.
///
/// Each toggle owns both halves of its explanation — what happens when it is on, and what
/// happens when it is off — because "Force login: off" tells a tester nothing about what
/// the app will now do.
enum FeatureToggle {
  forceLogin(
    id: 'force-login',
    label: 'Force login',
    effectWhenOn: 'Visitors must sign in before they can read or post.',
    effectWhenOff: 'Visitors can browse the community before signing in.',
    testId: 'scenarios-toggle-force-login',
  ),
  pushRegistration(
    id: 'push-registration',
    label: 'Push registration',
    effectWhenOn:
        'New device tokens go to Octopus, so this device can be notified.',
    effectWhenOff:
        'Device tokens stay in the app; already-registered ones live until a reset.',
    testId: 'scenarios-toggle-push-registration',
  );

  const FeatureToggle({
    required this.id,
    required this.label,
    required this.effectWhenOn,
    required this.effectWhenOff,
    required this.testId,
  });

  /// Stable id — the catalog spelling, also what the persisted config stores.
  final String id;

  /// What the switch is called, everywhere it is named.
  final String label;

  final String effectWhenOn;
  final String effectWhenOff;

  /// QA selector for the switch in its Scenarios section header.
  final String testId;

  /// What the app does in this state — the half a tester actually needs.
  String effectLine(bool enabled) => enabled ? effectWhenOn : effectWhenOff;

  /// "Force login is on" — used where the toggle is reported, not operated.
  String stateLine(bool enabled) => '$label is ${enabled ? 'on' : 'off'}';

  /// The value plus where to change it, for the read-only read-outs.
  String readOnlyValueLine(bool enabled) =>
      '${enabled ? 'on' : 'off'} · set in Scenarios';
}

/// The state of both toggles, as one immutable value.
///
/// Defaults match Android: force-login **off** (a sample you cannot browse without signing
/// in is a sample nobody opens twice) and push-registration **on** (the state a tester
/// expects when a notification does not arrive).
class FeatureToggles {
  const FeatureToggles({this.forceLogin = false, this.pushRegistration = true});

  static const FeatureToggles defaults = FeatureToggles();

  final bool forceLogin;
  final bool pushRegistration;

  bool operator [](FeatureToggle toggle) => switch (toggle) {
    FeatureToggle.forceLogin => forceLogin,
    FeatureToggle.pushRegistration => pushRegistration,
  };

  FeatureToggles withToggle(FeatureToggle toggle, bool enabled) =>
      switch (toggle) {
        FeatureToggle.forceLogin => FeatureToggles(
          forceLogin: enabled,
          pushRegistration: pushRegistration,
        ),
        FeatureToggle.pushRegistration => FeatureToggles(
          forceLogin: forceLogin,
          pushRegistration: enabled,
        ),
      };

  /// "Force login on · Push registration off" — one line for Debug info, the feedback
  /// report and anywhere else that reports both without offering to change them.
  String get summaryLine => FeatureToggle.values
      .map((t) => '${t.label} ${this[t] ? 'on' : 'off'}')
      .join(' · ');

  Map<String, Object?> toJson() => {
    'forceLogin': forceLogin,
    'pushRegistration': pushRegistration,
  };

  static FeatureToggles fromJson(Map<String, Object?>? json) {
    if (json == null) return defaults;
    return FeatureToggles(
      forceLogin: json['forceLogin'] as bool? ?? defaults.forceLogin,
      pushRegistration:
          json['pushRegistration'] as bool? ?? defaults.pushRegistration,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeatureToggles &&
      other.forceLogin == forceLogin &&
      other.pushRegistration == pushRegistration;

  @override
  int get hashCode => Object.hash(forceLogin, pushRegistration);
}
