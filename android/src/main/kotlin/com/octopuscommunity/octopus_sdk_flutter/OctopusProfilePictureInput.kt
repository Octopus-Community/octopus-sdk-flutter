package com.octopuscommunity.octopus_sdk_flutter

internal sealed class OctopusProfilePictureInput {
    data class Url(val value: String) : OctopusProfilePictureInput()
    data class Base64(val payload: String) : OctopusProfilePictureInput()

    companion object {
        // Any base64 data URI, parameters included (RFC 2397); the decoded bytes
        // are still checked as an image by the caller.
        private val dataUriPrefix = Regex("^data:[^,]*;base64,", RegexOption.IGNORE_CASE)

        fun parse(raw: String?): OctopusProfilePictureInput? {
            val value = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
            if (value.startsWith("http://", ignoreCase = true) ||
                value.startsWith("https://", ignoreCase = true)) {
                return Url(value)
            }
            val payload = value.replaceFirst(dataUriPrefix, "").filterNot { it.isWhitespace() }
            // Only synthesize entirely absent padding, like Android's Base64.DEFAULT.
            // Explicit incomplete padding remains invalid on both platforms.
            val alphabetCount = payload.count {
                it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it == '+' || it == '/'
            }
            val remainder = alphabetCount % 4
            val padding = if ('=' !in payload && remainder in 2..3) "=".repeat(4 - remainder) else ""
            return Base64(payload + padding)
        }
    }
}
