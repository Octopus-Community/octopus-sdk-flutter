package com.octopuscommunity.octopus_sdk_flutter

import android.net.Uri
import android.util.Log
import androidx.core.net.toUri

/**
 * How a member-scoped entry point identifies the member it is about.
 *
 * The single wire encoding shared by **every** member-scoped entry point —
 * `{source: "clientUserId"|"profileId", id: "..."}` — designed once on the Dart
 * side ([MemberIdSource] / `memberIdToMap` in `lib/src/member_id.dart`) and
 * decoded here by the one [fromMap] both [InitialScreenSpec.Activity] and
 * [InitialScreenSpec.Profile] call. The iOS bridge has the matching
 * `decodeMemberId` in `OctopusEmbeddedView.swift`.
 *
 * The two sources are mutually exclusive, mirroring the iOS
 * `OctopusInitialScreen.ActivityScreenInfo.Source` enum, and map onto the two
 * mutually exclusive id parameters the native destinations expose
 * (`userId` for an Octopus id, `clientUserId` for the host's own).
 */
data class MemberId(val source: Source, val id: String) {
    /** Which kind of id [id] is. */
    enum class Source {
        /**
         * The host app's own id for the member, resolved to an Octopus profile
         * through the SDK's `GetPublicProfile` client-user-id lookup. Requires
         * the community to expose client user ids.
         */
        CLIENT_USER_ID,

        /** The member's Octopus profile id — already resolved, needs no lookup. */
        PROFILE_ID,
    }

    companion object {
        /**
         * Decode a `{source, id}` map. Returns `null` when [raw] is not a map,
         * carries an unknown `source`, or has a missing / blank `id` — each
         * caller decides what an undecodable member means for it (fall back to
         * the main feed for [InitialScreenSpec.Activity], the connected user's
         * own profile for [InitialScreenSpec.Profile]).
         *
         * A pure decoder: a non-blank `id` is forwarded exactly as it arrived,
         * like the `post` / `group` ids below. Trimming — and treating a blank id
         * as no member at all — is the job of `memberIdToMap` in
         * `lib/src/member_id.dart`, the single producer of this payload. Do not
         * add normalization here: iOS trimming while this side did not is how the
         * same padded id came to resolve on one platform and miss on the other.
         */
        fun fromMap(raw: Any?): MemberId? {
            val map = raw as? Map<*, *> ?: return null
            val id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: return null
            val source = when (map["source"] as? String) {
                "clientUserId" -> Source.CLIENT_USER_ID
                "profileId" -> Source.PROFILE_ID
                else -> {
                    Log.w(
                        "MemberId",
                        "Unknown member source=${map["source"]} — ignoring the member"
                    )
                    return null
                }
            }
            return MemberId(source = source, id = id)
        }
    }
}

/**
 * Bridge-side representation of the Dart `OctopusInitialScreen` sealed class.
 * Decoded from the PlatformView `creationParams["initialScreen"]` map.
 *
 * Wire shape (Dart `OctopusInitialScreen.toMap()`):
 * - `{type: "mainFeed"}`
 * - `{type: "post", postId: "..."}`
 * - `{type: "group", groupId: "..."}`
 * - `{type: "activity", member: {source: ..., id: ...}}`
 * - `{type: "profile", member: <map|absent>}`
 * - `{type: "createPost", prefilledPost: <map|null>}`
 *
 * Unknown / malformed values fold to [MainFeed] — matches the iOS bridge
 * behavior where decoding errors silently fall back to the default screen.
 */
sealed class InitialScreenSpec {
    /** Default. Mount the SDK's main feed (with the feed selector). */
    data object MainFeed : InitialScreenSpec()

    /** Mount the post detail screen for [postId] in bridge mode. */
    data class Post(val postId: String) : InitialScreenSpec()

    /** Mount the group detail screen for [groupId] in bridge mode. */
    data class Group(val groupId: String) : InitialScreenSpec()

    /**
     * Mount the posts-only activity screen of the member named by [member]
     * (Unified Profile).
     *
     * No tab index rides on the wire: the native `OctopusDestination.Activity`
     * only honours `selectedTabIndex` for the connected-user entry (the home
     * floating button), and an id entry point that resolves to the connected
     * user lands per the SDK's own unseen-notifications rule. iOS's
     * `ActivityScreenInfo` exposes no tab index either, so there is nothing to
     * mirror.
     */
    data class Activity(val member: MemberId) : InitialScreenSpec()

    /**
     * Mount the profile screen of the member named by [member], or the connected
     * user's own **editable** profile when it is `null`.
     *
     * A non-null member always opens the read-only profile view, even when the
     * id happens to resolve to the connected user — that is the documented
     * contract of the native `ProfileSummary` destination, and matches iOS's
     * `OctopusProfileScreen(clientUserId:)`.
     *
     * A member carrying [MemberId.Source.PROFILE_ID] is **not reachable from the
     * current Dart API** (`OctopusInitialScreen.profile` takes only a
     * clientUserId) and the two bridges answer it differently: here
     * `ProfileSummary(userId=)` opens that member's profile, while iOS has no
     * by-Octopus-id profile view and opens that member's *activity* screen
     * instead. Each side does the closest thing its native SDK offers, which
     * holds only while nothing can reach the case. Adding
     * `OctopusInitialScreen.profile(profileId:)` means settling the two on one
     * behaviour first; `decodeInitialScreen` in the iOS `OctopusEmbeddedView.swift`
     * carries the same warning.
     */
    data class Profile(val member: MemberId?) : InitialScreenSpec()

    /**
     * Mount the post editor as the initial route.
     *
     * Image bytes carried under `createPost.prefilledPost.image` are
     * intentionally dropped on this embedded entry point — hosts that need
     * to share an image use `showOctopusCreatePostScreen`, which
     * materializes bytes via `OctopusCreatePostActivity`. Only the text,
     * topic, and CTA primitives reach the native editor here.
     */
    data class CreatePost(
        val text: String? = null,
        val topicId: String? = null,
        val ctaLabel: String? = null,
        val ctaUrl: Uri? = null,
    ) : InitialScreenSpec()

    companion object {
        /**
         * Decode an `initialScreen` map sent from Dart. Returns [MainFeed]
         * when [raw] is null, has no recognized `type`, or is malformed.
         *
         * Image bytes carried in `createPost.prefilledPost.image` are
         * **dropped** here — the embedded post editor entry point is not
         * expected to receive raw bytes (those go through
         * `showOctopusCreatePostScreen`, which materializes them via
         * `OctopusCreatePostActivity`). Hosts can still pass text / topicId
         * / CTA via the embedded route.
         */
        fun fromMap(raw: Any?): InitialScreenSpec {
            val map = raw as? Map<*, *> ?: return MainFeed
            return when (val type = map["type"] as? String) {
                "mainFeed", null -> MainFeed
                "post" -> {
                    val postId = (map["postId"] as? String)?.takeIf { it.isNotBlank() }
                    if (postId != null) Post(postId) else {
                        Log.w(TAG, "post: missing postId — falling back to mainFeed")
                        MainFeed
                    }
                }
                "group" -> {
                    val groupId = (map["groupId"] as? String)?.takeIf { it.isNotBlank() }
                    if (groupId != null) Group(groupId) else {
                        Log.w(TAG, "group: missing groupId — falling back to mainFeed")
                        MainFeed
                    }
                }
                "activity" -> {
                    val member = MemberId.fromMap(map["member"])
                    if (member != null) Activity(member) else {
                        // Unlike `profile`, this screen has no "connected user"
                        // meaning to fall back on — Dart always sends a member
                        // here, so an absent one is a malformed payload.
                        Log.w(TAG, "activity: missing member — falling back to mainFeed")
                        MainFeed
                    }
                }
                // An absent (or undecodable) member means the connected user's own
                // profile — the same meaning iOS gives
                // `OctopusProfileScreen(clientUserId: nil)`.
                "profile" -> Profile(MemberId.fromMap(map["member"]))
                "createPost" -> {
                    @Suppress("UNCHECKED_CAST")
                    val prefilled = map["prefilledPost"] as? Map<String, Any?>
                    if (prefilled == null) {
                        CreatePost()
                    } else {
                        val text = prefilled["text"] as? String
                        val topicId = prefilled["topicId"] as? String
                        @Suppress("UNCHECKED_CAST")
                        val cta = prefilled["cta"] as? Map<String, Any?>
                        val ctaLabel = cta?.get("label") as? String
                        val ctaUrlString = cta?.get("url") as? String
                        val ctaUrl = ctaUrlString?.let { runCatching { it.toUri() }.getOrNull() }
                        CreatePost(
                            text = text,
                            topicId = topicId,
                            ctaLabel = ctaLabel,
                            ctaUrl = ctaUrl,
                        )
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown initialScreen type=$type — falling back to mainFeed")
                    MainFeed
                }
            }
        }

        private const val TAG = "InitialScreenSpec"
    }
}
