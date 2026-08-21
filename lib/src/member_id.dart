/// How a member-scoped Octopus entry point identifies the member it is about.
///
/// **Internal — not exported from the package barrel.** The public types hold
/// their source privately and surface it as plain `String?` getters
/// (`clientUserId` / `profileId`), so this discriminator never appears in a
/// public signature.
///
/// Mirrors the iOS `OctopusInitialScreen.ActivityScreenInfo.Source` enum, which
/// is `package`-visible there for the same reason: the two named constructors
/// are the API, the discriminator is only the encoding.
enum MemberIdSource {
  /// The host app's own id for the member (the one passed to SSO
  /// `connectUser`), resolved to an Octopus profile through the
  /// `GetPublicProfile` client-user-id lookup. Requires the community to
  /// expose client user ids.
  clientUserId,

  /// The member's Octopus profile id — already resolved, needs no lookup.
  profileId,
}

/// The single wire encoding shared by **every** member-scoped entry point: the
/// `activity` initial screen and the `profile` one behind
/// `OctopusProfileScreen`.
///
/// Designed once and reused so both features decode through one shared helper
/// on each platform — `MemberId.fromMap` in `InitialScreenSpec.kt` and
/// `decodeMemberId` in the iOS `OctopusEmbeddedView.swift`.
///
/// The **only** producer of that payload, and therefore the one place the id is
/// normalized: [id] is trimmed, and an id left with nothing but whitespace
/// returns `null` — "no member". Both are needed because an id reaches a
/// lookup verbatim: `' cu-1 '` would be searched for with its padding and never
/// match, and `'  '` is not an id at all. Normalizing here rather than in each
/// bridge keeps the two native decoders identical to the ones they sit beside
/// (`post` / `group`), which likewise only reject a blank id and forward what
/// they were given.
///
/// Callers decide what `null` means for them: an absent `member` key, which
/// every decoder already reads as the entry point's own default (the connected
/// user's profile for `profile`, the main feed for `activity`).
Map<String, dynamic>? memberIdToMap(MemberIdSource source, String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return null;
  return <String, dynamic>{'source': source.name, 'id': trimmed};
}
