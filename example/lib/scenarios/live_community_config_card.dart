import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../design.dart';

String maskScenarioApiKey(String? key) =>
    key == null || key.trim().isEmpty ? '—' : '••••';

List<(String, String)> liveCommunityConfigRows(
  OctopusDebugCommunityConfig? config,
  String? apiKey,
) {
  String flag(bool? value) => value == null ? '—' : (value ? '✓ on' : '✗ off');
  return [
    ('API key', maskScenarioApiKey(apiKey)),
    ('Unified Profile (exposeClientUserId)', flag(config?.exposeClientUserId)),
    (
      'Terms acceptance',
      switch (config?.termsAcceptanceMode) {
        TermsAcceptanceMode.implicit => 'implicit',
        TermsAcceptanceMode.explicitMultiCheckbox =>
          'explicit · multi checkbox',
        TermsAcceptanceMode.explicitSingleCheckbox =>
          'explicit · single checkbox',
        null => '—',
      },
    ),
    ('Force login (strong actions)', flag(config?.forceLoginOnStrongActions)),
    ('Display account age', flag(config?.displayAccountAge)),
    ('Force nickname choice', flag(config?.forceNicknameChoice)),
    (
      'Consent texts',
      config == null ? '—' : config.consentTexts?.toString() ?? 'SDK wordings',
    ),
  ];
}

/// Poll only while Scenarios is visible. Late responses belong to the session
/// that requested them, never to a newly selected community.
class LiveCommunityConfigCard extends StatefulWidget {
  const LiveCommunityConfigCard({super.key, required this.active});
  final bool active;

  @override
  State<LiveCommunityConfigCard> createState() =>
      _LiveCommunityConfigCardState();
}

class _LiveCommunityConfigCardState extends State<LiveCommunityConfigCard> {
  Timer? _timer;
  AppState? _app;
  int? _session;
  bool? _ready;
  int _generation = 0;
  OctopusDebugCommunityConfig? _config;
  bool _unsupported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_app != app ||
        _session != app.communitySession ||
        _ready != app.initialized) {
      _app = app;
      _session = app.communitySession;
      _ready = app.initialized;
      _config = null;
      _unsupported = false;
      _restart();
    } else if (app.initialized && _timer == null) {
      _restart();
    }
  }

  @override
  void didUpdateWidget(LiveCommunityConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final generation = ++_generation;
    if (!widget.active || !(_app?.initialized ?? false)) return;
    _timer = Timer(Duration.zero, () => _refresh(generation));
  }

  Future<void> _refresh(int generation) async {
    final app = _app!;
    if (!mounted || generation != _generation || !widget.active) return;
    // A presentation or detail covers this retained tab.
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      try {
        final value = await app.octopus.debugGetCommunityConfig();
        if (!mounted ||
            generation != _generation ||
            app.communitySession != _session ||
            !app.initialized) {
          return;
        }
        setState(() {
          _config = value;
          _unsupported = false;
        });
      } catch (_) {
        if (!mounted ||
            generation != _generation ||
            app.communitySession != _session) {
          return;
        }
        setState(() {
          _config = null;
          _unsupported = true;
        });
      }
    }
    if (mounted && generation == _generation && widget.active) {
      _timer = Timer(const Duration(seconds: 2), () => _refresh(generation));
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'live-community-config',
    container: true,
    child: SamplePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Live community config',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'What the SDK sees for the current community (backend config + any local override).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          for (final row in liveCommunityConfigRows(
            _config,
            (_app?.initialized ?? false) ? _app?.activeApiKey : null,
          )) ...[
            SampleKeyValue(row.$1, row.$2, caption: true),
            const SizedBox(height: 4),
          ],
          if (_config == null)
            SampleKeyValue(
              'Status',
              (_app?.stopped ?? false)
                  ? 'SDK stopped — use Restart the SDK'
                  : !(_app?.initialized ?? false)
                  ? 'SDK not started — configure it in Settings'
                  : _unsupported
                  ? 'Config unavailable'
                  : 'loading…',
              caption: true,
            ),
          const SizedBox(height: 4),
          Text(
            'Post, Comment, Reply, Profile lock, Gamification and Powered by Octopus are not exposed by the Flutter config API.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
