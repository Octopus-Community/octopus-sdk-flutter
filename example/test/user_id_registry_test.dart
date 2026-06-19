import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/config/user_id_registry.dart';

/// Unit tests for the user-id picker registry. The real list shipped to the
/// Config screen is computed once from the build-time `OCTOPUS_USER_ID` seed
/// plus [defaultPredefinedUserIds]; here we exercise the pure helper directly
/// so dedup / trimming / order is locked without a build-time define.
void main() {
  group('buildPickerUserIds', () {
    test('puts the non-empty seed first, then the predefined ids', () {
      final out = buildPickerUserIds('seed-user', const ['a', 'b']);
      expect(out, ['seed-user', 'a', 'b']);
    });

    test('drops the seed when empty / whitespace-only', () {
      expect(buildPickerUserIds('', const ['a', 'b']), ['a', 'b']);
      expect(buildPickerUserIds('   ', const ['a', 'b']), ['a', 'b']);
    });

    test('deduplicates when the seed is already in the predefined list', () {
      final out = buildPickerUserIds('a', const ['a', 'b', 'a']);
      expect(out, ['a', 'b']);
    });

    test('trims each value', () {
      final out = buildPickerUserIds('  seed  ', const [' a ', '\tb\n']);
      expect(out, ['seed', 'a', 'b']);
    });

    test('returns an unmodifiable list at the module level', () {
      expect(pickerUserIds, isNotEmpty);
      expect(() => pickerUserIds.add('mutation'), throwsUnsupportedError);
    });

    test('default predefined list stays small (2–3 quick-picks) and covers '
        'the cross-platform push-QA identities', () {
      // The Config screen renders these as chips next to the always-visible
      // text field. Adding entries here adds chips, which makes the row wrap —
      // keep the list short on purpose. Free-text covers anything else.
      expect(defaultPredefinedUserIds.length, lessThanOrEqualTo(3));
      expect(defaultPredefinedUserIds, contains('flutter-sample-user'));
      expect(defaultPredefinedUserIds, contains('qa-tester-ios'));
      expect(defaultPredefinedUserIds, contains('qa-tester-android'));
    });
  });
}
