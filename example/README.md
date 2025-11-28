# Octopus SDK Flutter - Examples

This project demonstrates how to use the `octopus_sdk_flutter` plugin

## 🚀 Integration Modes


- **File**: `lib/main.dart`
- **Description**: The Octopus interface is integrated directly into your Flutter application as a widget
- **Ideal for**:
  - Applications that want to integrate the community into their existing interface
  - Smooth navigation between your app and the community
  - Frequent community usage

## 🎯 Getting Started


### API Key Configuration
Configure your API keys via environment variables:

```bash
flutter run --dart-define=OCTOPUS_API_KEY=your_api_key_here
```


## 🔧 Demonstrated Features

### Authentication
- **SSO**: Your application manages user authentication

### Customization
- **Custom themes**: Colors, font sizes, logos
- **Navigation**: Custom navigation bar titles
- **Interface**: Adaptation according to the chosen mode

### State Management
- **Initialization**: SDK configuration according to authentication mode
- **Connection**: Management of connected users
- **Disconnection**: Session cleanup

## 📚 Available SDK Methods

### Initialization
```dart
// SSO mode (your app manages auth)
await octopus.initializeOctopusSDK(
  apiKey: 'your_api_key',
  appManagedFields: ['AVATAR', 'NICKNAME'], // Optional
);

```

### User Management
```dart
// Connect user
await octopus.connectUser(
  userId: 'user123',
  token: 'jwt_token',
  nickname: 'John Doe',
  bio: 'User bio',
  picture: 'https://example.com/avatar.jpg'
);

// Connect with token provider
await octopus.connectUserWithTokenProvider(
  userId: 'user123',
  tokenProvider: () async => await fetchTokenFromServer(),
  nickname: 'John Doe',
);

// Disconnect user
await octopus.disconnectUser();
```

### UI Display
```dart

// Embedded widget with callbacks
OctopusView(
  navBarTitle: 'Community',
  navBarPrimaryColor: false,
  showBackButton: true,
  theme: customTheme,
  onNavigateToLogin: () async {
    print('Navigate to login');
    // After user completes login, call octopus.connectUser() with the user's credentials
  },
  onModifyUser: (fieldToEdit) {
    print('Modify user field: $fieldToEdit');
  },
  onCurrentPageChanged: (currentPage) {
    print('Current page: $currentPage');
  },
);
```

## 📁 File Structure

### Example App Files
```
example/lib/
├── main.dart              # Integration mode selector
```

### Package Files
```
lib/
├── octopus_sdk_flutter.dart           # Main SDK class
├── octopus_sdk_flutter_platform_interface.dart  # Platform interface
├── octopus_sdk_flutter_method_channel.dart      # Method channel implementation
├── octopus_theme.dart                 # Theme customization class
└── octopus_view.dart                  # Embedded widget wrapper
```

## 🎨 Customization

### Available Theme Properties
```dart
final customTheme = OctopusTheme(
  // Colors
  primaryMain: Colors.pink,
  primaryLowContrast: Colors.pink.withValues(alpha: 0.2),
  primaryHighContrast: Colors.white,
  onPrimary: Colors.white,
  
  // Font sizes (in points)
  fontSizeTitle1: 26,    // Main titles
  fontSizeTitle2: 20,    // Secondary titles
  fontSizeBody1: 17,     // Main body text
  fontSizeBody2: 14,     // Secondary body text
  fontSizeCaption1: 12,  // Main captions
  fontSizeCaption2: 10,  // Secondary captions
  
  // Custom logo (base64)
  logoBase64: logo,
);
```

### Embedded Widget Usage
```dart
OctopusView(
  navBarTitle: 'Community',
  theme: customTheme,
  showBackButton: false,
  onNavigateToLogin: () async {
    print('Navigate to login');
    // After user completes login, call octopus.connectUser() with the user's credentials
  },
  onModifyUser: (fieldToEdit) {
    print('Modify user field: $fieldToEdit');
  },
  onCurrentPageChanged: (currentPage) {
    print('Current page: $currentPage');
  },
)
```

## 🔍 Debugging

Debug logs are enabled to help you understand the authentication flow:
- Token generation
- User connection
- Error handling

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Octopus SDK Plugin](https://pub.dev/packages/octopus_sdk_flutter)
- [Code Examples](https://github.com/octopuscommunity/octopus_sdk_flutter)

## 🆘 Support

For any questions or issues:
1. Check that your API keys are correctly configured
2. Consult the debug logs
3. Contact the Octopus Community team
