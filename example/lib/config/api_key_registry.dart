// Named demo API keys shown as a single-choice picker on the Config screen.
//
// PUBLIC-SAFE and committed on purpose: this source declares only a generic
// parser and reads ONE compile-time define (`OCTOPUS_NAMED_API_KEYS`). It
// enumerates NO internal demo community, carries NO human label, and embeds
// NO key value — those live exclusively in the PRIVATE launcher
// `scripts/run-sample.sh` (which is `export-ignore`d from the public mirror),
// which fills the define from internal-tooling secrets at build time.
//
// A public / keyless build (cold clone, CI, the public OSS mirror) passes no
// define, so [injectedApiKeys] is empty and the Config screen falls back to
// the plain Demo / Custom selector. No secret, and no list of internal QA
// communities, ever ships in this repo's source.
//
// Wire format (one define, parsed at runtime — `String.fromEnvironment` is a
// const constructor, so the value can only be read, not split, at compile
// time): entries separated by `;`, fields by `~`, in `id~label~key` order:
//
//   slotA~Human label A~AbC123;slotB~Human label B~XyZ789
//
// Keys are base64url-shaped (`[A-Za-z0-9_-]`) and labels are plain text, so
// neither ever contains the `;`/`~` delimiters.

/// One named demo API key injected at build time.
class InjectedApiKey {
  /// Stable identifier (used for test ids and config display).
  final String id;

  /// Human-readable description of the community configuration.
  final String label;

  /// The key value handed to the SDK when this slot is picked.
  final String key;

  const InjectedApiKey({
    required this.id,
    required this.label,
    required this.key,
  });
}

/// Raw, opaque wire string for the named keys — empty on a keyless build.
const String _rawNamedKeys = String.fromEnvironment(
  'OCTOPUS_NAMED_API_KEYS',
  defaultValue: '',
);

/// The named keys present in this build, parsed from the injected define.
/// Empty on a public / keyless build → the Config screen shows the plain
/// Demo / Custom selector.
final List<InjectedApiKey> injectedApiKeys = List.unmodifiable(
  parseNamedApiKeys(_rawNamedKeys),
);

/// Parses the `OCTOPUS_NAMED_API_KEYS` wire string into typed slots.
///
/// Public (rather than private) so a unit test can exercise it without a real
/// build-time define. Defensive against the realities of a shell-built value:
/// tolerates empty input, surrounding whitespace, and trailing / empty
/// entries, and silently drops malformed entries (wrong field count or an
/// empty id / key) rather than throwing into the Config screen's build.
List<InjectedApiKey> parseNamedApiKeys(String raw) {
  final keys = <InjectedApiKey>[];
  for (final entry in raw.split(';')) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    final fields = trimmed.split('~');
    if (fields.length != 3) continue;
    final id = fields[0].trim();
    final label = fields[1].trim();
    final key = fields[2].trim();
    if (id.isEmpty || key.isEmpty) continue;
    keys.add(InjectedApiKey(id: id, label: label, key: key));
  }
  return keys;
}
