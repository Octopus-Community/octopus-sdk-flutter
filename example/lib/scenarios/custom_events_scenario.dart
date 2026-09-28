import 'package:flutter/material.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/scenario_customize.dart';
import '../widgets/scenario_scaffold.dart';

/// The `customEvents` presets' values, in one place.
///
/// Iso the Android sample's `ExplorerViewModel` constants. The property is a single
/// key/value pair rather than the map the Flutter sample carried before the port: the
/// Customize editor offers one property field, and a preset whose value cannot be typed
/// back into the editor is a preset the Custom/Preset chip can never match again.
const String defaultCustomEventName = 'sample_test_event';
const String defaultCustomEventProperty = 'sample_value';
const String defaultCustomEventPropertyKey = 'sample_prop';

/// Custom Events scenario — `trackCustomEvent`.
class CustomEventsScenario extends StatefulWidget {
  const CustomEventsScenario({super.key});

  @override
  State<CustomEventsScenario> createState() => _CustomEventsScenarioState();
}

class _CustomEventsScenarioState extends State<CustomEventsScenario> {
  final ScenarioCustomizeHolders _holders = ScenarioCustomizeHolders();

  String _nameInput = defaultCustomEventName;
  String _propertyInput = '';

  /// The one call both the presets and Customize's Run go through.
  Future<void> _track(
    ScenarioResultSink setResult, {
    required String name,
    required String property,
  }) async {
    final eventName = name.trim().isEmpty
        ? defaultCustomEventName
        : name.trim();
    final properties = property.isEmpty
        ? const <String, String>{}
        : {defaultCustomEventPropertyKey: property};
    try {
      demoLog.apiCall('trackCustomEvent', {
        'name': eventName,
        if (properties.isNotEmpty) 'properties': properties,
      });
      await AppScope.of(
        context,
      ).octopus.trackCustomEvent(eventName, properties);
      setResult(
        properties.isEmpty
            ? 'Tracked "$eventName" with no properties.'
            : 'Tracked "$eventName" with properties $properties.',
      );
    } catch (e) {
      setResult('trackCustomEvent failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScenarioScaffold(
      title: 'Custom Events',
      api: 'trackCustomEvent',
      description:
          'Track an analytics custom event, with and without properties.',
      youWillSee:
          'A line in the debug console for each call — the SDK sends the event '
          'and returns nothing, so the console is the only proof it went out.',
      resultTestId: 'customEvents-result',
      catalogParams: const {
        'event': 'String — name = "$defaultCustomEventName"',
        'event.properties':
            'Map<String, String> — empty, or '
            '$defaultCustomEventPropertyKey = "$defaultCustomEventProperty"',
      },
      customize: ScenarioCustomize(
        holders: _holders,
        // Rebuilt each build so the fields read this State's current values.
        params: [
          ScenarioEditableParam(
            name: 'event.name',
            type: 'String',
            help: defaultCustomEventName,
            presetValues: const [
              defaultCustomEventName,
              defaultCustomEventName,
            ],
            value: _nameInput,
            onValueChange: (value) => setState(() => _nameInput = value),
          ),
          ScenarioEditableParam(
            name: 'event.properties["$defaultCustomEventPropertyKey"]',
            type: 'String?',
            help: 'blank — send no properties at all',
            presetValues: const ['', defaultCustomEventProperty],
            value: _propertyInput,
            onValueChange: (value) => setState(() => _propertyInput = value),
          ),
        ],
        // The catalog names, not the editable ones. Deliberately kept as Android
        // spells them (INFO note on Android #487): these say which read-only rows
        // the editor supersedes, so they have to match the rows above — the Dart
        // API takes `(name, properties)` positionally, but the sample documents
        // the same two values under the same two names on both platforms.
        replacesCatalogParams: const {'event', 'event.properties'},
        customRun: (setResult) =>
            _track(setResult, name: _nameInput, property: _propertyInput),
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-customEvents-1',
          label: 'Preset 1 · Track sample event (no props)',
          onRun: (setResult) =>
              _track(setResult, name: defaultCustomEventName, property: ''),
        ),
        ScenarioPreset(
          testId: 'qa-preset-customEvents-2',
          label: 'Preset 2 · Track sample event (with props)',
          onRun: (setResult) => _track(
            setResult,
            name: defaultCustomEventName,
            property: defaultCustomEventProperty,
          ),
        ),
      ],
    );
  }
}
