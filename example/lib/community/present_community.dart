/// The two non-embedded presentation shapes the Home dock offers.
///
/// The Scenarios tab still owns the *documented* demonstration of every
/// integration mode (with presets, deep-link variants and a result zone); these
/// helpers are the one-tap version behind Home's dock, so a tester can see the
/// SDK in a sheet or a modal without walking the catalog. Both build the same
/// [OctopusHomeScreen] the scenarios do, with the same login / profile-edit
/// routing and the same native close affordance.
library;

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';

/// Shared configuration of the embedded SDK surface for a modal presentation.
///
/// [navigationMode] is `navigationStack` in both shapes: a sheet and a
/// `fullscreenDialog` route are modal presentations, where iOS's legacy
/// navigation container can silently drop the SDK's own sub-navigation.
Widget _octopusSurface(
  BuildContext hostContext,
  AppState app, {
  required double bottomSafeArea,
  String? navBarTitle,
}) {
  return OctopusHomeScreen(
    theme: app.effectiveOctopusTheme(),
    navBarTitle: navBarTitle,
    navigationMode: OctopusNavigationMode.navigationStack,
    navBarLeadingAction: OctopusNavBarLeadingAction.close,
    bottomSafeAreaInset: bottomSafeArea,
    notification: app.pendingCommunityNotification,
    onBack: () => Navigator.of(hostContext).pop(),
    onNavigateToLogin: () => Navigator.of(
      hostContext,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
    onModifyUser: (field) =>
        Navigator.of(hostContext, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => ProfileEditPage(fieldToEdit: field),
          ),
        ),
  );
}

/// Opens the community in a 90%-height Material bottom sheet.
Future<void> openCommunitySheet(BuildContext context) async {
  final app = AppScope.of(context);
  demoLog.apiCall('showModalBottomSheet<OctopusHomeScreen>', const {
    'source': 'home-dock',
  });
  // Raw View inset, immune to what the widget tree consumes, so the SDK's
  // floating "Write a post" pill clears the home indicator.
  final bottomSafeArea = MediaQueryData.fromView(
    View.of(context),
  ).viewPadding.bottom;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      // Keep the SDK's bottom input bar above the software keyboard: the sheet
      // is a fixed fraction of the screen and does not resize for the IME.
      final mediaQuery = MediaQuery.of(sheetContext);
      final keyboardInset = mediaQuery.viewInsets.bottom;
      final fullHeight = mediaQuery.size.height;
      final maxHeight = fullHeight * 0.9;
      final available = fullHeight - keyboardInset;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SizedBox(
          height: maxHeight < available ? maxHeight : available,
          child: _octopusSurface(
            sheetContext,
            app,
            bottomSafeArea: bottomSafeArea,
          ),
        ),
      );
    },
  );
}

/// Opens the community in a `fullscreenDialog` route — the Flutter equivalent
/// of a modal presentation.
Future<void> openCommunityModal(BuildContext context) async {
  final app = AppScope.of(context);
  demoLog.apiCall('MaterialPageRoute<OctopusHomeScreen>', const {
    'fullscreenDialog': true,
    'source': 'home-dock',
  });
  final bottomSafeArea = MediaQueryData.fromView(
    View.of(context),
  ).viewPadding.bottom;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: _octopusSurface(
            routeContext,
            app,
            bottomSafeArea: bottomSafeArea,
            navBarTitle: 'Community',
          ),
        ),
      ),
    ),
  );
}
