import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _octopus = OctopusSdkFlutter();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_circle, size: 100, color: Colors.blue),
            const SizedBox(height: 32),

            // Title
            const Text(
              'Login page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Connect',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),

            // SSO connect button
            ElevatedButton(
              onPressed: _isConnecting ? null : _connectWithSSO,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isConnecting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Connection in progress...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 8),
                        Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isConnecting ? null : _disconnectUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text(
                    'Disconnect',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Back button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectWithSSO() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // User ID must be immutable for a specific user
      final userId = 'YOUR_USER_ID';

      // Server returns JSON with "token" key
      final token = 'GENERATE_VALID_JWT_USING_SHARED_SECRET';

      print('Connecting user with SSO: $userId');

      // Connect user within Octopus
      await _octopus.connectUser(
        userId: userId,
        token: token,
        
        // nickname: "Example username", // optional if NICKNAME is not present in appManagedFields at init
        // bio: 'SSO user example bio', // optional if BIO is not present in appManagedFields at init
        // picture: 'https://...', // optional if AVATER is not present in appManagedFields at init
      );

      print('SSO authentication successful');

      // Back to previous page
      if (mounted) {
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SSO authentication successful !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('SSO authentication failed: $e');
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnectUser() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      print('Disconnecting user from Octopus SDK');

      // Déconnecter l'utilisateur d'Octopus SDK
      await _octopus.disconnectUser();

      print('User disconnected successfully');

      if (mounted) {
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success !'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Disconnect failed: $e');
      setState(() {
        _errorMessage = 'Disconnect error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
}
