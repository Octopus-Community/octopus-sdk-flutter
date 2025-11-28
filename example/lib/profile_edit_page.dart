import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

class ProfileEditPage extends StatefulWidget {
  final String? fieldToEdit;
  final OctopusSdkFlutter octopus;

  const ProfileEditPage({super.key, this.fieldToEdit, required this.octopus});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.fieldToEdit != null) {
      _focusOnField(widget.fieldToEdit!);
    }
  }

  void _focusOnField(String field) {
    switch (field) {
      case 'NICKNAME':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(FocusNode());
          Future.delayed(const Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(FocusNode());
          });
        });
        break;
      case 'BIO':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(FocusNode());
          Future.delayed(const Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(FocusNode());
          });
        });
        break;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fieldToEdit != null 
            ? 'Modify ${_getFieldDisplayName(widget.fieldToEdit!)}'
            : 'Modify profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar section
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.fieldToEdit == null || widget.fieldToEdit == 'AVATAR')
                      ElevatedButton.icon(
                        onPressed: _changeAvatar,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Change picture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Nickname field
              if (widget.fieldToEdit == null || widget.fieldToEdit == 'NICKNAME')
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Please enter a username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),
              
              // Bio field
              if (widget.fieldToEdit == null || widget.fieldToEdit == 'BIO')
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell us about yourself...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 32),
              
              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'NICKNAME':
        return 'User profile name';
      case 'BIO':
        return 'User profile description';
      case 'AVATAR':
        return 'User profile picture';
      default:
        return 'Profile';
    }
  }

  Future<void> _changeAvatar() async {
    // Simuler le changement d'avatar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('not implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
  
      print('Profile saved:');
      print('Nickname: ${_nicknameController.text}');
      print('Bio: ${_bioController.text}');
      
      // Connect user with new informations (with all managed fields, a missing value will erase the field value in Octopus)
      await widget.octopus.connectUser(
        userId: "YOUR_INTERNAL_USER_ID",
        // Your backend should provide a jwt when authentifiyng a user
        // cf. https://doc.octopuscommunity.com/backend/sso 
        token: '',
        
        // nickname: "Example username", // optional if NICKNAME is not present in appManagedFields at init
        // bio: 'SSO user example bio', // optional if BIO is not present in appManagedFields at init
        // picture: 'https://...', // optional if AVATER is not present in appManagedFields at init
      );


      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

