package com.octopuscommunity.octopus_sdk_flutter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import java.io.File

private const val TAG = "OctopusFlutterTheme"
private const val MAX_ENCODED_LENGTH = 12 * 1024 * 1024

/** 128px covers 24dp glyphs at high density; illustrations get a larger raster budget. */
internal fun iconMaxEdge(slot: String): Int =
    if (slot.startsWith("screenStates.") || slot.contains("empty", ignoreCase = true) ||
        slot == "gamification.rulesHeader" || slot == "logo") 1024 else 128

internal fun iconBytes(slot: String, source: String): ByteArray? = iconOrDefault(slot) {
    require(source.length <= MAX_ENCODED_LENGTH) { "Encoded image exceeds 12 MiB" }
    val payload = iconBase64Payload(source)
    Base64.decode(payload, Base64.DEFAULT).takeIf { it.isNotEmpty() }
}

internal fun iconBase64Payload(source: String): String =
    if (source.startsWith("data:")) source.substringAfter(',', "") else source

/** A failed slot must never prevent the rest of the theme from rendering. */
internal fun <T> iconOrDefault(slot: String, block: () -> T?): T? = try {
    block().also { if (it == null) Log.w(TAG, "Icon $slot could not be decoded; keeping the native default") }
} catch (e: Exception) {
    Log.w(TAG, "Icon $slot could not be decoded; keeping the native default", e)
    null
} catch (e: OutOfMemoryError) {
    Log.w(TAG, "Icon $slot exceeded available memory; keeping the native default", e)
    null
}

/** Two-pass decode; the injected operation also makes bounds/failure behavior JVM-testable. */
internal fun decodeBoundedIcon(slot: String, decode: (BitmapFactory.Options) -> Bitmap?): Bitmap? =
    iconOrDefault(slot) {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        decode(options)
        if (options.outWidth <= 0 || options.outHeight <= 0) return@iconOrDefault null
        val edge = maxOf(options.outWidth, options.outHeight)
        val maxEdge = iconMaxEdge(slot)
        var sample = 1
        while ((edge.toLong() + sample - 1) / sample > maxEdge) sample *= 2
        options.inSampleSize = sample
        options.inJustDecodeBounds = false
        options.inScaled = false
        decode(options)
    }

internal fun decodeIconSource(slot: String, source: String): Bitmap? = iconOrDefault(slot) {
    val bytes = iconBytes(slot, source) ?: return@iconOrDefault null
    decodeBoundedIcon(slot) { options -> BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) }
}

internal fun decodeIconFile(slot: String, path: String): Bitmap? = iconOrDefault(slot) {
    if (!File(path).isFile) return@iconOrDefault null
    decodeBoundedIcon(slot) { options -> BitmapFactory.decodeFile(path, options) }
}
