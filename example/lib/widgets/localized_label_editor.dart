import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../design.dart';

/// The state of a [LocalizedLabelEditor]: whether the label is given per
/// language, the default language, and one (language tag, text) row per
/// language.
///
/// Off, the label is the single text the scenario already has, auto-translated
/// by Octopus. On, it is an [OctopusLocalizedText.perLanguage] built from the
/// rows — the same switch as the native samples' bridge forms.
class LocalizedLabelController extends ChangeNotifier {
  /// Starts with per-language off, the default language `en`, and the given
  /// [initialRows] (language tag, text).
  LocalizedLabelController({
    List<(String, String)> initialRows = const [],
    String defaultLanguage = 'en',
  }) : defaultLanguage = TextEditingController(text: defaultLanguage) {
    for (final (language, text) in initialRows) {
      addRow(language: language, text: text);
    }
  }

  bool _perLanguage = false;

  /// The language of the text shown and translated when none matches the
  /// reader.
  final TextEditingController defaultLanguage;

  final List<(TextEditingController, TextEditingController)> _rows = [];

  /// Whether the label is given per language.
  bool get perLanguage => _perLanguage;

  set perLanguage(bool value) {
    if (value == _perLanguage) return;
    _perLanguage = value;
    notifyListeners();
  }

  /// The (language tag, text) rows, in order.
  List<(TextEditingController, TextEditingController)> get rows =>
      List.unmodifiable(_rows);

  /// Appends a row.
  void addRow({String language = '', String text = ''}) {
    _rows.add((
      TextEditingController(text: language),
      TextEditingController(text: text),
    ));
    notifyListeners();
  }

  /// Removes the row at [index].
  void removeRow(int index) {
    final (language, text) = _rows.removeAt(index);
    language.dispose();
    text.dispose();
    notifyListeners();
  }

  /// The label to send: [autoTranslatedText], auto-translated, when
  /// per-language is off; otherwise the per-language text of the rows.
  ///
  /// The rows are sent unchecked: the native SDK validates them when the label
  /// is used, and the call then throws an [OctopusLocalizedTextValidationError].
  /// Two rows with the very same tag keep the last one, as a `Map` does.
  OctopusLocalizedText build(String autoTranslatedText) {
    if (!_perLanguage) {
      return OctopusLocalizedText.autoTranslated(autoTranslatedText);
    }
    return OctopusLocalizedText.perLanguage({
      for (final (language, text) in _rows) language.text: text.text,
    }, defaultLanguage: defaultLanguage.text);
  }

  /// A one-line summary of [label] for the result panel and the debug log.
  static String describe(OctopusLocalizedText label) => switch (label) {
    OctopusAutoTranslatedText(:final text) => '"$text" (auto-translated)',
    OctopusPerLanguageText(:final texts, :final defaultLanguage) =>
      '${texts.entries.map((e) => '${e.key}="${e.value}"').join(', ')} '
          '(default $defaultLanguage)',
  };

  @override
  void dispose() {
    defaultLanguage.dispose();
    for (final (language, text) in _rows) {
      language.dispose();
      text.dispose();
    }
    super.dispose();
  }
}

/// The per-language switch and rows of a button label, under the scenario's
/// single label field.
class LocalizedLabelEditor extends StatelessWidget {
  const LocalizedLabelEditor({
    super.key,
    required this.controller,
    required this.testIdPrefix,
  });

  final LocalizedLabelController controller;

  /// Prefix of the semantics identifiers of the switch, fields and buttons.
  final String testIdPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: '$testIdPrefix-per-language',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Label per language'),
              subtitle: const Text(
                'Off: the label above, translated automatically. On: one '
                'label per language (BCP-47 tags such as en, pt-BR, '
                'zh-Hant-TW); other readers see a translation of the default '
                "language's label.",
              ),
              value: controller.perLanguage,
              onChanged: (value) => controller.perLanguage = value,
            ),
          ),
          if (controller.perLanguage) ...[
            const SizedBox(height: SampleSpacing.space2),
            Semantics(
              identifier: '$testIdPrefix-default-language',
              child: TextField(
                controller: controller.defaultLanguage,
                decoration: const InputDecoration(
                  labelText: 'Default language',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            for (final (index, (language, text)) in controller.rows.indexed)
              Padding(
                padding: const EdgeInsets.only(top: SampleSpacing.space2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Semantics(
                        identifier: '$testIdPrefix-language-$index',
                        child: TextField(
                          controller: language,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SampleSpacing.space2),
                    Expanded(
                      child: Semantics(
                        identifier: '$testIdPrefix-text-$index',
                        child: TextField(
                          controller: text,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove this language',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => controller.removeRow(index),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                identifier: '$testIdPrefix-add-language',
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add a language'),
                  onPressed: () => controller.addRow(),
                ),
              ),
            ),
            Text(
              'Nothing is checked here: empty the rows, blank a label, give '
              'one language twice (en-US and en_US) or name a default '
              'language without a row, and the native SDK refuses it when the '
              'label is used, reported here as the typed '
              'OctopusLocalizedTextValidationError.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
