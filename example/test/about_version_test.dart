import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The bundled example intentionally reads the plugin's generated metadata.
// ignore: implementation_imports
import 'package:octopus_sdk_flutter/src/octopus_sdk_version.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/settings/about_screen.dart';

class _App extends AppState {
  @override
  String get sampleVersionLabel => '0.0.0+999';
}

void main() {
  testWidgets('About distinguishes the plugin version from the host build', (
    tester,
  ) async {
    final app = _App();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: AboutScreen()),
      ),
    );
    expect(find.text('SDK version'), findsOneWidget);
    expect(find.text(octopusSdkVersion), findsOneWidget);
    expect(find.text('0.0.0+999'), findsOneWidget);
    expect(find.text('Not exposed by the Flutter plugin'), findsNothing);
  });
}
