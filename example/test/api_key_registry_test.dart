import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/config/api_key_registry.dart';

/// Unit tests for the named-key wire parser that backs the Config-screen
/// picker. The real values arrive via `--dart-define=OCTOPUS_NAMED_API_KEYS`
/// from your build-time `--dart-define` injection; here we exercise
/// [parseNamedApiKeys] directly with synthetic wire strings so the parser is
/// covered without a build-time define.
void main() {
  group('parseNamedApiKeys', () {
    test('empty / whitespace-only input yields no keys', () {
      expect(parseNamedApiKeys(''), isEmpty);
      expect(parseNamedApiKeys('   '), isEmpty);
      expect(parseNamedApiKeys(';;'), isEmpty);
    });

    test('parses a single id~label~key entry', () {
      final keys = parseNamedApiKeys('slotA~Human label A~AbC123');
      expect(keys, hasLength(1));
      expect(keys.single.id, 'slotA');
      expect(keys.single.label, 'Human label A');
      expect(keys.single.key, 'AbC123');
    });

    test('parses multiple entries in order', () {
      final keys = parseNamedApiKeys(
        'a~Label A~key-a;b~Label B~key_b;c~Label C~keyC',
      );
      expect(keys.map((k) => k.id), ['a', 'b', 'c']);
      expect(keys.map((k) => k.label), ['Label A', 'Label B', 'Label C']);
      expect(keys.map((k) => k.key), ['key-a', 'key_b', 'keyC']);
    });

    test('preserves middots and spaces inside labels', () {
      final keys = parseNamedApiKeys('id~Alpha · beta gamma · delta~kkkk');
      expect(keys.single.label, 'Alpha · beta gamma · delta');
    });

    test('drops trailing / empty / whitespace entries', () {
      final keys = parseNamedApiKeys('a~A~ka; ;b~B~kb;');
      expect(keys.map((k) => k.id), ['a', 'b']);
    });

    test('trims surrounding whitespace on each field', () {
      final keys = parseNamedApiKeys('  id  ~  My label  ~  thekey  ');
      expect(keys.single.id, 'id');
      expect(keys.single.label, 'My label');
      expect(keys.single.key, 'thekey');
    });

    test('drops malformed entries (wrong field count)', () {
      // 2 fields (missing key) and 4 fields are both rejected; the valid one
      // between them still parses.
      final keys = parseNamedApiKeys(
        'bad~onlytwo;ok~Good~key;too~many~fields~here',
      );
      expect(keys, hasLength(1));
      expect(keys.single.id, 'ok');
    });

    test('drops entries with an empty id or empty key', () {
      expect(parseNamedApiKeys('~Label~key'), isEmpty);
      expect(parseNamedApiKeys('id~Label~'), isEmpty);
    });

    test('allows an empty label (kept as empty string)', () {
      final keys = parseNamedApiKeys('id~~thekey');
      expect(keys.single.label, '');
      expect(keys.single.key, 'thekey');
    });
  });

  group('injectedApiKeys', () {
    test('is empty on a keyless build (no define) and unmodifiable', () {
      // `flutter test` runs with no --dart-define, so the build is keyless and
      // the Config screen must fall back to the Demo / Custom selector.
      expect(injectedApiKeys, isEmpty);
      expect(
        () => injectedApiKeys.add(
          const InjectedApiKey(id: 'x', label: 'x', key: 'x'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
