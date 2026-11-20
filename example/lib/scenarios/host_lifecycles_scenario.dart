import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../design.dart';
import '../sample_fixtures.dart';
import '../widgets/scenario_scaffold.dart';

enum _HostLifecycleMode { recreate, keepMounted }

class HostLifecyclesScenario extends StatefulWidget {
  const HostLifecyclesScenario({super.key});

  @override
  State<HostLifecyclesScenario> createState() => _HostLifecyclesScenarioState();
}

class _HostLifecyclesScenarioState extends State<HostLifecyclesScenario> {
  final _post = TextEditingController(text: sampleFixtures.postText);
  final _navigator = GlobalKey<NavigatorState>();
  final _observer = RouteObserver<PageRoute<dynamic>>();
  bool _running = false;
  _HostLifecycleMode _mode = _HostLifecycleMode.recreate;
  int _returns = 0;
  String _result = 'Not run yet';

  @override
  void dispose() {
    _post.dispose();
    super.dispose();
  }

  void _start(_HostLifecycleMode mode) {
    if (!AppScope.of(context).initialized || _post.text.trim().isEmpty) {
      setState(
        () => _result = 'Initialize a demo community and enter a Post ID.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _returns = 0;
      _result = 'Running…';
      _running = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Material(
      child: SafeArea(
        child: Column(
          children: [
            // Exactly one result node, outside the navigator and its routes.
            Semantics(
              identifier: 'hostLifecycles-result',
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_result),
              ),
            ),
            Expanded(
              child: _running
                  // Contain each route's BlockSemantics so its modal barrier
                  // cannot hide the result sibling from accessibility tools.
                  ? Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: NavigatorPopHandler<void>(
                        onPopWithResult: (_) => _navigator.currentState!.pop(),
                        child: Navigator(
                          key: _navigator,
                          observers: [_observer],
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => _CommunityRoute(
                              observer: _observer,
                              mode: _mode,
                              postId: _post.text.trim(),
                              onCover: () =>
                                  setState(() => _result = 'Running…'),
                              onReturn: () => setState(() {
                                _returns++;
                                _result =
                                    'Returned $_returns time(s)… '
                                    'Verify the post and comments still render.';
                              }),
                              onBack: () => setState(() => _running = false),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ScenarioScaffold(
                      title: 'Host lifecycles',
                      api: 'host: PlatformView retention / recreation',
                      description:
                          'Push a host screen over the community, then pop it. '
                          'Repeat at least three times and check the post and '
                          'comments after every return.',
                      note:
                          'Keep mounted retains the same PlatformView under '
                          'the host route. Remove and recreate disposes it '
                          'once covered, then creates a new PlatformView on '
                          'return, resetting navigation to the selected post.',
                      resultTestId: 'hostLifecycles-result',
                      hidesResult: true,
                      inputFields: Semantics(
                        identifier: 'hostLifecycles-post-edit',
                        child: TextField(
                          controller: _post,
                          decoration: const InputDecoration(
                            labelText: 'Post ID',
                          ),
                        ),
                      ),
                      presets: [
                        ScenarioPreset(
                          testId: 'qa-preset-hostLifecycles-3',
                          label: 'Preset 3 · Remove and recreate PlatformView',
                          onRun: (_) async =>
                              _start(_HostLifecycleMode.recreate),
                        ),
                        ScenarioPreset(
                          testId: 'qa-preset-hostLifecycles-6',
                          label: 'Preset 6 · Keep mounted while covered',
                          onRun: (_) async =>
                              _start(_HostLifecycleMode.keepMounted),
                        ),
                      ],
                      liveState: app.initialized
                          ? null
                          : const Text('Initialize a demo community first.'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityRoute extends StatefulWidget {
  const _CommunityRoute({
    required this.observer,
    required this.mode,
    required this.postId,
    required this.onCover,
    required this.onReturn,
    required this.onBack,
  });

  final RouteObserver<PageRoute<dynamic>> observer;
  final _HostLifecycleMode mode;
  final String postId;
  final VoidCallback onCover;
  final VoidCallback onReturn;
  final VoidCallback onBack;

  @override
  State<_CommunityRoute> createState() => _CommunityRouteState();
}

class _CommunityRouteState extends State<_CommunityRoute> with RouteAware {
  PageRoute<dynamic>? _route;
  bool _showCommunity = true;
  bool _awaitingReturn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)! as PageRoute<dynamic>;
    if (_route == route) return;
    widget.observer.unsubscribe(this);
    _route?.secondaryAnimation?.removeStatusListener(_transitionChanged);
    _route = route;
    widget.observer.subscribe(this, route);
    route.secondaryAnimation?.addStatusListener(_transitionChanged);
  }

  @override
  void didPushNext() {
    _awaitingReturn = true;
  }

  @override
  void didPopNext() {
    setState(() => _showCommunity = true);
    _transitionChanged(_route!.secondaryAnimation!.status);
  }

  void _transitionChanged(AnimationStatus status) {
    if (_awaitingReturn &&
        status == AnimationStatus.completed &&
        widget.mode == _HostLifecycleMode.recreate) {
      // Keep painting through the push; dispose only under the opaque cover.
      setState(() => _showCommunity = false);
    }
    if (!_awaitingReturn ||
        !_showCommunity ||
        status != AnimationStatus.dismissed) {
      return;
    }
    _awaitingReturn = false;
    // Signal from the surviving community route, after its return transition
    // and rebuilt frame. Never listen for an event on the removed cover route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _route!.isCurrent) widget.onReturn();
    });
  }

  @override
  void dispose() {
    widget.observer.unsubscribe(this);
    _route?.secondaryAnimation?.removeStatusListener(_transitionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SampleScaffold(
      appBar: AppBar(
        title: const Text('Community'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Wrap(
            children: [
              Semantics(
                identifier: 'hostLifecycles-back-button',
                child: TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Back to scenario'),
                ),
              ),
              Semantics(
                identifier: 'hostLifecycles-push-button',
                child: FilledButton(
                  onPressed: () {
                    widget.onCover();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => SampleScaffold(
                          appBar: AppBar(title: const Text('Host screen')),
                          body: Center(
                            child: Semantics(
                              identifier: 'hostLifecycles-pop-button',
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Pop host screen'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Push host screen'),
                ),
              ),
            ],
          ),
          Expanded(
            child: _showCommunity
                ? OctopusHomeScreen(
                    theme: app.effectiveOctopusTheme(),
                    onBack: widget.onBack,
                    initialScreen: OctopusInitialScreen.post(
                      PostScreenInfo(postId: widget.postId),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
