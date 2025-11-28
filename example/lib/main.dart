import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter/octopus_theme.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import 'login_page.dart';
import 'profile_edit_page.dart';

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

  final octopus = OctopusSdkFlutter();
  bool _isInitializing = false;
  bool _isInitialized = false;
  String _authMode = 'SSO';
  String? logo;
  int _currentTabIndex = 0;

    @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      setState(() {
        // Set an image (jpg/png) in base64 here for a logo in the top bar
        // logo = "iVBORw0KGgoAAAANSUhEUgAAAHgAAAAoBAMAAADHxCMWAAAAG1BMVEUAAAD///9fX19/f3+fn5+/v7/f398/Pz8fHx8eKUFYAAAACXBIWXMAAA7EAAAOxAGVKw4bAAABw0lEQVRIie2TS0/CQBSFL21hugRE6LKNobisiMRlIw+35eUaeboswSDLaYyRn+2daQszShslccdJuOXM9Jv7aAtw1lln/Y8sB4NSktaGv4VvPAza5WlwO48h1z0N7i8xBKvT4GULQzWgJ8GGjaGV8RWfuXsJJp2hiZfX0SMx906QnmdJlzlTGbO7DQnu1tcLCtr0rTrwYieKjLMmkHzWgSI6zRVh7QV/Y2hS/kwiJ0rxVBdUF6kOusAXYe6mMMGY82InSnXJGLKmipuYwAYRvmOhqbNWNC9yEqw5YECGYsdYOQwkmF9WMRw6CcaO+7DBrgH5aF4xzGsMKC/biZ0IZ3yspwHs+Ek8r2+wjc126VGYYil9gAprMeNLMG9iRYP5bXe5dyIcYElbnpblAAlus2BBi1zVDk4UOq3u8XM1dyDDVnhCX3KicPbK0OGrpGLIME4JF8F6qG0PThS+GnrZD5/pwo3hHYoCuaBgO6A3Rj2cVuREsSTPEL4eVjQv6BVQmOSj3JuEKxtXdMdk/1j53EZ/SF50x5Ryrm4k73HxjzJBPHOaVn7yXtZNRfV1MWGjdL1bz9Pz5mY0Yef9qTAz0+E/6QsbtFgL+NY6GgAAAABJRU5ErkJggg==";
      });
    });
    
  }

  Future<void> _initOctopus() async {
    if (_isInitialized || _isInitializing) return;
    setState(() => _isInitializing = true);

    try {


      // Set the Octopus API Key using your favorite method
      const API_KEY = String.fromEnvironment('OCTOPUS_API_KEY');
      
      // Initialize SDK
      await octopus.initializeOctopusSDK(
        apiKey: API_KEY,
        // User profile properties managed by your app (optional)
        // a combination of
        // 'AVATAR',
        //  'BIO',
        //  'NICKNAME',
        appManagedFields: [],
      );


      // Sample app behavior, do not do this in your app 
      octopus.disconnectUser();

      setState(() => _isInitialized = true);

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

      await octopus.connectUser(
        userId: "YOUR_INTERNAL_USER_ID",
        // Your backend should provide a jwt when authentifiyng a user
        // cf. https://doc.octopuscommunity.com/backend/sso 
        token: '',
        
        // nickname: "Example username", // optional if NICKNAME is not present in appManagedFields at init
        // bio: 'SSO user example bio', // optional if BIO is not present in appManagedFields at init
        // picture: 'https://...', // optional if AVATER is not present in appManagedFields at init
      );

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
    } finally {
      
    }
  }


  Widget _buildConfigPage() {
    return Padding(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            
            if (!_isInitialized && _authMode == 'SSO')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _initOctopus,
                  child: const Text('Init'),
                ),
              ),

            if (_isInitialized) 
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connectUser,
                  child: const Text('Connect User'),
                ),
              ),
            

            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Initialize the SDK \n'
                      
                      '2. Switch to the "Community" tab to see the embedded widget',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPage() {
    print(
      '🔍 _buildCommunityPage called, logo: ${logo != null ? "loaded" : "null"}',
    );


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
      // logoBase64: logo!,
      themeMode: OctopusThemeMode.light,
    );

    // Using the OctopusView widget
    return OctopusView(
      //navBarTitle: 'Embedded Community',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: [_buildConfigPage(), _buildCommunityPage()],
      ),
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
