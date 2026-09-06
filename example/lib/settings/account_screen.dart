import 'package:flutter/material.dart';

import '../app_state.dart';
import '../auth/connect_user_result.dart';
import '../design.dart';

/// The three entitlements the demo communities are configured around. The
/// value is what the forged JWT carries; the label is what the screen shows.
const List<(String, String)> _standardEntitlements = [
  ('customer:verified', 'Verified'),
  ('customer:moderator', 'Moderator'),
  ('customer:premium', 'Premium'),
];

/// Settings → Account: the identity the sample hands to `connectUser`, and the
/// three session actions that go with it.
///
/// Vocabulary note: this screen says **entitlements** throughout — never
/// "roles", "permissions" or "claims". That is the word the SDK, the backend
/// and the integration docs use, so it is the word a host developer will
/// search for.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  final _avatar = TextEditingController();
  final _customEntitlement = TextEditingController();
  bool _seeded = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The AppScope lookup is only legal from here on, not from initState.
    if (_seeded) return;
    _seeded = true;
    final app = AppScope.of(context);
    _nickname.text = app.testNickname;
    _bio.text = app.testBio;
    _avatar.text = app.testAvatarUrl;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _avatar.dispose();
    _customEntitlement.dispose();
    super.dispose();
  }

  Set<String> get _entitlements => AppScope.of(context).currentEntitlements;

  void _toggle(String value, bool on) {
    final app = AppScope.of(context);
    final next = Set<String>.from(app.currentEntitlements);
    if (on) {
      next.add(value);
    } else {
      next.remove(value);
    }
    app.setCurrentEntitlements(next);
  }

  void _addCustomEntitlement() {
    final value = _customEntitlement.text.trim();
    if (value.isEmpty) return;
    final app = AppScope.of(context);
    app.setCurrentEntitlements({...app.currentEntitlements, value});
    _customEntitlement.clear();
    setState(() {});
  }

  void _pushProfile() {
    AppScope.of(context).setTestProfile(
      nickname: _nickname.text,
      bio: _bio.text,
      avatarUrl: _avatar.text,
    );
  }

  Future<void> _connect() async {
    final app = AppScope.of(context);
    _pushProfile();
    setState(() => _busy = true);
    try {
      final result = await app.connectDemoUser(
        entitlements: app.currentEntitlements,
        sendTestProfile: true,
      );
      final failure = describeConnectUserFailure(result);
      if (!mounted) return;
      showSampleSnackBar(context, failure ?? 'Connected as ${app.displayName}');
    } catch (e) {
      app.noteConnectFailure('$e');
      if (mounted) showSampleSnackBar(context, 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final result = await app.refreshEntitlements();
      if (!mounted) return;
      showSampleSnackBar(context, 'refreshEntitlements → $result');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await app.disconnectUser();
      if (mounted) showSampleSnackBar(context, 'Disconnected');
    } catch (e) {
      if (mounted) showSampleSnackBar(context, 'Disconnect failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final connected = app.userConnected;
    final custom =
        (app.currentEntitlements
            .where((e) => !_standardEntitlements.any((s) => s.$1 == e))
            .toList()
          ..sort());

    return Scaffold(
      appBar: AppBar(title: const SampleAppBarTitle('Account')),
      body: Semantics(
        identifier: 'account-screen',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identity ────────────────────────────────────────────────
            SampleSection(
              title: connected ? 'Connected user' : 'Identity',
              tone: connected ? SampleTone.success : SampleTone.neutral,
              identifier: 'account-identity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(url: app.testAvatarUrl, name: app.displayName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                if (connected) ...[
                                  SampleDot(sampleGreenFor(theme.brightness)),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    connected
                                        ? 'Connected · ${app.effectiveUserId}'
                                        : 'Not connected · '
                                              '${app.effectiveUserId}',
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'account-nickname-input',
                    container: true,
                    child: TextField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: 'Nickname',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(_pushProfile),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    identifier: 'account-avatar-input',
                    container: true,
                    child: TextField(
                      controller: _avatar,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Avatar URL',
                        hintText: 'Leave empty to show initials',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(_pushProfile),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    identifier: 'account-bio-input',
                    container: true,
                    child: TextField(
                      controller: _bio,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(_pushProfile),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Entitlements ────────────────────────────────────────────
            SampleSection(
              title: 'Entitlements',
              identifier: 'account-entitlements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (value, label) in _standardEntitlements)
                    Semantics(
                      identifier:
                          'account-entitlement-${value.split(':').last}',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(label),
                        subtitle: Text(
                          value,
                          style: const TextStyle(
                            fontFamily: sampleMonoFamily,
                            fontSize: 12,
                          ),
                        ),
                        value: _entitlements.contains(value),
                        onChanged: (on) => _toggle(value, on),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Semantics(
                          identifier: 'account-custom-entitlement-input',
                          container: true,
                          child: TextField(
                            controller: _customEntitlement,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Custom entitlement',
                              hintText: 'customer:beta',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addCustomEntitlement(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        identifier: 'account-custom-entitlement-add',
                        button: true,
                        child: IconButton.filled(
                          tooltip: 'Add entitlement',
                          onPressed: _addCustomEntitlement,
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final value in custom)
                          Semantics(
                            identifier: 'account-entitlement-chip-$value',
                            child: InputChip(
                              label: Text(value),
                              onDeleted: () => _toggle(value, false),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'The entitlements the forged JWT will carry. The community '
                    'backend resolves them — the SDK profile reports what it '
                    'granted.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Session ─────────────────────────────────────────────────
            SampleSection(
              title: 'Session',
              identifier: 'account-session',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Action(
                    label: connected ? 'Reconnect' : 'Connect SSO User',
                    help: connected
                        ? 'Re-creates the Octopus session with the updated '
                              'entitlements.'
                        : 'Forges a local JWT with these values and calls '
                              'connectUser. No real identity server is '
                              'contacted.',
                    identifier: 'account-connect-button',
                    onPressed: _busy ? null : _connect,
                  ),
                  if (connected) ...[
                    const SizedBox(height: 12),
                    _Action(
                      label: 'Refresh entitlements',
                      help: 'Lighter SDK-side refresh, keeps the session.',
                      identifier: 'account-refresh-button',
                      filled: false,
                      onPressed: _busy ? null : _refresh,
                    ),
                    const SizedBox(height: 12),
                    _Action(
                      label: 'Disconnect',
                      help:
                          'Ends the Octopus session. The SDK falls back to a '
                          'read-only guest.',
                      identifier: 'account-disconnect-button',
                      filled: false,
                      danger: true,
                      onPressed: _busy ? null : _disconnect,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One session action: the control, then the single line that says what it
/// actually does. No action on this screen ships without its help line.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.help,
    required this.identifier,
    required this.onPressed,
    this.filled = true,
    this.danger = false,
  });

  final String label;
  final String help;
  final String identifier;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Navy on light / accent blue on dark for a non-danger outline action —
    // same swap as the app-wide button theme, which the filled variant
    // inherits directly by passing a null style below.
    final accent = danger
        ? sampleDangerFor(theme.brightness)
        : sampleAccent(theme.brightness);
    final button = filled
        ? FilledButton(
            onPressed: onPressed,
            style: danger
                ? FilledButton.styleFrom(backgroundColor: accent)
                : null,
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
            ),
            child: Text(label),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Semantics(
            identifier: identifier,
            button: true,
            child: SizedBox(height: 48, child: button),
          ),
        ),
        const SizedBox(height: 4),
        Text(help, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// The avatar the sample would send with `connectUser`: the pasted picture, or
/// the initials of the display name. Never a generic silhouette — an empty
/// avatar is a real state a host has to render, and initials render it
/// honestly.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String url;
  final String name;

  String get _initials {
    final parts = name
        .split(RegExp(r'[\s_\-.]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Semantics(
      identifier: 'account-avatar',
      child: CircleAvatar(
        radius: 26,
        backgroundColor: sampleTintFor(brightness),
        foregroundImage: url.isEmpty ? null : NetworkImage(url),
        child: Text(
          _initials,
          style: TextStyle(
            color: sampleAccent(brightness),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
