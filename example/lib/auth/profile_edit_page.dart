import 'package:flutter/material.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../octopus_demo_config.dart';

/// Profile-edit page backing the embedded UI's `onModifyUser` callback.
///
/// When a profile field is app-managed (`appManagedFields`), the SDK asks the
/// host app to edit it. Saving re-connects the demo user with the updated
/// fields (the SSO way to push profile changes).
class ProfileEditPage extends StatefulWidget {
  /// The field the SDK asked to edit (`NICKNAME` / `BIO` / `PICTURE`), or null
  /// for "edit my profile".
  final String? fieldToEdit;

  const ProfileEditPage({super.key, this.fieldToEdit});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _busy = false;

  bool get _showNickname =>
      widget.fieldToEdit == null || widget.fieldToEdit == 'NICKNAME';
  bool get _showBio =>
      widget.fieldToEdit == null || widget.fieldToEdit == 'BIO';

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = AppScope.of(context);
    final nickname = _showNickname ? _nicknameController.text.trim() : null;
    final bio = _showBio ? _bioController.text.trim() : null;
    final userId = app.effectiveUserId;
    try {
      demoLog.apiCall('connectUser', {
        'userId': userId,
        if (nickname != null) 'nickname': nickname,
        if (bio != null) 'bio': bio,
      });
      await app.octopus.connectUser(
        userId: userId,
        tokenProvider: () async => octopusUserToken,
        nickname: nickname,
        bio: bio,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fieldToEdit == null
              ? 'Edit profile'
              : 'Edit ${widget.fieldToEdit}',
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_showNickname)
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a nickname' : null,
              ),
            if (_showNickname && _showBio) const SizedBox(height: 16),
            if (_showBio)
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
