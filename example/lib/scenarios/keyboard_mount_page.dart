import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../design.dart';

/// Debug-only preset destination. The route is already open before the IME
/// appears; mounting the SDK never pushes a route or removes the focused field.
class KeyboardMountPage extends StatefulWidget {
  const KeyboardMountPage({super.key});

  @override
  State<KeyboardMountPage> createState() => _KeyboardMountPageState();
}

class _KeyboardMountPageState extends State<KeyboardMountPage> {
  final _focus = FocusNode();
  bool _mounted = false;
  double? _keyboardAtMount;
  double? _safeAreaAtMount;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SampleScaffold(
      appBar: const SampleTopAppBar(title: 'Keyboard-up mount'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(SampleSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    autofocus: true,
                    focusNode: _focus,
                    decoration: const InputDecoration(labelText: 'Host field'),
                  ),
                  const SizedBox(height: SampleSpacing.space2),
                  // Keep the text field focused when the button is tapped.
                  ExcludeFocus(
                    child: OutlinedButton(
                      onPressed: !_mounted && _focus.hasFocus && keyboard > 0
                          ? () => setState(() {
                              _keyboardAtMount = keyboard;
                              _safeAreaAtMount = MediaQuery.paddingOf(
                                context,
                              ).bottom;
                              _mounted = true;
                            })
                          : null,
                      child: const Text('Mount community'),
                    ),
                  ),
                  Text(
                    _mounted
                        ? 'At mount: keyboard $_keyboardAtMount, safe area '
                              '$_safeAreaAtMount. Dismiss the keyboard and '
                              'inspect the community bottom inset.'
                        : 'Keep the keyboard open, then mount in this route. '
                              'The default SDK bottom inset is sampled at mount.',
                  ),
                ],
              ),
            ),
            if (_mounted)
              Expanded(
                child: OctopusHomeScreen(
                  onBack: () => Navigator.of(context).pop(),
                  navBarLeadingAction: OctopusNavBarLeadingAction.close,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
