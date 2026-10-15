import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import 'connect_user_result.dart';

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
  bool _seeded = false;
  bool _busy = false;

  bool get _showNickname =>
      widget.fieldToEdit == null || widget.fieldToEdit == 'NICKNAME';
  bool get _showBio =>
      widget.fieldToEdit == null || widget.fieldToEdit == 'BIO';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.maybeOf(context);
    if (_seeded || app == null) return;
    _seeded = true;
    _nicknameController.text = app.profileForEditing.nickname ?? '';
    _bioController.text = app.profileForEditing.bio ?? '';
  }

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
    final previous = app.profileForEditing;
    // Native connectUser ignores a null nickname; null bio/picture clear them.
    // Keep unedited values, while an edited empty bio deliberately clears it.
    final nickname = _showNickname
        ? _nicknameController.text.trim()
        : previous.nickname;
    final bio = _showBio ? _bioController.text.trim() : previous.bio;
    final picture = previous.picture;
    final userId = app.effectiveUserId;
    try {
      final result = await app.connectWithProfile(
        userId: userId,
        nickname: nickname,
        bio: bio,
        picture: picture,
      );
      final failure = describeConnectUserFailure(result);
      if (failure != null) {
        // A rejected profile (nickname taken, bio too long, …) arrives as a
        // refusal, not an exception — without this branch the page would pop
        // as if the save had worked.
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Save failed — $failure')));
        }
        return;
      }
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
    const bioMaxLines = 4;
    final inputStyle = Theme.of(context).textTheme.bodyLarge!;
    final linePainter = TextPainter(
      text: TextSpan(text: ' ', style: inputStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    // Reserve the extra lines below the icon so its center matches Nickname's
    // first line, including when system text scaling changes the line height.
    final bioIconBottomPadding =
        (bioMaxLines - 1) * linePainter.preferredLineHeight;
    linePainter.dispose();

    return SampleScaffold(
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(SampleSpacing.space6),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 32,
                  child: Icon(Icons.person_outline, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit profile',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_showNickname)
                TextFormField(
                  controller: _nicknameController,
                  style: inputStyle,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a nickname'
                      : null,
                ),
              if (_showNickname && _showBio)
                const SizedBox(height: SampleSpacing.space4),
              if (_showBio)
                TextFormField(
                  controller: _bioController,
                  style: inputStyle,
                  maxLines: bioMaxLines,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    border: const OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: bioIconBottomPadding),
                      child: const Icon(Icons.description),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              const SizedBox(height: SampleSpacing.space6),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
