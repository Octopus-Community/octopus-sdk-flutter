import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../config/host_integration.dart';
import '../widgets/open_url.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import 'client_profile_page.dart';
import 'community_push_target.dart';

/// One SDK toolbar in every container. Callbacks always use the host navigator.
class CommunitySurface extends StatefulWidget {
  const CommunitySurface({
    super.key,
    required this.app,
    this.active = true,
    this.presentation = false,
    this.modal = false,
    this.useCommunityNotification = true,
    this.bottomSafeArea = 0,
  });

  final AppState app;
  final bool active;
  final bool presentation;
  final bool modal;
  final bool useCommunityNotification;
  final double bottomSafeArea;

  @override
  State<CommunitySurface> createState() => _CommunitySurfaceState();
}

class _CommunitySurfaceState extends State<CommunitySurface> {
  VoidCallback? _cancelGroupAccess;

  void _syncGroupAccess() {
    _cancelGroupAccess?.call();
    _cancelGroupAccess = null;
    if (!widget.app.hostGroupAccessWired || !_canHandle) return;
    _cancelGroupAccess = OctopusSDK.setGroupAccessDeniedCallback((groupId) {
      if (!_canHandle) return;
      demoLog.note('Group access denied', {'groupId': groupId});
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Group access denied'),
          content: const Text(
            'The host received access denial for this group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _cancelGroupAccess?.call();
    super.dispose();
  }

  Key? _identity;
  OctopusNotification? _notification;

  bool get _canHandle =>
      mounted && widget.active && (ModalRoute.of(context)?.isCurrent ?? false);

  void _openHost(Widget page) {
    if (!_canHandle) return;
    // Push on the host root graph, preserving the SDK stack underneath so Back
    // returns to the same post, comment or profile that triggered the callback.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app,
    builder: (context, _) {
      _syncGroupAccess();
      final app = widget.app;
      final theme = app.effectiveOctopusTheme();
      final identity = ValueKey<String>(
        'community|${app.communitySession}|${app.communityRootEpoch}'
        '|${app.communityNavigation.name}'
        '|${app.activeThemeLabel}|${app.localeTag}'
        '|${theme?.themeMode?.name}|${app.unifiedProfileWired}'
        '|${app.exposeClientUserIdOverride.name}'
        '|${app.hostProfileEditWired}|${app.onAuthenticationRequiredWired}'
        '|${app.hostUrlHandling.name}',
      );
      if (_identity != identity) {
        _identity = identity;
        // A remount consumes only a pending target; it never replays a target
        // already consumed by the previous native view.
        _notification = widget.useCommunityNotification
            ? app.takeDisplayedCommunityNotification()
            : null;
      }
      final initialScreen = communityPushInitialScreen(_notification);
      return OctopusHomeScreen(
        key: identity,
        theme: theme,
        navBarTitle: 'Community',
        navBarPrimaryColor: false,
        titleCentered: Theme.of(context).platform == TargetPlatform.iOS,
        navigationMode: OctopusNavigationMode.navigationStack,
        showBackButton: widget.presentation,
        navBarLeadingAction: widget.presentation
            ? (widget.modal
                  ? OctopusNavBarLeadingAction.close
                  : OctopusNavBarLeadingAction.back)
            : null,
        bottomSafeAreaInset: widget.bottomSafeArea,
        // Supplying both would make the notification win over initialScreen.
        notification: initialScreen == null ? _notification : null,
        initialScreen: initialScreen,
        onBack: () {
          if (_canHandle) {
            if (widget.presentation) {
              Navigator.of(context, rootNavigator: true).pop();
            } else if (initialScreen != null) {
              app.resetCommunityRoot();
            }
          }
        },
        onNavigateToLogin: app.onAuthenticationRequiredWired
            ? () => _openHost(const LoginPage())
            : null,
        onModifyUser: app.hostProfileEditWired
            ? (field) => _openHost(ProfileEditPage(fieldToEdit: field))
            : null,
        // The bridge ignores the Dart return value. A null callback is the
        // only supported way to leave URL opening to the native SDK.
        onNavigateToUrl: app.hostUrlHandling == HostUrlHandling.inApp
            ? (url) {
                if (_canHandle) {
                  demoLog.apiCall('onNavigateToUrl', {'url': url});
                  openUrlOrCopy(
                    context,
                    url,
                    clipLabel: 'Community link',
                    mode: LaunchMode.inAppBrowserView,
                  );
                }
                return UrlOpeningStrategy.handledByApp;
              }
            : null,
        onNavigateToProfile: app.unifiedProfileWired
            ? (clientUserId) =>
                  _openHost(ClientProfilePage(clientUserId: clientUserId))
            : null,
      );
    },
  );
}

/// Sheet and Modal are demos; neither inherits a pending or previously opened push.
Future<void> openCommunitySheet(BuildContext context) async {
  final app = AppScope.of(context);
  final bottomSafeArea = MediaQueryData.fromView(
    View.of(context),
  ).viewPadding.bottom;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      final keyboardInset = mediaQuery.viewInsets.bottom;
      final maxHeight = mediaQuery.size.height * 0.9;
      final available = mediaQuery.size.height - keyboardInset;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SizedBox(
          height: maxHeight < available ? maxHeight : available,
          child: CommunitySurface(
            app: app,
            presentation: true,
            modal: true,
            useCommunityNotification: false,
            bottomSafeArea: bottomSafeArea,
          ),
        ),
      );
    },
  );
}

Future<void> openCommunityModal(BuildContext context) =>
    _openCommunityRoute(context, modal: true);

/// Full screen presents the whole native flow over the host shell on both OSes.
Future<void> openCommunityFullScreen(
  BuildContext context, {
  bool useCommunityNotification = false,
}) => _openCommunityRoute(
  context,
  useCommunityNotification: useCommunityNotification,
);

Future<void> _openCommunityRoute(
  BuildContext context, {
  bool modal = false,
  bool useCommunityNotification = false,
}) {
  final app = AppScope.of(context);
  final bottomSafeArea = MediaQueryData.fromView(
    View.of(context),
  ).viewPadding.bottom;
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: modal,
      builder: (_) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: CommunitySurface(
            app: app,
            presentation: true,
            modal: modal,
            useCommunityNotification: useCommunityNotification,
            bottomSafeArea: bottomSafeArea,
          ),
        ),
      ),
    ),
  );
}
