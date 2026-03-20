import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'profile_edit_page.dart';
import 'secrets.dart';

void main() => runApp(const OctopusApp());

class OctopusApp extends StatelessWidget {
  const OctopusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octopus SDK Sample App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5), // indigo-ish
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final octopus = OctopusSDK();
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isUserConnected = false;
  String? logo;
  int _currentTabIndex = 0;
  int _notSeenCount = 0;
  bool? _hasAccessToCommunity;

  static const String _userConnectedKey = 'isUserConnected';

  @override
  void initState() {
    super.initState();

    OctopusSDK.notSeenNotificationsCount.listen((count) {
      debugPrint('[OCT-1142] notSeenNotificationsCount received: $count');
      if (mounted) setState(() => _notSeenCount = count);
    });
    OctopusSDK.hasAccessToCommunity.listen((hasAccess) {
      if (mounted) setState(() => _hasAccessToCommunity = hasAccess);
    });
    OctopusSDK.events.listen((event) {
      if (event is PostCreatedEvent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Octopus Post created: ${event.postId}')),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final byteData = await rootBundle.load('assets/logo.png');
      setState(() {
        logo = base64Encode(byteData.buffer.asUint8List());
      });

      // Load saved user connection state
      await _loadUserConnectionState();

      // Initialize SDK automatically on app start
      _initOctopus();
    });
  }

  Future<void> _loadUserConnectionState() async {
    final prefs = await SharedPreferences.getInstance();
    final isConnected = prefs.getBool(_userConnectedKey) ?? false;
    if (mounted) {
      setState(() => _isUserConnected = isConnected);
    }
  }

  Future<void> _saveUserConnectionState(bool isConnected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userConnectedKey, isConnected);
  }

  Future<void> _initOctopus() async {
    if (_isInitialized || _isInitializing) return;
    setState(() => _isInitializing = true);

    try {
      // Initialize SDK
      await octopus.initialize(
        // Change it in secrets.dart
        apiKey: octopusApiKey,
        // User profile properties managed by your app (optional)
        // a combination of
        // 'PICTURE',
        //  'BIO',
        //  'NICKNAME',
        appManagedFields: [ProfileField.nickname],  // e.g. [ProfileField.nickname, ProfileField.picture, ProfileField.bio]
      );

      setState(() => _isInitialized = true);

      // Connect the user in Octopus if he is connected in app
      if (_isUserConnected) {
        await _connectUser();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Octopus SDK initialized')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Init failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _connectUser() async {
    if (!_isInitialized || _isInitializing) return;

    try {
      // Connect user
      await octopus.connectUser(
        userId: "YOUR_INTERNAL_USER_ID",
        // Your backend should provide a jwt when authentifiyng a user
        // cf. https://doc.octopuscommunity.com/backend/sso
        token: octopusUserToken, // Stored in secrets.dart FOR SAMPLE USAGE
        // nickname: "Example username", // optional if NICKNAME is not present in appManagedFields at init
        // bio: 'SSO user example bio', // optional if BIO is not present in appManagedFields at init
        // picture: 'https://...', // optional if PICTURE is not present in appManagedFields at init
      );

      setState(() => _isUserConnected = true);
      await _saveUserConnectionState(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User connected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  Future<void> _disconnectUser() async {
    try {
      await octopus.disconnectUser();
      setState(() => _isUserConnected = false);
      await _saveUserConnectionState(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disconnect failed: $e')),
        );
      }
    }
  }


  Widget _buildConfigPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with description
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.widgets, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Embedded Widget Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The Octopus interface is integrated directly into your Flutter application '
                      'as a widget. Ideal for integration into your existing interface.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SDK Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SDK Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isInitialized ? 'Initialized' : 'Not initialized',
                          style: TextStyle(
                            color: _isInitialized ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_isInitialized) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications,
                            color: _notSeenCount > 0 ? Colors.orange : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Unread notifications: $_notSeenCount',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              onPressed: () async {
                                await octopus.updateNotSeenNotificationsCount();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Notification count refreshed')),
                                  );
                                }
                              },
                              child: const Text('Refresh', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _hasAccessToCommunity == true ? Icons.lock_open : Icons.lock,
                            color: _hasAccessToCommunity == true ? Colors.green : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Community access: ${_hasAccessToCommunity ?? 'unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            if (_isInitialized)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUserConnected ? _disconnectUser : _connectUser,
                  style: _isUserConnected ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade700,
                  ) : null,
                  child: Text(
                      _isUserConnected ? 'Disconnect User' : 'Connect User'),
                ),
              ),

            const SizedBox(height: 16),

          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCommunityPage() {
    // If SDK is not initialized, show message
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'SDK not initialized',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please initialize the SDK in the Configuration tab',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Example of using the embedded widget with custom theme

    var embeddedTheme = OctopusTheme(
      // Different colors for the embedded view
      primaryMain: Colors.lightBlue,
      primaryLowContrast: Colors.lightBlue.withValues(alpha: 0.2),
      primaryHighContrast: Colors.lightBlue.withValues(alpha: 0.4),
      onPrimary: Colors.deepPurple,

      // Smaller font sizes for the embedded view
      fontSizeTitle1: 12, // Smaller than default (26)
      fontSizeTitle2: 18, // Smaller than default (20)
      fontSizeBody1: 15, // Smaller than default (17)
      fontSizeBody2: 14, // Smaller than default (14)
      fontSizeCaption1: 11, // Smaller than default (12)
      fontSizeCaption2: 9, // Smaller than default (10)
      // Custom logo
      logoBase64: logo!,
      themeMode: OctopusThemeMode.light,
    );

    // Using the OctopusHomeScreen widget
    return OctopusHomeScreen(
      theme: embeddedTheme,
      navBarPrimaryColor: true,
      showBackButton: false,
      enabled: _isInitialized,
      // will be called when an anonymous user (a user on which you did not perform a connectUser) wants to write content
      onNavigateToLogin: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const LoginPage()));
      },
      // If you have appManagedFields, you need to handle when a user wants to modify his profile
      onModifyUser: (fieldToEdit) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileEditPage(fieldToEdit: fieldToEdit, octopus: octopus),
          ),
        );
      },
      onNavigateToUrl: (url) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('On Navigate to Url: $url')),
        );
        return UrlOpeningStrategy.handledByApp;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentTabIndex == 0 ? _buildConfigPage() : _buildCommunityPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuration',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
        ],
      ),
    );
  }
}
