package com.octopuscommunity.octopus_sdk_flutter

import android.net.Uri
import android.util.Log
import androidx.core.net.toUri

/**
 * Bridge-side representation of the Dart `OctopusInitialScreen` sealed class.
 * Decoded from the PlatformView `creationParams["initialScreen"]` map.
 *
 * Wire shape (Dart `OctopusInitialScreen.toMap()`):
 * - `{type: "mainFeed"}`
 * - `{type: "post", postId: "..."}`
 * - `{type: "group", groupId: "..."}`
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
