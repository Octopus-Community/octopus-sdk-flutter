import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_server.dart';
import 'client_post.dart';
import 'client_post_error.dart';
import 'client_user_error.dart';
import 'group_follow_unfollow_error.dart';
import 'octopus_group.dart';
import 'octopus_post.dart';
import 'octopus_reaction_kind.dart';
import 'octopus_result.dart';
import 'override_community_access_error.dart';
import 'refresh_entitlements_error.dart';
import 'set_reaction_error.dart';
import 'profile_field.dart';
import 'sync_follow_group.dart';
import 'octopus_sdk_platform.dart';

/// An implementation of [OctopusSDKPlatform] that uses method channels.
class OctopusSDKMethodChannel extends OctopusSDKPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('octopus_sdk_flutter');

  @override
  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) async {
    await methodChannel.invokeMethod('initialize', {
      'apiKey': apiKey,
      'appManagedFields':
          appManagedFields?.map((f) => f.toNativeValue()).toList(),
      'apiServer': apiServer?.toMap(),
    });
  }

  @override
  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) async {
    await methodChannel.invokeMethod('initializeOctopusAuth', {
      'apiKey': apiKey,
      'deepLink': deepLink,
      'apiServer': apiServer?.toMap(),
    });
  }

  @override
  Future<void> switchCommunity({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) async {
    await methodChannel.invokeMethod('switchCommunity', {
      'apiKey': apiKey,
      'appManagedFields':
          appManagedFields?.map((f) => f.toNativeValue()).toList(),
      'apiServer': apiServer?.toMap(),
    });
  }

  @override
  Future<void> switchCommunityOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) async {
    await methodChannel.invokeMethod('switchCommunityOctopusAuth', {
      'apiKey': apiKey,
      'deepLink': deepLink,
      'apiServer': apiServer?.toMap(),
    });
  }

  @override
  Future<void> reset() async {
    await methodChannel.invokeMethod('reset');
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod('stop');
  }

  @override
  Future<OctopusResult<void, ClientUserError>> connectUser(
      {required String userId,
      required String token,
      String? nickname,
      String? bio,
      String? picture}) async {
    final raw =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>('connectUser', {
      'userId': userId,
      'token': token,
      'nickname': nickname,
      'bio': bio,
      'picture': picture
    });
    return _decodeConnectUserResult(raw);
  }

  @override
  Future<OctopusResult<void, ClientUserError>> connectUserWithTokenProvider({
    required String userId,
    required String providerId,
    String? nickname,
    String? bio,
    String? picture,
  }) async {
    final raw = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('connectUserWithTokenProvider', {
      'userId': userId,
      'providerId': providerId,
      'nickname': nickname,
      'bio': bio,
      'picture': picture,
    });
    return _decodeConnectUserResult(raw);
  }

  OctopusResult<void, ClientUserError> _decodeConnectUserResult(
    Map<dynamic, dynamic>? raw,
  ) {
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, ClientUserError>(null);
    }
    return OctopusResult.failureFromWire<ClientUserError>(
      wire,
      ClientUserError.fromWire,
    );
  }

  @override
  Future<void> provideClientUserToken(String requestId, String token) async {
    await methodChannel.invokeMethod('provideClientUserToken', {
      'requestId': requestId,
      'token': token,
    });
  }

  @override
  Future<void> disconnectUser() async {
    await methodChannel.invokeMethod('disconnectUser');
  }

  @override
  Future<void> showCreatePostScreen(Map<String, dynamic> args) async {
    await methodChannel.invokeMethod('showCreatePostScreen', args);
  }

  @override
  Future<void> updateNotSeenNotificationsCount() async {
    await methodChannel.invokeMethod('updateNotSeenNotificationsCount');
  }

  @override
  Future<OctopusResult<void, OverrideCommunityAccessError>>
      overrideCommunityAccess(bool hasAccess) async {
    final raw = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'overrideCommunityAccess',
      {'hasAccess': hasAccess},
    );
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, OverrideCommunityAccessError>(null);
    }
    return OctopusResult.failureFromWire<OverrideCommunityAccessError>(
      wire,
      OverrideCommunityAccessError.fromWire,
    );
  }

  @override
  Future<OctopusResult<void, RefreshEntitlementsError>>
      refreshEntitlements() async {
    final raw = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('refreshEntitlements');
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, RefreshEntitlementsError>(null);
    }
    return OctopusResult.failureFromWire<RefreshEntitlementsError>(
      wire,
      RefreshEntitlementsError.fromWire,
    );
  }

  @override
  Future<OctopusResult<void, SetReactionError>> setReaction(
    OctopusReactionKind? reaction,
    String postId,
  ) async {
    final raw = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'setReaction',
      {
        'postId': postId,
        'reaction': reaction?.toWire(),
      },
    );
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, SetReactionError>(null);
    }
    return OctopusResult.failureFromWire<SetReactionError>(
      wire,
      SetReactionError.fromWire,
    );
  }

  @override
  Future<OctopusResult<OctopusPost, ClientPostError>>
      fetchOrCreateClientObjectRelatedPost(
    ClientPost clientPost, {
    required String requestId,
    required bool hasTokenProvider,
  }) async {
    final raw = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'fetchOrCreateClientObjectRelatedPost',
      {
        'clientPost': clientPost.toMap(),
        'requestId': requestId,
        'hasTokenProvider': hasTokenProvider,
      },
    );
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      final rawPost = wire['post'];
      return OctopusSuccess<OctopusPost, ClientPostError>(
        OctopusPost.fromWire(rawPost is Map ? rawPost : const {}),
      );
    }
    return OctopusResult.failureFromWire<ClientPostError>(
      wire,
      ClientPostError.fromWire,
    );
  }

  @override
  Future<void> provideBridgeToken(String requestId, String? token) async {
    await methodChannel.invokeMethod('provideBridgeToken', {
      'requestId': requestId,
      'token': token,
    });
  }

  @override
  Future<void> startClientObjectPostObservation(
      String observationId, String clientObjectId) async {
    await methodChannel.invokeMethod('startClientObjectPostObservation', {
      'observationId': observationId,
      'clientObjectId': clientObjectId,
    });
  }

  @override
  Future<void> stopClientObjectPostObservation(String observationId) async {
    await methodChannel.invokeMethod('stopClientObjectPostObservation', {
      'observationId': observationId,
    });
  }

  @override
  Future<Map<dynamic, dynamic>?> fetchCommunityData({
    String? profileId,
    String? clientUserId,
  }) async {
    return await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('fetchCommunityData', {
      'profileId': profileId,
      'clientUserId': clientUserId,
    });
  }

  @override
  Future<void> startCommunityDataObservation(
    String observationId, {
    String? profileId,
    String? clientUserId,
  }) async {
    await methodChannel.invokeMethod('startCommunityDataObservation', {
      'observationId': observationId,
      'profileId': profileId,
      'clientUserId': clientUserId,
    });
  }

  @override
  Future<void> stopCommunityDataObservation(String observationId) async {
    await methodChannel.invokeMethod('stopCommunityDataObservation', {
      'observationId': observationId,
    });
  }

  @override
  Future<void> trackCommunityAccess(bool hasAccess) async {
    await methodChannel.invokeMethod('trackCommunityAccess', {
      'hasAccess': hasAccess,
    });
  }

  @override
  Future<void> overrideDefaultLocale(Locale? locale) async {
    await methodChannel.invokeMethod('overrideDefaultLocale', {
      'languageCode': locale?.languageCode,
      'countryCode': locale?.countryCode,
    });
  }

  @override
  Future<void> trackCustomEvent(
      String name, Map<String, String> properties) async {
    await methodChannel.invokeMethod('trackCustomEvent', {
      'name': name,
      'properties': properties,
    });
  }

  @override
  Future<void> registerPushNotificationToken(String token) async {
    await methodChannel.invokeMethod('registerPushNotificationToken', {
      'token': token,
    });
  }

  @override
  Future<List<SyncFollowGroupResult>> syncFollowGroups(
      List<SyncFollowGroupAction> actions) async {
    if (actions.isEmpty) return const <SyncFollowGroupResult>[];

    final raw = await methodChannel.invokeMethod<List<dynamic>>(
      'syncFollowGroups',
      {
        'actions': actions
            .map((a) => {
                  'groupId': a.groupId,
                  'followed': a.followed,
                  'actionDateMs': a.actionDate.millisecondsSinceEpoch,
                })
            .toList(),
      },
    );

    if (raw == null) return const <SyncFollowGroupResult>[];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map((m) => SyncFollowGroupResult(
              groupId: m['groupId'] as String,
              status: SyncFollowGroupStatus.fromWire(m['status'] as String),
            ))
        .toList(growable: false);
  }

  @override
  Future<OctopusResult<List<OctopusGroup>, OctopusServerError>>
      fetchGroups() async {
    final raw =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>('fetchGroups');
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      final rawGroups = wire['groups'];
      final groups = <OctopusGroup>[
        if (rawGroups is List)
          for (final g in rawGroups.whereType<Map>()) OctopusGroup.fromWire(g),
      ];
      return OctopusSuccess<List<OctopusGroup>, OctopusServerError>(groups);
    }
    // fetchGroups never carries a typed business error (Android's <_, Nothing>);
    // the only failures are connection-level. We pass an errorParser that maps
    // unexpected typed payloads (e.g. from a future-platform skew) to a
    // [GroupFollowUnfollowUnknownError] so the result still type-checks — those
    // would surface as an [OctopusInvalidArguments]<OctopusServerError>.
    return OctopusResult.failureFromWire<OctopusServerError>(
      wire,
      (e) => GroupFollowUnfollowError.fromWire(e),
    );
  }

  @override
  Future<OctopusResult<void, GroupFollowUnfollowError>> followGroup(
      String groupId) async {
    final raw = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'followGroup',
      {'groupId': groupId},
    );
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, GroupFollowUnfollowError>(null);
    }
    return OctopusResult.failureFromWire<GroupFollowUnfollowError>(
      wire,
      GroupFollowUnfollowError.fromWire,
    );
  }

  @override
  Future<OctopusResult<void, GroupFollowUnfollowError>> unfollowGroup(
      String groupId) async {
    final raw = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'unfollowGroup',
      {'groupId': groupId},
    );
    final wire = raw ??
        const <String, dynamic>{
          'type': 'failure',
          'kind': 'statusError',
          'code': -1,
          'description': 'No response from the platform',
        };
    if (wire['type'] == 'success') {
      return OctopusSuccess<void, GroupFollowUnfollowError>(null);
    }
    return OctopusResult.failureFromWire<GroupFollowUnfollowError>(
      wire,
      GroupFollowUnfollowError.fromWire,
    );
  }
}
