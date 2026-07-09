import 'package:flutter/foundation.dart' show immutable;

import 'octopus_prefilled_post.dart';

/// Info needed to open the Octopus post editor as an SDK entry point
/// (Bridge Share).
///
/// When [prefilledPost] is `null`, the editor opens empty — equivalent to the
/// regular in-SDK new-post flow. When non-null, the editor opens prefilled with
/// the provided text / image / group / CTA.
///
/// Mirrors the native `CreatePostScreenInfo` (a top-level type on Android; the
/// `OctopusInitialScreen.CreatePostScreenInfo` nested type on iOS).
@immutable
class CreatePostScreenInfo {
  /// The prefill payload, or `null` for an empty editor.
  final OctopusPrefilledPost? prefilledPost;

  /// Optional callback that signs this prefilled share so the server accepts
  /// its image in a community configured to forbid member pictures.
  ///
  /// Only needed for such communities: when the user publishes this prefilled
  /// share carrying an image, the SDK computes a SHA-256 `fingerprint` of the
  /// final content (text + CTA + image) and invokes this provider. Your backend
  /// must return a JWT (HS256, the same shared secret as your SSO tokens)
  /// carrying that value in its `bridge_fingerprint` claim. Return `null` when
  /// you cannot sign. Communities that allow member pictures don't need this —
  /// leave it unset; only register it for communities that actually require a
  /// signature.
  ///
  /// The provider must **complete** — return a token or `null`. A provider that
  /// never completes parks the publish until the editor is dismissed.
  ///
  /// It is scoped to **one** editor session: opening another editor (another
  /// [OctopusSDK.showOctopusCreatePostScreen]) supersedes it. Don't keep two
  /// prefilled-share editors in flight at once — if a second editor opens
  /// before the first one publishes, the first share would be sent unsigned.
  ///
  /// **Supported on both platforms** (Android → native
  /// `CreatePostScreenInfo.bridgeShareTokenProvider`; iOS → native
  /// `OctopusPrefilledPost.sign`, plugin pods `1.12.4`+). The `null`-reply
  /// behaviour differs slightly because of the native shapes: on Android a
  /// `null` sends the attempt unsigned and the server rejects the image, while
  /// the iOS native signer returns a non-optional token, so a `null` reply
  /// makes the iOS editor show a signing error and stay open. The outcome is
  /// the same for the intended use case (return a real JWT) — in both cases an
  /// unsigned image is not published to a pictures-off community.
  ///
  /// Excluded from [==] / [hashCode] (a function has no value identity),
  /// matching how the SDK treats its other callbacks.
  final Future<String?> Function(String fingerprint)? bridgeShareTokenProvider;

  /// Creates the create-post-screen entry info.
  const CreatePostScreenInfo({
    this.prefilledPost,
    this.bridgeShareTokenProvider,
  });

  /// The platform-channel representation handed to the native bridges.
  ///
  /// [bridgeShareTokenProvider] is intentionally absent — a function can't ride
  /// the channel. [OctopusSDK.showOctopusCreatePostScreen] registers it and
  /// passes a `requestId` instead, so the native editor can request a signature
  /// back over the event channel at publish time.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'prefilledPost': prefilledPost?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePostScreenInfo && other.prefilledPost == prefilledPost;

  @override
  int get hashCode => prefilledPost.hashCode;

  @override
  String toString() => 'CreatePostScreenInfo(prefilledPost: $prefilledPost, '
      'bridgeShareTokenProvider: '
      '${bridgeShareTokenProvider == null ? 'null' : 'set'})';
}
