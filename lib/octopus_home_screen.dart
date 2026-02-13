import 'package:flutter/material.dart';
import 'dart:async';
import 'octopus_theme.dart';
import 'octopus_sdk.dart';

/// A Flutter widget that displays the native Octopus UI embedded within your Flutter app.
///
/// This widget provides a simple way to integrate the Octopus Community UI directly
/// into your Flutter application without opening a separate modal.
///
/// Example usage:
/// ```dart
/// OctopusHomeScreen(
///   navBarTitle: 'Community',
///   theme: OctopusTheme(
///     primaryMain: Colors.blue,
///     logoBase64: myLogoBase64,
///     themeMode: OctopusThemeMode.dark,
///   ),
///   showBackButton: false,
///   onNavigateToLogin: () {
///     // Handle navigation to login screen
///     print('User navigated to login');
///   },
///   onModifyUser: (fieldToEdit) {
///     // Handle profile modification
///     if (fieldToEdit != null) {
///       print('User wants to edit: $fieldToEdit');
///     } else {
///       print('User wants to edit profile');
///     }
///   },
/// )
/// ```
class OctopusHomeScreen extends StatefulWidget {
  /// Title displayed in the navigation bar
  ///
  /// iOS: When provided, replaces the logo completely
  /// Android: Can be displayed alongside the logo
  final String? navBarTitle;

  /// If true, uses the primary color for the navigation bar background
  final bool navBarPrimaryColor;

  /// If true, shows the back button in the navigation bar (Android only)
  final bool showBackButton;

  /// Custom theme for the interface (colors, font sizes, logo)
  final OctopusTheme? theme;


  /// Whether to show a loading indicator while the native view is initializing
  final bool showLoadingIndicator;

  /// Widget to display while loading (if showLoadingIndicator is true)
  final Widget? loadingWidget;

  /// Error widget to display if the native view fails to load
  final Widget? errorWidget;

  /// Whether to show error states (default: true)
  final bool showError;

  /// Whether the widget should be enabled
  final bool enabled;

  /// Callback function called when the user navigates to login
  final VoidCallback? onNavigateToLogin;

  /// Callback function called when the user wants to modify their profile
  ///
  /// The parameter is the field that has been asked to be edited by the user.
  /// Null if the user tapped on "Edit my profile".
  final Function(String?)? onModifyUser;

  final VoidCallback? onBack;

  /// Callback function called when a URL is tapped inside the Octopus Community UI.
  ///
  /// When set, URLs are intercepted and forwarded to Flutter instead of being
  /// opened by the SDK. Return [UrlOpeningStrategy.handledByApp] if your app
  /// handles the URL, or [UrlOpeningStrategy.handledByOctopus] to let the SDK
  /// open it in the default browser.
  ///
  /// When not set, all URLs are handled by the SDK (default behavior).
  final UrlOpeningStrategy Function(String)? onNavigateToUrl;

  const OctopusHomeScreen({
    super.key,
    this.navBarTitle,
    this.navBarPrimaryColor = false,
    this.showBackButton = true,
    this.theme,
    this.showLoadingIndicator = true,
    this.loadingWidget,
    this.errorWidget,
    this.showError = true,
    this.enabled = true,
    this.onNavigateToLogin,
    this.onModifyUser,
    this.onBack,
    this.onNavigateToUrl,
  });

  @override
  State<OctopusHomeScreen> createState() => _OctopusHomeScreenState();
}

class _OctopusHomeScreenState extends State<OctopusHomeScreen> {
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for events from native code
    _eventSubscription = OctopusSDK.eventStream.listen((event) {
      if (event['event'] == 'loginRequired') {
        widget.onNavigateToLogin?.call();
      } else if (event['event'] == 'editUser') {
        final fieldToEdit = event['fieldToEdit'] as String?;
        widget.onModifyUser?.call(fieldToEdit);
      } else if (event['event'] == 'navigateToUrl') {
        final url = event['url'] as String?;
        if (url != null) {
          widget.onNavigateToUrl?.call(url);
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    // Use the provided theme directly
    OctopusTheme? mergedTheme = widget.theme;

    return OctopusSDK.embeddedView(
      navBarTitle: widget.navBarTitle,
      navBarPrimaryColor: widget.navBarPrimaryColor,
      showBackButton: widget.showBackButton,
      theme: mergedTheme,
      interceptUrls: widget.onNavigateToUrl != null,
    );
  }
}