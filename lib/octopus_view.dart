import 'package:flutter/material.dart';
import 'dart:async';
import 'octopus_theme.dart';
import 'octopus_sdk_flutter.dart';

/// A Flutter widget that displays the native Octopus UI embedded within your Flutter app.
/// 
/// This widget provides a simple way to integrate the Octopus Community UI directly
/// into your Flutter application without opening a separate modal.
/// 
/// Example usage:
/// ```dart
/// OctopusView(
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
class OctopusView extends StatefulWidget {
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

  const OctopusView({
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
    this.onBack
  });

  @override
  State<OctopusView> createState() => _OctopusViewState();
}

class _OctopusViewState extends State<OctopusView> {
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for events from native code
    _eventSubscription = OctopusSdkFlutter.eventStream.listen((event) {
      if (event['event'] == 'loginRequired') {
        widget.onNavigateToLogin?.call();
      } else if (event['event'] == 'editUser') {
        final fieldToEdit = event['fieldToEdit'] as String?;
        widget.onModifyUser?.call(fieldToEdit);
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

    return OctopusSdkFlutter.embeddedView(
      navBarTitle: widget.navBarTitle,
      navBarPrimaryColor: widget.navBarPrimaryColor,
      showBackButton: widget.showBackButton,
      theme: mergedTheme,
      onNavigateToLogin: widget.onNavigateToLogin,
      onModifyUser: widget.onModifyUser,
      onBack: widget.onBack
    );
  }
}
