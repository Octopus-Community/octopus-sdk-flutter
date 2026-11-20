package com.octopuscommunity.octopus_sdk_flutter

import com.octopuscommunity.sdk.domain.model.OctopusLocalizedText
import java.util.Locale
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * The platform-channel code both bridges answer with when the native SDK refuses a per-language
 * text. Dart maps it back onto `OctopusLocalizedTextValidationError`.
 */
internal const val INVALID_LOCALIZED_TEXT = "INVALID_LOCALIZED_TEXT"

/**
 * Decodes the wire form of a Dart `OctopusLocalizedText` (`toMap()`), or `null` when [raw] is not
 * one:
 * - `{type: "autoTranslated", text}`
 * - `{type: "perLanguage", texts: [{language, text}, …], defaultLanguage}`
 *
 * The tags arrive as the app wrote them. The only conversion is [localeForTag], the same on iOS;
 * the native constructor then validates the texts and its verdict is final.
 *
 * @throws OctopusLocalizedText.ValidationError when the native SDK refuses a per-language text,
 *   or [OctopusLocalizedText.ValidationError.DuplicateLanguage] when two tags give the same
 *   [Locale] ([OctopusLocalizedText.ValidationError.EmptyLanguage] when that locale has no
 *   language): a `Map<Locale, String>` would otherwise keep only the last text.
 */
internal fun decodeLocalizedText(raw: Any?): OctopusLocalizedText? {
    val map = raw as? Map<*, *> ?: return null
    return when (map["type"] as? String) {
        "autoTranslated" -> (map["text"] as? String)?.let { OctopusLocalizedText.AutoTranslated(it) }
        "perLanguage" -> {
            val texts = LinkedHashMap<Locale, String>()
            (map["texts"] as? List<*>).orEmpty().forEach { entry ->
                val pair = entry as? Map<*, *> ?: return@forEach
                val language = pair["language"] as? String ?: return@forEach
                val text = pair["text"] as? String ?: return@forEach
                val locale = localeForTag(language)
                if (texts.put(locale, text) != null) {
                    // Tags without a language ("", "und", "x"…) all give Locale.ROOT: report what
                    // the native SDK reports for any of them, not a duplicate.
                    throw if (locale.language.isEmpty()) {
                        OctopusLocalizedText.ValidationError.EmptyLanguage
                    } else {
                        OctopusLocalizedText.ValidationError.DuplicateLanguage(languageCodeOf(locale))
                    }
                }
            }
            val defaultLanguage = localeForTag(map["defaultLanguage"] as? String ?: "")
            OctopusLocalizedText.PerLanguage(texts, defaultLanguage)
        }
        else -> null
    }
}

/**
 * The locale of a BCP-47 tag as the app wrote it: an underscore is read as a hyphen, then
 * [Locale.forLanguageTag] reads it. iOS does the same with `Locale(identifier:)`.
 */
internal fun localeForTag(tag: String): Locale = Locale.forLanguageTag(tag.replace('_', '-'))

/**
 * The code the native SDK builds for [locale] (`language[-Script][-REGION]`, Hebrew, Indonesian
 * and Yiddish under `he`, `id` and `yi`), used to name a duplicate the bridge catches before the
 * native check can see it.
 */
internal fun languageCodeOf(locale: Locale): String {
    val language = when (locale.language) {
        "iw" -> "he"
        "in" -> "id"
        "ji" -> "yi"
        else -> locale.language
    }
    return listOf(language, locale.script, locale.country).filter { it.isNotEmpty() }.joinToString("-")
}

/**
 * The `details` of an [INVALID_LOCALIZED_TEXT] error: the Dart
 * `OctopusLocalizedTextValidationErrorKind` name and the language code, when the kind has one.
 */
internal fun encodeLocalizedTextError(error: OctopusLocalizedText.ValidationError): Map<String, Any?> =
    when (error) {
        OctopusLocalizedText.ValidationError.EmptyTexts -> mapOf("kind" to "emptyTexts", "languageCode" to null)
        OctopusLocalizedText.ValidationError.EmptyLanguage -> mapOf("kind" to "emptyLanguage", "languageCode" to null)
        is OctopusLocalizedText.ValidationError.BlankText ->
            mapOf("kind" to "blankText", "languageCode" to error.languageCode)
        is OctopusLocalizedText.ValidationError.DuplicateLanguage ->
            mapOf("kind" to "duplicateLanguage", "languageCode" to error.languageCode)
        is OctopusLocalizedText.ValidationError.DefaultLanguageMissing ->
            mapOf("kind" to "defaultLanguageMissing", "languageCode" to error.languageCode)
    }

/**
 * The CTA label primitives the native `OctopusDestination.CreatePost` route takes: the code of the
 * default language (`null` when auto-translated) and the labels of the other languages as a compact
 * JSON object of code to label (`null` when there is none) — the form the native editor decodes.
 */
internal data class CtaLabelPrimitives(val label: String, val language: String?, val translations: String?)

internal fun OctopusLocalizedText.toCtaLabelPrimitives(): CtaLabelPrimitives = when (this) {
    is OctopusLocalizedText.AutoTranslated -> CtaLabelPrimitives(text, null, null)
    is OctopusLocalizedText.PerLanguage -> {
        val others = textsByLanguageCode.filterKeys { it != defaultLanguageCode }
        CtaLabelPrimitives(
            label = defaultText,
            language = defaultLanguageCode,
            translations = others.takeIf { it.isNotEmpty() }
                ?.let { JsonObject(it.mapValues { (_, label) -> JsonPrimitive(label) }).toString() },
        )
    }
}
