import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

/// The native notification path handles posts/comments and profile links.
/// Group/member entry points use the public initial-screen API: the native
/// Android deep-link table has no group or member route in the pinned SDK.
OctopusInitialScreen? communityPushInitialScreen(
  OctopusNotification? notification,
) {
  final path = Uri.tryParse(notification?.linkPath ?? '')?.pathSegments;
  if (path == null || path.length != 2 || path.last.trim().isEmpty) return null;
  return switch (path.first) {
    'group' => OctopusInitialScreen.group(GroupScreenInfo(groupId: path.last)),
    'member' => OctopusInitialScreen.activity(
      ActivityScreenInfo.profileId(path.last),
    ),
    _ => null,
  };
}
