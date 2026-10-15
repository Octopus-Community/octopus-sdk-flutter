import 'package:flutter/material.dart';
import '../design.dart';

const sdkLanguages = <(String, String)>[
  ('', 'Follow system'),
  ('en', 'English'),
  ('fr', 'French'),
  ('de', 'German'),
  ('it', 'Italian'),
  ('pl', 'Polish'),
  ('pt', 'Portuguese'),
  ('es', 'Spanish'),
  ('sv', 'Swedish'),
  ('tr', 'Turkish'),
];

String sdkLanguageLabel(String tag) => sdkLanguages
    .firstWhere((item) => item.$1 == tag, orElse: () => (tag, tag))
    .$2;

/// Whole-row radios wrap their labels and grow with the system text size.
class SettingsChoices<T> extends StatelessWidget {
  const SettingsChoices({
    super.key,
    required this.selected,
    required this.options,
    required this.onChanged,
    required this.identifier,
    this.disabledOptions = const {},
    this.segmented = false,
  });

  final bool segmented;
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String identifier;
  final Set<T> disabledOptions;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    child: segmented
        ? SampleSegmentedChoice<T>(
            options: options,
            selected: selected,
            onChanged: onChanged,
            disabledOptions: disabledOptions,
          )
        : RadioGroup<T>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) onChanged?.call(value);
            },
            child: Column(
              children: [
                for (final (value, label) in options)
                  RadioListTile<T>(
                    value: value,
                    title: Text(label),
                    enabled:
                        onChanged != null && !disabledOptions.contains(value),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
  );
}
