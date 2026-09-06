import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Which container the community is opened in for a given run.
enum _Presentation {
  /// The sample builds the route itself and hosts [OctopusHomeScreen] in it —
  /// the widget-level API, where `onBack` is a *delegation*: nothing dismisses
  /// the route unless the host pops it.
  embedded,

  /// [OctopusSDK.showOctopusHomeScreen] builds and owns the route — the
  /// helper-level API, where `onBack` is a *notification*: the helper pops its
  /// own route either way.
  fullscreen,
}

/// One leading-icon configuration a preset runs.
class _LeadingConfig {
  /// `showBackButton` as passed to the embedded [OctopusHomeScreen]. The
  /// fullscreen helper hard-codes `true` and does not expose it — see
  /// [_LeadingConfig.fullscreenSupported].
  final bool showBackButton;
  final OctopusNavBarLeadingAction? leadingAction;

  /// What the tester should see, so the Result panel states the expectation
  /// before the screen opens rather than after the fact.
  final String expectation;

  const _LeadingConfig({
    required this.showBackButton,
    required this.leadingAction,
    required this.expectation,
  });

  /// Whether this configuration is reachable through
  /// [OctopusSDK.showOctopusHomeScreen], which always requests
  /// `showBackButton: true`. Only the "no leading icon at all" control is not.
  bool get fullscreenSupported => showBackButton || leadingAction != null;

  String get summary =>
      'showBackButton: $showBackButton · '
      'navBarLeadingAction: ${leadingAction?.name ?? 'null'}';
}

/// Embedded Back Button — the SDK's own leading top-app-bar icon, and the
/// callback its tap fires on the SDK's **root** screen.
///
/// This is the one piece of the presentation surface a host cannot build
/// itself: the icon is painted by the native SDK inside the SDK's own
/// navigation stack, and the host only learns a tap happened through
/// `onBack`. The three presentation scenarios (Fullscreen, Modal, Sheet)
/// assert *where* the community is put; this one asserts *how the host gets
/// out of it*.
///
/// **Two containers, one set of presets.** The Presentation selector runs the
/// same five leading-icon configurations against either API, which is what
/// makes the two `onBack` contracts comparable side by side:
///
/// - **Embedded view** — the sample pushes its own route around
///   [OctopusHomeScreen]. `onBack` is a **delegation**: the widget dismisses
///   nothing, so the route stays up unless this scenario pops it.
/// - **Fullscreen helper** — [OctopusSDK.showOctopusHomeScreen] owns the route
///   it pushed. `onBack` is a **notification**: the route pops itself whether
///   or not a callback was passed, and the callback runs *before* the pop.
///   Same notify-then-close contract as the React Native wrapper's
///   `openUI({ onBackRequested })`, for the same reason — a helper-owned
///   container must never let a host strand the user in it.
///
/// **Which taps reach the counter.** Only the SDK's **root** leading icon.
/// Deeper SDK screens (post detail, group detail…) paint their own chevron and
/// pop inside the native stack, so the counter stays put — open a post first
/// and tap its back arrow to see that. No OS-level gesture reaches `onBack`
/// either, and what it does instead depends on where the user is: while the
/// SDK is on its **root** screen, Android system / predictive back pops the
/// Flutter route directly; **deeper inside the SDK** the native navigation
/// stack consumes it and navigates up, leaving the Flutter route in place. On
/// iOS both containers here are plain `MaterialPageRoute`s, so the
/// swipe-from-left-edge gesture they enable is a Flutter-level pop that emits
/// no `backRequested`, while the native SDK runs its own navigation stack for
/// its internal screens.
///
/// **Preset 5 is fullscreen-N/A on purpose.** "No leading icon" is not
/// expressible through the helper, which always requests
/// `showBackButton: true`; the preset says so instead of silently opening a
/// different configuration.
class EmbeddedBackScenario extends StatefulWidget {
  const EmbeddedBackScenario({super.key});

  @override
  State<EmbeddedBackScenario> createState() => _EmbeddedBackScenarioState();
}

class _EmbeddedBackScenarioState extends State<EmbeddedBackScenario> {
  _Presentation _presentation = _Presentation.fullscreen;

  /// How many times `onBack` has fired since this screen was opened, and from
  /// which container the last one came. Shown live above the presets AND
  /// written into the Result panel, because the tester is looking at the SDK
  /// — not at this screen — at the moment the callback fires.
  int _backCount = 0;
  _Presentation? _lastSource;

  static const _configs = <String, _LeadingConfig>{
    'qa-preset-embeddedBack-1': _LeadingConfig(
      showBackButton: true,
      leadingAction: null,
      expectation: 'Expect a back arrow (‹) at top-left of the SDK nav bar.',
    ),
    'qa-preset-embeddedBack-2': _LeadingConfig(
      showBackButton: false,
      leadingAction: OctopusNavBarLeadingAction.back,
      expectation:
          'Expect a back arrow (‹) driven by navBarLeadingAction, not by '
          'showBackButton.',
    ),
    'qa-preset-embeddedBack-3': _LeadingConfig(
      showBackButton: false,
      leadingAction: OctopusNavBarLeadingAction.close,
      expectation: 'Expect a close (X) at top-left of the SDK nav bar.',
    ),
    'qa-preset-embeddedBack-4': _LeadingConfig(
      showBackButton: true,
      leadingAction: OctopusNavBarLeadingAction.close,
      expectation:
          'Both are set and they disagree: expect the close (X) to win, on '
          'both platforms.',
    ),
    'qa-preset-embeddedBack-5': _LeadingConfig(
      showBackButton: false,
      leadingAction: null,
      expectation:
          'Negative control: expect NO leading icon, and the counter to stay '
          'at its current value. Leave with the system back gesture.',
    ),
  };

  void _recordBack(ScenarioResultSink setResult, _Presentation source) {
    setState(() {
      _backCount++;
      _lastSource = source;
    });
    demoLog.apiCall('onBack', {
      'presentation': source.name,
      'count': _backCount,
    });
    setResult(
      'onBack fired ×$_backCount (${source.name}).\n'
      '${source == _Presentation.fullscreen ? 'The helper popped its own route after notifying.' : 'The scenario popped the route it owns.'}',
    );
  }

  Future<void> _run(ScenarioResultSink setResult, String testId) async {
    final config = _configs[testId]!;
    final presentation = _presentation;
    if (presentation == _Presentation.fullscreen &&
        !config.fullscreenSupported) {
      setResult(
        'Not applicable to the fullscreen helper.\n'
        'showOctopusHomeScreen always requests showBackButton: true, so "no '
        'leading icon" cannot be expressed through it. Switch Presentation to '
        '"Embedded view" to run this control.',
      );
      return;
    }

    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    final theme = app.effectiveOctopusTheme();

    try {
      if (presentation == _Presentation.fullscreen) {
        demoLog.apiCall('showOctopusHomeScreen', {
          'navBarLeadingAction': config.leadingAction?.name,
          'onBack': 'set',
        });
        setResult(
          'Fullscreen helper opened · ${config.summary}\n'
          '${config.expectation}\n'
          'Tapping it notifies onBack, then the helper pops its own route.',
        );
        unawaited(
          OctopusSDK().showOctopusHomeScreen(
            context,
            theme: theme,
            navBarTitle: 'Community',
            navBarLeadingAction: config.leadingAction,
            // Notification only — the helper owns the route and pops it on
            // its own. Nothing here dismisses anything.
            onBack: () => _recordBack(setResult, _Presentation.fullscreen),
            onNavigateToLogin: () => navigator.push(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            onModifyUser: (field) => navigator.push(
              MaterialPageRoute(
                builder: (_) => ProfileEditPage(fieldToEdit: field),
              ),
            ),
          ),
        );
        return;
      }

      demoLog.apiCall('Navigator.push<OctopusHomeScreen>', {
        'showBackButton': config.showBackButton,
        'navBarLeadingAction': config.leadingAction?.name,
      });
      setResult(
        'Embedded view opened · ${config.summary}\n'
        '${config.expectation}\n'
        'Tapping it calls onBack, which is what pops this route — the widget '
        'dismisses nothing by itself.',
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (routeContext) => Scaffold(
              body: SafeArea(
                bottom: false,
                child: OctopusHomeScreen(
                  theme: theme,
                  navBarTitle: 'Community',
                  showBackButton: config.showBackButton,
                  navBarLeadingAction: config.leadingAction,
                  // Delegation: the widget pops nothing, so this callback is
                  // the only way out of the route short of the system back
                  // gesture.
                  onBack: () {
                    _recordBack(setResult, _Presentation.embedded);
                    Navigator.of(routeContext).pop();
                  },
                  onNavigateToLogin: () => Navigator.of(
                    routeContext,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                  onModifyUser: (field) => Navigator.of(routeContext).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditPage(fieldToEdit: field),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      setResult('Embedded Back Button scenario failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScenarioScaffold(
      title: 'Embedded Back Button',
      api: 'navBarLeadingAction',
      description:
          "The SDK paints its own leading icon on its root screen and reports "
          'the tap through onBack. Pick the icon with showBackButton / '
          'navBarLeadingAction, and the container with the Presentation '
          'selector: the embedded widget delegates the dismissal to you, while '
          'showOctopusHomeScreen notifies you and pops its own route. The '
          'counter below only moves on the SDK ROOT screen — a deeper screen '
          "pops inside the SDK's own stack, and neither platform routes the OS "
          'back gesture through the callback.',
      resultTestId: 'embeddedBack-result',
      liveState: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No `Semantics(identifier:)` here on purpose: QA ids in this app
          // come from the shared QA scenario catalogue (kept outside this
          // repo), and the `embeddedBack` entry there owns only
          // `embeddedBack-result` and `qa-preset-embeddedBack-1..5`. Inventing
          // one locally would put the sample and the catalogue out of step.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Presentation>(
              segments: const [
                ButtonSegment(
                  value: _Presentation.embedded,
                  label: Text('Embedded view'),
                ),
                ButtonSegment(
                  value: _Presentation.fullscreen,
                  label: Text('Fullscreen helper'),
                ),
              ],
              selected: {_presentation},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _presentation = s.first),
            ),
          ),
          const SizedBox(height: 12),
          KeyValueCard(
            title: 'onBack',
            rows: [
              ('Fired', '×$_backCount'),
              ('Last source', _lastSource?.name ?? '—'),
              (
                'Container',
                _presentation == _Presentation.fullscreen
                    ? 'showOctopusHomeScreen (notify-then-close)'
                    : 'OctopusHomeScreen (host pops)',
              ),
            ],
          ),
        ],
      ),
      presets: [
        for (final entry in _presetLabels.entries)
          ScenarioPreset(
            testId: entry.key,
            label: entry.value,
            onRun: (setResult) => _run(setResult, entry.key),
          ),
      ],
    );
  }
}

/// Preset labels, verbatim from the shared scenario catalog.
const Map<String, String> _presetLabels = {
  'qa-preset-embeddedBack-1': 'Preset 1 · Back arrow (showBackButton)',
  'qa-preset-embeddedBack-2': "Preset 2 · Leading action 'back'",
  'qa-preset-embeddedBack-3': "Preset 3 · Leading action 'close'",
  'qa-preset-embeddedBack-4':
      'Preset 4 · Leading action wins over showBackButton',
  'qa-preset-embeddedBack-5': 'Preset 5 · No leading icon (negative control)',
};
