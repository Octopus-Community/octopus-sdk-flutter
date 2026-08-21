import 'dart:ui' show Locale;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'api_server.dart';
import 'client_post.dart';
import 'client_post_error.dart';
import 'client_user_error.dart';
import 'content_options.dart';
import 'group_follow_unfollow_error.dart';
import 'octopus_group.dart';
import 'octopus_post.dart';
import 'octopus_reaction_kind.dart';
import 'octopus_result.dart';
import 'override_community_access_error.dart';
import 'refresh_entitlements_error.dart';
import 'set_reaction_error.dart';
import 'profile_field.dart';
import 'profile_fields_lock.dart';
import 'sync_follow_group.dart';
import 'terms_acceptance_mode.dart';
import 'octopus_sdk_method_channel.dart';

abstract class OctopusSDKPlatform extends PlatformInterface {
  /// Constructs a OctopusSDKPlatform.
  OctopusSDKPlatform() : super(token: _token);

  static final Object _token = Object();

  static OctopusSDKPlatform _instance = OctopusSDKMethodChannel();

  /// The default instance of [OctopusSDKPlatform] to use.
  ///
  /// Defaults to [OctopusSDKMethodChannel].
  static OctopusSDKPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OctopusSDKPlatform] when
  /// they register themselves.
  static set instance(OctopusSDKPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) {
    throw UnimplementedError(
      'initialize() has not been implemented.',
    );
  }

  Future<void> initializeOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) {
    throw UnimplementedError(
      'initializeOctopusAuth() has not been implemented.',
    );
  }

  Future<void> switchCommunity({
    required String apiKey,
    List<ProfileField>? appManagedFields,
    ApiServer? apiServer,
  }) {
    throw UnimplementedError('switchCommunity() has not been implemented.');
  }

  Future<void> switchCommunityOctopusAuth({
    required String apiKey,
    String? deepLink,
    ApiServer? apiServer,
  }) {
    throw UnimplementedError(
      'switchCommunityOctopusAuth() has not been implemented.',
    );
  }

  Future<void> reset() {
    throw UnimplementedError('reset() has not been implemented.');
  }

  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  Future<OctopusResult<void, ClientUserError>> connectUser(
      {required String userId,
      required String token,
      String? nickname,
      String? bio,
      String? picture}) {
    throw UnimplementedError('connectUser() has not been implemented.');
  }

  /// Connect with a persistent tokenProvider: the native SDK invokes Dart back
  /// over the event channel ([providerId] keys the closure on Dart) every time
  /// it needs a fresh user JWT (initial connect, [refreshEntitlements], …). The
  /// reply path is [provideClientUserToken].
  Future<OctopusResult<void, ClientUserError>> connectUserWithTokenProvider({
    required String userId,
    required String providerId,
    String? nickname,
    String? bio,
    String? picture,
  }) {
    throw UnimplementedError(
      'connectUserWithTokenProvider() has not been implemented.',
    );
  }

  /// Replies to a native `clientUserTokenRequest` with the freshly-signed JWT.
  /// An empty string is the bridges' "no token available" signal (mirrors the
  /// `provideBridgeToken` null-reply contract for create-post bridges). What it
  /// produces is platform-dependent: Android refuses an empty token locally,
  /// as `ClientUserMissingTokenError`, while iOS does not inspect it and
  /// forwards it to the backend token exchange, so the failure comes back from
  /// that call and can be a connection-level `OctopusStatusError` rather than a
  /// `ClientUserError` — or not come back at all: on a first connect the native
  /// iOS SDK falls back to a guest connection, and `connectUser` then reports
  /// success (see MIGRATING.md).
  Future<void> provideClientUserToken(String requestId, String token) {
    throw UnimplementedError(
      'provideClientUserToken() has not been implemented.',
    );
  }

  Future<void> disconnectUser() {
    throw UnimplementedError('disconnectUser() has not been implemented.');
  }

  Future<void> showCreatePostScreen(Map<String, dynamic> args) {
    throw UnimplementedError(
      'showCreatePostScreen() has not been implemented.',
    );
  }

  Future<void> updateNotSeenNotificationsCount() {
    throw UnimplementedError(
      'updateNotSeenNotificationsCount() has not been implemented.',
    );
  }

  Future<OctopusResult<void, OverrideCommunityAccessError>>
      overrideCommunityAccess(bool hasAccess) {
    throw UnimplementedError(
      'overrideCommunityAccess() has not been implemented.',
    );
  }

  Future<OctopusResult<void, RefreshEntitlementsError>> refreshEntitlements() {
    throw UnimplementedError(
      'refreshEntitlements() has not been implemented.',
    );
  }

  Future<OctopusResult<void, SetReactionError>> setReaction(
    OctopusReactionKind? reaction,
    String postId,
  ) {
    throw UnimplementedError('setReaction() has not been implemented.');
  }

  Future<OctopusResult<OctopusPost, ClientPostError>>
      fetchOrCreateClientObjectRelatedPost(
    ClientPost clientPost, {
    required String requestId,
    required bool hasTokenProvider,
  }) {
    throw UnimplementedError(
      'fetchOrCreateClientObjectRelatedPost() has not been implemented.',
    );
  }

  /// Replies to a native `bridgeTokenRequest` with the resolved [token] (or
  /// `null`). Always called by the SDK in response to a request — the explicit
  /// null-reply contract the native side waits on.
  Future<void> provideBridgeToken(String requestId, String? token) {
    throw UnimplementedError('provideBridgeToken() has not been implemented.');
  }

  /// Starts a native observation of the post linked to [clientObjectId],
  /// emitting `clientObjectPostChanged` events tagged with [observationId].
  Future<void> startClientObjectPostObservation(
      String observationId, String clientObjectId) {
    throw UnimplementedError(
      'startClientObjectPostObservation() has not been implemented.',
    );
  }

  /// Stops the native observation identified by [observationId].
  Future<void> stopClientObjectPostObservation(String observationId) {
    throw UnimplementedError(
      'stopClientObjectPostObservation() has not been implemented.',
    );
  }

  /// Fetches a member's community-data snapshot. Exactly one of [profileId] /
  /// [clientUserId] is non-null. Returns the wire map, or `null` when the member
  /// is unknown.
  Future<Map<dynamic, dynamic>?> fetchCommunityData({
    String? profileId,
    String? clientUserId,
  }) {
    throw UnimplementedError('fetchCommunityData() has not been implemented.');
  }

  /// Starts a native observation of a member's community data, emitting
  /// `communityDataChanged` events tagged with [observationId]. Exactly one of
  /// [profileId] / [clientUserId] is non-null.
  Future<void> startCommunityDataObservation(
    String observationId, {
    String? profileId,
    String? clientUserId,
  }) {
    throw UnimplementedError(
      'startCommunityDataObservation() has not been implemented.',
    );
  }

  /// Stops the community-data observation identified by [observationId].
  Future<void> stopCommunityDataObservation(String observationId) {
    throw UnimplementedError(
      'stopCommunityDataObservation() has not been implemented.',
    );
  }

  Future<void> trackCommunityAccess(bool hasAccess) {
    throw UnimplementedError(
      'trackCommunityAccess() has not been implemented.',
    );
  }

  Future<void> overrideDefaultLocale(Locale? locale) {
    throw UnimplementedError(
      'overrideDefaultLocale() has not been implemented.',
    );
  }

  Future<void> debugOverrideProfileFieldsLock(ProfileFieldsLock? lock) {
    throw UnimplementedError(
      'debugOverrideProfileFieldsLock() has not been implemented.',
    );
  }

  Future<void> debugOverrideContentOptions(ContentOptions? options) {
    throw UnimplementedError(
      'debugOverrideContentOptions() has not been implemented.',
    );
  }

  Future<void> debugOverrideTermsAcceptanceMode(TermsAcceptanceMode? mode) {
    throw UnimplementedError(
      'debugOverrideTermsAcceptanceMode() has not been implemented.',
    );
  }

  Future<void> trackCustomEvent(String name, Map<String, String> properties) {
    throw UnimplementedError(
      'trackCustomEvent() has not been implemented.',
    );
  }

  Future<void> registerPushNotificationToken(String token) {
    throw UnimplementedError(
      'registerPushNotificationToken() has not been implemented.',
    );
  }

  Future<List<SyncFollowGroupResult>> syncFollowGroups(
      List<SyncFollowGroupAction> actions) {
    throw UnimplementedError('syncFollowGroups() has not been implemented.');
  }

  Future<OctopusResult<List<OctopusGroup>, OctopusServerError>> fetchGroups() {
    throw UnimplementedError('fetchGroups() has not been implemented.');
  }

  Future<OctopusResult<void, GroupFollowUnfollowError>> followGroup(
      String groupId) {
    throw UnimplementedError('followGroup() has not been implemented.');
  }

  Future<OctopusResult<void, GroupFollowUnfollowError>> unfollowGroup(
      String groupId) {
    throw UnimplementedError('unfollowGroup() has not been implemented.');
  }
}
