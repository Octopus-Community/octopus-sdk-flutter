import 'package:flutter/material.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/scenario_scaffold.dart';

/// Custom Events scenario — `trackCustomEvent`.
class CustomEventsScenario extends StatelessWidget {
  const CustomEventsScenario({super.key});

  static const String _eventName = 'sample_event';
  static const Map<String, String> _props = {
    'source': 'scenario',
    'tier': 'demo',
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Custom Events',
      description:
          'Track an analytics custom event, with and without properties.',
      resultTestId: 'customEvents-result',
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-customEvents-1',
          label: 'Preset 1 · Track sample event (no props)',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('trackCustomEvent', {'name': _eventName});
              await app.octopus.trackCustomEvent(_eventName);
              setResult('Tracked "$_eventName" with no properties.');
            } catch (e) {
              setResult('trackCustomEvent failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-customEvents-2',
          label: 'Preset 2 · Track sample event (with props)',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('trackCustomEvent', {
                'name': _eventName,
                'properties': _props,
              });
              await app.octopus.trackCustomEvent(_eventName, _props);
              setResult('Tracked "$_eventName" with properties $_props.');
            } catch (e) {
              setResult('trackCustomEvent failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
