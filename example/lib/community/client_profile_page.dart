import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';

/// A **host-app** profile page enriched with the member's Octopus community
/// stats — the point of the Unified Profile read API.
///
/// This is the use case the raw API presets in the Community Data scenario only
/// hint at: instead of sending the user into the SDK's native profile screen,
/// the host renders its own page and pulls the Octopus numbers into it with
/// [OctopusSDK.fetchCommunityData].
///
/// Mirrors the native Android sample's `ClientProfileScreen`, including **how
/// you get here**: `community_screen.dart` wires the SDK's
/// `onNavigateToProfile` callback (`OctopusHomeScreen.onNavigateToProfile`),
/// so tapping any profile inside the embedded UI pushes this very page — the
/// same activation switch on every platform since 1.13.0. That wiring is
/// conditional on the demo's own Settings toggle (`app.unifiedProfileWired`)
/// so the sample can show both behaviours side by side; a real host would
/// simply always pass the callback (or never).
///
/// The Community Data scenario also pushes this page directly (Preset 6 ·
/// "Open the host-rendered profile page"), so it stays reachable with the
/// toggle off — the page itself is plain host code and does not care which of
/// the two routes brought you here.
class ClientProfilePage extends StatefulWidget {
  /// The member's id in **the host's** system — what a real host app would
  /// already have on its profile route.
  final String clientUserId;

  const ClientProfilePage({super.key, required this.clientUserId});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  OctopusCommunityData? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = AppScope.of(context);
    try {
      demoLog.apiCall('fetchCommunityData', {
        'clientUserId': widget.clientUserId,
      });
      final data = await app.octopus.fetchCommunityData(
        clientUserId: widget.clientUserId,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client profile (host app)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The host's own profile header — nothing here comes from the SDK.
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.person,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.clientUserId,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'clientUserId — the host app\'s own id',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Octopus community data — fetchCommunityData(clientUserId:)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _body(theme),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Semantics(
        identifier: 'clientProfile-error',
        child: Text(
          'Fetch failed: $_error',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) {
      return Semantics(
        identifier: 'clientProfile-unknown',
        child: Text(
          'No Octopus profile for this clientUserId. Either the member has '
          'never used the community, or the community is not configured to '
          'expose client user ids.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Semantics(
      identifier: 'clientProfile-data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(theme, 'profileId', data.profileId),
          _row(theme, 'messageCount', data.messageCount?.toString() ?? '—'),
          _row(
            theme,
            'gamification level',
            data.gamification?.level.toString() ?? '— (gamification off)',
          ),
          _row(
            theme,
            'gamification score',
            data.gamification?.score?.toString() ??
                '— (never exposed to consumers)',
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    ),
  );
}
