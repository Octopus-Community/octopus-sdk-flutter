# Octopus SDK Flutter

A Flutter plugin for integrating Octopus Community into your Flutter applications. 

📖 **Official Documentation**: [https://doc.octopuscommunity.com/](https://doc.octopuscommunity.com/)

> **Note**: This Flutter SDK is based on the official Octopus Community SDKs. For detailed information about Octopus features, authentication methods, and integration concepts, please refer to the [official documentation](https://doc.octopuscommunity.com/). Some features of the native SDKs are not yet available. 

## Features

- 🎨 **Theme Customization**: Colors, font sizes, and logos
- 📱 **Cross-Platform**: iOS and Android support
- 🖼️ **Flexible UI**: Embedded widget
- 🔧 **Easy Integration**: Simple API with comprehensive documentation
- 👤 **User Management**: Connect, disconnect, and manage user sessions and profile information
- 🎯 **Complete SDK Lifecycle**: Initialize, authenticate, display UI, and cleanup

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  octopus_sdk_flutter: ^1.7.0
```

Then run:

```bash
flutter pub get
```

## Testing the Example Project

To test the example project, run the example app and follow the integration examples provided in the `/example` folder. You will need a sandbox community, an API Key and an SSO jwt secret.

## Platform-Specific Configuration

### Android Configuration

#### 1. Update `android/app/build.gradle`

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

#### 2. Update MainActivity.kt

**Important**: You must update your `android/app/src/main/kotlin/your/package/name/MainActivity.kt` file to extend `FlutterFragmentActivity` instead of `FlutterActivity`:

```kotlin
package com.yourpackage.yourapp

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

This is required for the Octopus SDK to work properly with the embedded widget functionality.

#### 3. Add Internet Permission

In `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application>
        <!-- Your existing configuration -->
    </application>
</manifest>
```

### iOS Configuration

#### 1. Update `ios/Podfile`

```ruby
# Minimum iOS version
platform :ios, '14.0'

# CocoaPods configuration
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Required for Octopus SDK
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
```

#### 2. Update `ios/Runner/Info.plist`

Add network permissions for API calls:

```xml
<dict>
    <!-- Your existing configuration -->
    
    <!-- Allow arbitrary loads for development -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
```

## Core SDK Functions

The Octopus SDK Flutter provides four main functions to manage the complete lifecycle:

### 1. **Initialize SDK** 
Set up the SDK with your API key

### 2. **Connect User** 
Authenticate and connect a user to the Octopus Community

### 3. **Show Octopus UI**
Display the Octopus Community interface (embedded)

### 4. **Disconnect User** 
Log out the current user and clean up the session

---

## Quick Start Guide

### Step 1: Basic Setup

```dart
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter/octopus_theme.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final octopus = OctopusSdkFlutter();
  bool isInitialized = false;
  bool isUserConnected = false;
}
```

### Step 2: Initialize SDK

```dart
// Initialize SDK
await octopus.initializeOctopusSDK(
  apiKey: 'your_api_key',
  appManagedFields: [], // Optional: fields managed by your app (NICKNAME, AVATAR, BIO)
);
```

### Step 3 (optional): Connect User 

**⚠️ Note**: For security reasons, the jwt has to be generated on your backend. Never leave the sso secret inside your app code/build!

```dart
// Connect User
await octopus.connectUser(
  userId: 'unique_user_id',
  token: 'your_jwt_token_here', // Replace with actual token from your backend
  nickname: 'John Doe',              // Optional
  bio: 'Flutter developer',          // Optional  
  picture: 'https://example.com/avatar.jpg' // Optional: URL or base64
);
```

### Step 4: Show Octopus UI

Once the SDK is initialized, you can display the Octopus Community interface.


```dart
// Show Octopus UI - Embedded Widget
Container(
  width: double.infinity,
  height: 400,
  child: OctopusView(
    navBarTitle: 'Embedded Community',
    navBarPrimaryColor: true,  // Use primary color for nav bar background
    theme: OctopusTheme(
      primaryMain: Colors.purple,
      fontSizeTitle1: 24,
      fontSizeBody1: 16,
    ),
    // see sample app in /example for examples on how to use the callback features
    onNavigateToLogin: () {
      // Handle navigation to login
      print('Navigate to login');
    },
    onModifyUser: (fieldToEdit) {
      // Handle user profile modification
      print('Modify user field: $fieldToEdit');
    },
  ),
)
```

### Step 5: Disconnect User 

```dart
// Disconnect User 
await octopus.disconnectUser();
```

### Complete Example

Here's a complete working example that demonstrates all functions:

```dart
import 'package:flutter/material.dart';

import 'main_embedded.dart';
import 'main_modal.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter/octopus_theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octopus SDK - Embedded Mode',
      home: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final octopus = OctopusSdkFlutter();
  bool isInitialized = false;
  bool isUserConnected = false;
  String status = 'Not initialized';
  
  @override
  void initState() {
    super.initState();
    initializeSDK();
  }
  
  // Initialize SDK
  Future<void> initializeSDK() async {
    setState(() => status = 'Initializing...');
    
    try {
      await octopus.initializeOctopusSDK(
        apiKey: 'your_api_key',
        appManagedFields: ['NICKNAME', 'AVATAR'], // Valid values: NICKNAME, AVATAR, BIO
      );
      
      setState(() {
        isInitialized = true;
        status = 'SDK initialized - Ready to connect user';
      });
    } catch (e) {
      setState(() => status = 'Initialization error: $e');
    }
  }
  
  // Connect User
  Future<void> connectUser() async {
    setState(() => status = 'Connecting user...');
    
    try {
      final token = 'your_jwt_token_here'; // Replace with actual token from your backend
      
      await octopus.connectUser(
        userId: 'user123',
        token: token,
        nickname: 'John Doe'
      );
      
      setState(() {
        isUserConnected = true;
        status = 'User connected - Ready to show UI';
      });
    } catch (e) {
      setState(() => status = 'Connection error: $e');
    }
  }
  
  // Show UI
  Future<void> showOctopusUI() async {
    octopus.showOctopusView(
      context,
      navBarTitle: 'Community',
      navBarPrimaryColor: true,
      theme: OctopusTheme(
        primaryMain: Colors.blue,
        fontSizeTitle1: 26,
      ),
    onNavigateToLogin: () {
      print('Navigate to login');
      // After user completes login, call octopus.connectUser() with the user's credentials
    },
      onModifyUser: (fieldToEdit) {
        print('Modify user field: $fieldToEdit');
      },
    );
  }
  
  // Disconnect User
  Future<void> disconnectUser() async {
    await octopus.disconnectUser();
    setState(() {
      isUserConnected = false;
      status = 'User disconnected';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Octopus SDK Demo')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $status'),
            SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: isInitialized && !isUserConnected ? connectUser : null,
              child: Text('2. Connect User'),
            ),
            
            ElevatedButton(
              onPressed: isUserConnected ? showOctopusUI : null,
              child: Text('3. Show Octopus UI'),
            ),
            
            ElevatedButton(
              onPressed: isUserConnected ? disconnectUser : null,
              child: Text('4. Disconnect User'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Theme Customization

The `OctopusTheme` class allows complete customization of the Octopus Community interface:

### Colors

```dart
final theme = OctopusTheme(
  primaryMain: Color(0xFF6200EA),           // Main brand color
  primaryLowContrast: Color(0x336200EA),   // Low contrast variant
  primaryHighContrast: Colors.white,       // High contrast variant
  onPrimary: Colors.white,                 // Content color on primary
);
```

### Font Sizes

```dart
final theme = OctopusTheme(
  fontSizeTitle1: 26,    // Main titles (default: 26)
  fontSizeTitle2: 20,    // Secondary titles (default: 20)
  fontSizeBody1: 17,     // Main body text (default: 17)
  fontSizeBody2: 14,     // Secondary body text (default: 14)
  fontSizeCaption1: 12,  // Main captions (default: 12)
  fontSizeCaption2: 10,  // Secondary captions (default: 10)
);
```

### Custom Logo

```dart
final theme = OctopusTheme(
  logoBase64: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...', // Full base64
  // or
  logoBase64: 'iVBORw0KGgoAAAANSUhEUgAA...', // Base64 without prefix
);
```

### Complete Theme Example

```dart
final customTheme = OctopusTheme(
  // Brand colors
  primaryMain: const Color(0xFF1976D2),
  primaryLowContrast: const Color(0xFF1976D2).withOpacity(0.12),
  primaryHighContrast: Colors.white,
  onPrimary: Colors.white,
  
  // Typography scale
  fontSizeTitle1: 32,
  fontSizeTitle2: 24,
  fontSizeBody1: 18,
  fontSizeBody2: 16,
  fontSizeCaption1: 14,
  fontSizeCaption2: 12,
  
  // Branding
  logoBase64: 'your_logo_base64_here',
);
```


## API Reference

### OctopusSdkFlutter Methods

#### `initializeOctopusSDK`
```dart
Future<void> initializeOctopusSDK({
  required String apiKey,
  List<String>? appManagedFields,
})
```

**Parameters:**
- `apiKey` (required): Your Octopus Community API key
- `appManagedFields` (optional): List of profile fields managed by your app instead of Octopus Community

**appManagedFields Details:**
This parameter allows you to specify which user profile fields should be managed by your application rather than by Octopus Community. When a field is in this list, users will not be able to edit it directly in the Octopus Community interface. Instead, your app should handle editing these fields through the `onModifyUser` callback.

**Valid field names (only these 3 values are supported):**
- `'NICKNAME'`: User's display name
- `'AVATAR'`: User's profile picture  
- `'BIO'`: User's biography/description

**Example:**
```dart
await octopus.initializeOctopusSDK(
  apiKey: 'your-api-key',
  appManagedFields: ['NICKNAME', 'AVATAR', 'BIO'],
);
```

If `appManagedFields` is empty or null, all fields will be managed by Octopus Community (default behavior).


#### `connectUser`
```dart
Future<void> connectUser({
  required String userId,
  required String token,
  String? nickname,
  String? bio,
  String? picture
})
```

#### `OctopusView` Widget
```dart
OctopusView({
  String? navBarTitle,              // Navigation bar title
  bool navBarPrimaryColor = false,  // Use primary color for nav bar
  bool showBackButton = true,       // Show back button (Android only)
  OctopusTheme? theme,              // Custom theme
  required VoidCallback onNavigateToLogin,  // Login navigation callback
  Function(String?)? onModifyUser,  // User modification callback
  Function(String)? onCurrentPageChanged,  // Page change callback
})
```

**Parameters:**
- `navBarTitle`: Title text to display in the embedded view's navigation bar
- `navBarPrimaryColor`: Whether to use the primary theme color for the navigation bar background
- `showBackButton`: Whether to show the back button in the navigation bar (Android only)
- `theme`: Optional custom theme for colors, fonts, and logo
- `onNavigateToLogin`: Required callback for login navigation
- `onModifyUser`: Optional callback for user profile modification
- `onCurrentPageChanged`: Optional callback for page change events

**Features:**
- **Embedded Widget**: Integrates seamlessly into your Flutter UI
- **Callback Support**: Full callback support for navigation and user actions
- **Cross-platform**: Consistent behavior on iOS and Android

### OctopusTheme Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `primaryMain` | `Color?` | `null` | Main brand color |
| `primaryLowContrast` | `Color?` | `null` | Low contrast variant |
| `primaryHighContrast` | `Color?` | `null` | High contrast variant |
| `onPrimary` | `Color?` | `null` | Content color on primary |
| `fontSizeTitle1` | `int?` | `26` | Main titles font size |
| `fontSizeTitle2` | `int?` | `20` | Secondary titles font size |
| `fontSizeBody1` | `int?` | `17` | Main body text font size |
| `fontSizeBody2` | `int?` | `14` | Secondary body text font size |
| `fontSizeCaption1` | `int?` | `12` | Main captions font size |
| `fontSizeCaption2` | `int?` | `10` | Secondary captions font size |
| `logoBase64` | `String?` | `null` | Custom logo in base64 format |
| `themeMode` | `OctopusThemeMode?` | `null` | Theme mode (light/dark) |

### OctopusThemeMode Enum

The `OctopusThemeMode` enum allows you to control the overall appearance of the Octopus interface:

```dart
enum OctopusThemeMode {
  /// Light theme mode - bright interface with dark text
  light,
  /// Dark theme mode - dark interface with light text
  dark,
}
```

**Usage Examples:**

```dart
// Light theme
final lightTheme = OctopusTheme(
  primaryMain: Colors.blue,
  themeMode: OctopusThemeMode.light,
);

// Dark theme
final darkTheme = OctopusTheme(
  primaryMain: Colors.blue,
  themeMode: OctopusThemeMode.dark,
);

// Auto theme (follows system preference)
final autoTheme = OctopusTheme(
  primaryMain: Colors.blue,
  // themeMode: null (default) - follows system theme
);
```

**Theme Mode Behavior:**
- **`OctopusThemeMode.light`**: Forces light theme regardless of system setting
- **`OctopusThemeMode.dark`**: Forces dark theme regardless of system setting
- **`null` (default)**: Follows the system theme preference automatically

### Available Methods

| Method | Description | Required Parameters |
|--------|-------------|-------------------|
| `initializeOctopusSDK()` | Initialize SDK in SSO mode | `apiKey` |
| `connectUser()` | Connect user (SSO mode) | `userId`, `token` |
| `disconnectUser()` | Disconnect current user | None |
### Available Widgets

| Widget | Type | Description |
|--------|------|-------------|
| `OctopusView` | StatelessWidget | Simple embedded Octopus UI widget with callbacks |

### Converting Image to Base64

To use a custom logo, you need to convert your image to base64 format. Here's how to do it:

#### From Assets

```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  String? logoBase64;

  @override
  void initState() {
    super.initState();
    loadLogo();
  }

  Future<void> loadLogo() async {
    final bytes = await rootBundle.load('assets/logo.png');
    setState(() {
      logoBase64 = base64Encode(bytes.buffer.asUint8List());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (logoBase64 == null) {
      return CircularProgressIndicator();
    }

    final theme = OctopusTheme(
      logoBase64: logoBase64,
      primaryMain: Colors.blue,
      // ... other theme properties
    );

    return OctopusView(theme: theme);
  }
}
```

#### From Network Image

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<String> convertNetworkImageToBase64(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode == 200) {
    final bytes = response.bodyBytes;
    return base64Encode(bytes);
  } else {
    throw Exception('Failed to load image');
  }
}

// Usage
final logoBase64 = await convertNetworkImageToBase64('https://example.com/logo.png');
final theme = OctopusTheme(logoBase64: logoBase64);
```

#### From File

```dart
import 'dart:convert';
import 'dart:io';

Future<String> convertFileToBase64(String filePath) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  return base64Encode(bytes);
}

// Usage
final logoBase64 = await convertFileToBase64('/path/to/logo.png');
final theme = OctopusTheme(logoBase64: logoBase64);
```

## Troubleshooting

### Common Issues

#### iOS Build Issues
- Ensure iOS deployment target is 14.0 or higher
- Check that `ENABLE_USER_SCRIPT_SANDBOXING` is set to `NO`
- Run `cd ios && pod install --repo-update`

#### Android Build Issues
- Ensure `minSdkVersion` is 21 or higher
- Check that internet permission is added
- Clean and rebuild: `flutter clean && flutter pub get`

#### Authentication Issues
- Verify your API key is correct
- Check that JWT tokens are properly formatted 

#### Network Issues
- Check internet connectivity
- Verify API endpoints are reachable
- Review network security settings (iOS ATS)

## OctopusView Widgets

The `OctopusView` widgets provide a simplified way to integrate the native Octopus Community UI into your Flutter application.

### OctopusView (StatelessWidget)

The simplest widget to display the embedded Octopus UI. This widget is lightweight and suitable for most use cases:

**Key Features:**
- Lightweight and fast
- No state management overhead
- Suitable for simple integrations
- Minimal memory footprint

```dart
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OctopusView(
      navBarTitle: 'My Community',
      showBackButton: false,
    );
  }
}
```

### OctopusViewStateful (StatefulWidget)

For more advanced state management with error handling and loading states. This widget provides additional callbacks and state management:

**Key Features:**
- Built-in error handling with retry functionality
- Loading state management
- Callback support for view lifecycle events
- Automatic error recovery
- Custom loading and error widgets


The `errorWidget` parameter allows you to create fully customized error displays:

- **Interactive elements**: Buttons, links, custom actions
- **Branding integration**: Your app's colors, logos, fonts
- **Multiple actions**: Retry, help, contact support, etc.
- **Responsive design**: Adapt to different screen sizes
- **Accessibility**: Include proper labels and descriptions

### Available Parameters

#### OctopusView

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `navBarTitle` | `String?` | `null` | Title displayed in the navigation bar |
| `navBarPrimaryColor` | `bool` | `false` | Uses primary color for navigation bar background |
| `showBackButton` | `bool` | `true` | Shows back button (Android only) |
| `theme` | `OctopusTheme?` | `null` | Custom theme for the interface |
| `showLoadingIndicator` | `bool` | `true` | Shows loading indicator |
| `loadingWidget` | `Widget?` | `null` | Custom widget for loading state |
| `errorWidget` | `Widget?` | `null` | Custom widget for error state |
| `showError` | `bool` | `true` | Whether to show error states |
| `enabled` | `bool` | `true` | Enables/disables the widget |

#### OctopusViewStateful

All parameters from `OctopusView` plus:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `onBackPressed` | `VoidCallback?` | `null` | Callback called when user presses back |
| `onViewReady` | `VoidCallback?` | `null` | Callback called when view is ready |
| `onError` | `Function(String error)?` | `null` | Callback called on error |
| `showError` | `bool` | `true` | Whether to show error states |



### Usage Examples

#### Example with Custom Theme

```dart
final customTheme = OctopusTheme(
  primaryMain: Colors.blue,
  primaryLowContrast: Colors.blue.withOpacity(0.2),
  primaryHighContrast: Colors.white,
  onPrimary: Colors.white,
  fontSizeTitle1: 24,
  fontSizeBody1: 16,
  logoBase64: myLogoBase64,
);

OctopusView(
  navBarTitle: 'Community',
  theme: customTheme,
  navBarPrimaryColor: true,
  showBackButton: false,
)
```

#### Example with State Management

```dart
OctopusViewStateful(
  navBarTitle: 'Community',
  showBackButton: true,
  onBackPressed: () {
    Navigator.of(context).pop();
  },
  onViewReady: () {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Community loaded!')),
    );
  },
  onError: (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  },
  loadingWidget: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Loading your community...'),
      ],
    ),
  ),
)
```

#### Example with Error Control

```dart
// Hide error display but still handle errors via callback
OctopusViewStateful(
  navBarTitle: 'Community',
  showError: false, // Don't show error widget
  onError: (error) {
    // Handle error silently or show custom notification
    print('Error occurred: $error');
  },
)

// Or show custom error widget
OctopusViewStateful(
  navBarTitle: 'Community',
  showError: true,
  errorWidget: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No connection'),
        SizedBox(height: 8),
        Text('Please check your internet connection'),
      ],
    ),
  ),
)
```

#### Advanced Error Widget Customization

You can create highly customized error widgets with interactive elements:

```dart
OctopusViewStateful(
  navBarTitle: 'Community',
  errorWidget: Container(
    padding: EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.orange,
        ),
        SizedBox(height: 16),
        Text(
          'Something went wrong',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'We couldn\'t load the community right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Custom retry logic
                print('Retry pressed');
              },
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
            TextButton.icon(
              onPressed: () {
                // Custom help logic
                print('Help pressed');
              },
              icon: Icon(Icons.help_outline),
              label: Text('Help'),
            ),
          ],
        ),
      ],
    ),
  ),
)
```

#### Branded Error Widget

Create error widgets that match your app's branding:

```dart
OctopusViewStateful(
  navBarTitle: 'Community',
  theme: OctopusTheme(
    primaryMain: Colors.blue,
    // ... other theme properties
  ),
  errorWidget: Container(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Your app logo
        Image.asset(
          'assets/logo.png',
          height: 64,
          width: 64,
        ),
        SizedBox(height: 24),
        Text(
          'Connection Issue',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue, // Use your brand color
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Custom retry action
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // Your brand color
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text('Try Again'),
        ),
      ],
    ),
  ),
)
```

#### Example in TabBar

```dart
TabBarView(
  children: [
    // Other content...
    OctopusView(
      navBarTitle: 'Community',
      showBackButton: false,
    ),
  ],
)
```

#### Example in BottomNavigationBar

```dart
IndexedStack(
  index: _currentIndex,
  children: [
    // Other content...
    OctopusView(
      navBarTitle: 'Community',
      showBackButton: false,
    ),
  ],
)
```

### Error Handling

The `OctopusViewStateful` widget automatically handles errors and displays a default error widget with a "Retry" button. You can customize this behavior:

```dart
OctopusViewStateful(
  errorWidget: Center(
    child: Column(
      children: [
        Icon(Icons.wifi_off, size: 64),
        Text('No connection'),
        ElevatedButton(
          onPressed: () => setState(() {}),
          child: Text('Retry'),
        ),
      ],
    ),
  ),
)
```

### Important Notes

- The widget works on Android and iOS
- On iOS, `navBarTitle` completely replaces the logo
- On Android, `navBarTitle` can be displayed alongside the logo
- The `showBackButton` parameter only affects Android
- Make sure the SDK is initialized before using the widget

## Examples

Check the `/example` folder for complete implementation examples:

- **Basic Integration**: Simple setup with default theme
- **Custom Theme**: Advanced theming with custom colors and fonts
- **SSO Authentication**: Complete SSO flow with JWT token integration
- **Embedded Widgets**: Usage of `OctopusView` widgets with callbacks

## Support

For issues, questions, or contributions:

- 📧 **Email**: support@octopuscommunity.com
- 📖 **Official Documentation**: [https://doc.octopuscommunity.com/](https://doc.octopuscommunity.com/)
- 📖 **Flutter SDK Documentation**: This README

## License

This project is licensed under the Octopus Community Mobile SDK License Agreement - see the [LICENSE](LICENSE) file for details.
