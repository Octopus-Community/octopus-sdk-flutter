// Predefined SSO user ids surfaced by the Config-screen User ID picker.
//
// Hardcoded on purpose — these are stable test identities, not secrets, and
// they ship in the public OSS mirror. Each value is the literal `sub` the
// host-side SSO signer (`ClientUserTokenSigner`) embeds in the user JWT and
// hands to `connectUser(tokenProvider:)` (or a trivial provider returning the
// pre-baked token when no SSO secret was injected at build time).
//
// The build-time `--dart-define=OCTOPUS_USER_ID=<value>` still acts as the
// initial seed for fresh installs / CI, but at runtime the Config screen
// lets QA pick a different identity (or paste a custom one) so two instances
// of the sample running side-by-side can hold distinct user JWTs — required
// for end-to-end push-notification testing between, e.g., an Android emulator
// and an iOS simulator.
//
// Adding a new id: just append to [defaultPredefinedUserIds]. The Config
// screen rebuilds the picker from this list + the build-time seed (deduped).

import '../octopus_demo_config.dart';

/// Hardcoded shortlist of user ids the Config-screen quick-pick chips show
/// in addition to whatever was passed via `--dart-define=OCTOPUS_USER_ID`.
/// Kept tight on purpose (2–3 entries): two QA identities for cross-platform
/// push end-to-end (one Android, one iOS), and the default seed slot. Anything
/// beyond that is one keystroke away — the text field accepts any value.
const List<String> defaultPredefinedUserIds = [
  'flutter-sample-user',
  'qa-tester-ios',
  'qa-tester-android',
];

/// The final picker list: the build-time seed first (so the default is the
/// id the launcher signed the bundled `OCTOPUS_USER_TOKEN` against), then the
/// hardcoded predefined ids, deduped while preserving insertion order. The
/// `Custom…` fallback is rendered by the Config screen itself and is not part
/// of this list.
final List<String> pickerUserIds = List.unmodifiable(
  _buildPickerUserIds(octopusUserId, defaultPredefinedUserIds),
);

/// Pure helper exposed for tests: build the picker list from a seed and a
/// predefined-id list. Trims each value and drops empties; deduplicates while
/// preserving first-seen order (the seed is first when non-empty).
List<String> buildPickerUserIds(String seed, Iterable<String> predefined) =>
    _buildPickerUserIds(seed, predefined);

List<String> _buildPickerUserIds(String seed, Iterable<String> predefined) {
  final out = <String>[];
  final seen = <String>{};
  void addIfNew(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (seen.add(trimmed)) out.add(trimmed);
  }

  addIfNew(seed);
  for (final id in predefined) {
    addIfNew(id);
  }
  return out;
}
