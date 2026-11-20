package com.octopuscommunity.octopus_sdk_flutter

import com.octopuscommunity.sdk.domain.model.OctopusLocalizedText
import java.io.File
import java.nio.file.Files
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertNull
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The per-language button labels through the bridge: the wire `OctopusLocalizedText`, the native
 * validation errors sent back to Dart, and the three entry points that carry a label (client post,
 * create-post activity, embedded create-post route). Robolectric gives the real `Uri`; how to run
 * them is in OctopusSDKFlutterPluginTest.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class LocalizedTextWireTest {
    private val context = RuntimeEnvironment.getApplication()
    private val cacheDir: File = Files.createTempDirectory("octopus-localized-text-test").toFile()

    @After
    fun tearDown() {
        cacheDir.deleteRecursively()
    }

    private fun perLanguage(vararg texts: Pair<String, String>, defaultLanguage: String) = mapOf(
        "type" to "perLanguage",
        "texts" to texts.map { (language, text) -> mapOf("language" to language, "text" to text) },
        "defaultLanguage" to defaultLanguage,
    )

    @Test
    fun autoTranslated_decodesToTheNativeAutoTranslated() {
        assertEquals(
            OctopusLocalizedText.AutoTranslated("Read"),
            decodeLocalizedText(mapOf("type" to "autoTranslated", "text" to "Read")),
        )
    }

    @Test
    fun perLanguage_buildsLocalesFromTheTags_scriptIncluded() {
        val label = decodeLocalizedText(
            perLanguage("en" to "Read", "zh-Hant-TW" to "閱讀", "pt-BR" to "Ler", defaultLanguage = "en"),
        )
        assertIs<OctopusLocalizedText.PerLanguage>(label)
        assertEquals("en", label.defaultLanguageCode)
        assertEquals(
            mapOf("en" to "Read", "zh-Hant-TW" to "閱讀", "pt-BR" to "Ler"),
            label.textsByLanguageCode,
        )
        assertEquals(Locale.forLanguageTag("zh-Hant-TW"), label.texts.keys.elementAt(1))
    }

    @Test
    fun anUnderscore_isReadAsAHyphen() {
        val label = decodeLocalizedText(
            perLanguage("pt_BR" to "Ler", "zh_Hant_TW" to "閱讀", defaultLanguage = "pt_BR"),
        )
        assertIs<OctopusLocalizedText.PerLanguage>(label)
        assertEquals("pt-BR", label.defaultLanguageCode)
        assertEquals(mapOf("pt-BR" to "Ler", "zh-Hant-TW" to "閱讀"), label.textsByLanguageCode)
        assertEquals(Locale.forLanguageTag("pt-BR"), localeForTag("pt_BR"))
    }

    @Test
    fun twoTagsOfOneLocale_areADuplicate_neverADroppedText() {
        val error = assertFailsWith<OctopusLocalizedText.ValidationError.DuplicateLanguage> {
            decodeLocalizedText(perLanguage("en-US" to "Read", "en_us" to "Read it", defaultLanguage = "en-US"))
        }
        assertEquals("en-US", error.languageCode)
        assertEquals(mapOf("kind" to "duplicateLanguage", "languageCode" to "en-US"), encodeLocalizedTextError(error))
    }

    @Test
    fun undeterminedLanguage_isEmptyLanguage() {
        listOf("und", "und_FR").forEach { tag ->
            assertFailsWith<OctopusLocalizedText.ValidationError.EmptyLanguage>(tag) {
                decodeLocalizedText(perLanguage(tag to "Read", "en" to "Read", defaultLanguage = "en"))
            }
        }
    }

    @Test
    fun tagsWithoutALanguage_areEmptyLanguage_notADuplicate() {
        val error = assertFailsWith<OctopusLocalizedText.ValidationError> {
            decodeLocalizedText(perLanguage("" to "a", "und" to "b", "en" to "c", defaultLanguage = "en"))
        }
        assertEquals(OctopusLocalizedText.ValidationError.EmptyLanguage, error)
        assertEquals(mapOf("kind" to "emptyLanguage", "languageCode" to null), encodeLocalizedTextError(error))
    }

    @Test
    fun languageCodeOf_matchesTheNativeCode() {
        assertEquals("zh-Hant-TW", languageCodeOf(localeForTag("zh-Hant-TW")))
        assertEquals("he-IL", languageCodeOf(localeForTag("iw_IL")))
    }

    @Test
    fun noLabel_decodesToNull() {
        assertNull(decodeLocalizedText(null))
        assertNull(decodeLocalizedText(mapOf("type" to "somethingNew")))
    }

    @Test
    fun aNativeRefusal_isEncodedWithItsKindAndLanguage() {
        val error = assertFailsWith<OctopusLocalizedText.ValidationError> {
            decodeLocalizedText(perLanguage("en" to "Read", defaultLanguage = "fr"))
        }
        assertEquals(mapOf("kind" to "defaultLanguageMissing", "languageCode" to "fr"), encodeLocalizedTextError(error))

        // Hebrew under its old and current codes: two locales, one code.
        val duplicate = assertFailsWith<OctopusLocalizedText.ValidationError> {
            decodeLocalizedText(perLanguage("iw" to "צפה", "he" to "צפה", defaultLanguage = "he"))
        }
        assertEquals(mapOf("kind" to "duplicateLanguage", "languageCode" to "he"), encodeLocalizedTextError(duplicate))
    }

    @Test
    fun everyNativeKind_hasItsDartName() {
        assertEquals(
            listOf("emptyTexts", "emptyLanguage", "blankText", "duplicateLanguage", "defaultLanguageMissing"),
            listOf(
                OctopusLocalizedText.ValidationError.EmptyTexts,
                OctopusLocalizedText.ValidationError.EmptyLanguage,
                OctopusLocalizedText.ValidationError.BlankText("en"),
                OctopusLocalizedText.ValidationError.DuplicateLanguage("en"),
                OctopusLocalizedText.ValidationError.DefaultLanguageMissing("en"),
            ).map { encodeLocalizedTextError(it)["kind"] },
        )
    }

    @Test
    fun ctaLabelPrimitives_carryTheOtherLanguagesAsJson() {
        val label = decodeLocalizedText(perLanguage("en" to "Read", "fr" to "Lire", defaultLanguage = "en"))!!
        assertEquals(CtaLabelPrimitives("Read", "en", """{"fr":"Lire"}"""), label.toCtaLabelPrimitives())
        assertEquals(
            CtaLabelPrimitives("Read", null, null),
            OctopusLocalizedText.AutoTranslated("Read").toCtaLabelPrimitives(),
        )
    }

    @Test
    fun clientPost_takesThePerLanguageButton() {
        val decoded = OctopusSDKFlutterPlugin().decodeClientPost(
            mapOf(
                "objectId" to "obj-1",
                "text" to "Some bridge post text",
                "viewObjectButton" to perLanguage("en" to "View", "fr" to "Voir", defaultLanguage = "fr"),
            ),
            cacheDir,
        )
        val button = assertIs<OctopusLocalizedText.PerLanguage>(decoded.clientPost.viewObjectButton)
        assertEquals("fr", button.defaultLanguageCode)
        assertEquals("Voir", decoded.clientPost.viewObjectButtonText)
    }

    @Test
    fun clientPost_legacyAttachment_keepsTheButton() {
        val decoded = OctopusSDKFlutterPlugin().decodeClientPost(
            mapOf(
                "objectId" to "obj-1",
                "text" to "Some bridge post text",
                "attachment" to mapOf("type" to "remoteImage", "url" to "https://example.com/a.jpg"),
                "viewObjectButton" to mapOf("type" to "autoTranslated", "text" to "View"),
            ),
            cacheDir,
        )
        assertEquals(OctopusLocalizedText.AutoTranslated("View"), decoded.clientPost.viewObjectButton)
        @Suppress("DEPRECATION")
        assertEquals(1, listOfNotNull(decoded.clientPost.attachment).size)
    }

    @Test
    fun createPostIntent_carriesThePerLanguageCtaLabel() {
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf(
                "prefilledPost" to mapOf(
                    "cta" to mapOf(
                        "url" to "https://example.com/a",
                        "label" to "Read",
                        "localizedLabel" to perLanguage("en" to "Read", "fr" to "Lire", defaultLanguage = "en"),
                    ),
                ),
            ),
        )
        val cta = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!.cta!!
        assertEquals("Read", cta.label)
        val label = assertIs<OctopusLocalizedText.PerLanguage>(cta.localizedLabel)
        assertEquals(mapOf("en" to "Read", "fr" to "Lire"), label.textsByLanguageCode)
    }

    @Test
    fun createPostIntent_prefersAutoTranslatedLocalizedLabelToLegacyLabel() {
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf(
                "prefilledPost" to mapOf(
                    "cta" to mapOf(
                        "url" to "https://example.com/a",
                        "label" to "Legacy label",
                        "localizedLabel" to mapOf("type" to "autoTranslated", "text" to "Localized label"),
                    ),
                ),
            ),
        )
        val cta = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!.cta!!
        assertEquals(OctopusLocalizedText.AutoTranslated("Localized label"), cta.localizedLabel)
    }

    @Test
    fun createPostIntent_refusedLabel_dropsTheCtaOnly() {
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf(
                "prefilledPost" to mapOf(
                    "text" to "A prefilled text",
                    "cta" to mapOf(
                        "url" to "https://example.com/a",
                        "label" to "Read",
                        "localizedLabel" to perLanguage("en" to "Read", defaultLanguage = "fr"),
                    ),
                ),
            ),
        )
        val prefilled = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!
        assertEquals("A prefilled text", prefilled.text)
        assertNull(prefilled.cta)
    }

    @Test
    fun createPostIntent_plainLabel_staysAutoTranslated() {
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf("prefilledPost" to mapOf("cta" to mapOf("url" to "https://example.com/a", "label" to "Read"))),
        )
        val cta = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!.cta!!
        assertEquals(OctopusLocalizedText.AutoTranslated("Read"), cta.localizedLabel)
    }

    @Test
    fun embeddedCreatePost_carriesTheLabelPrimitives() {
        val spec = InitialScreenSpec.fromMap(
            mapOf(
                "type" to "createPost",
                "prefilledPost" to mapOf(
                    "cta" to mapOf(
                        "url" to "https://example.com/a",
                        "label" to "Read",
                        "localizedLabel" to perLanguage("en" to "Read", "fr" to "Lire", defaultLanguage = "en"),
                    ),
                ),
            ),
        )
        val createPost = assertIs<InitialScreenSpec.CreatePost>(spec)
        assertEquals("Read", createPost.ctaLabel)
        assertEquals("en", createPost.ctaLabelLanguage)
        assertEquals("""{"fr":"Lire"}""", createPost.ctaLabelTranslations)
    }

    @Test
    fun embeddedCreatePost_refusedLabel_dropsTheCta() {
        val spec = InitialScreenSpec.fromMap(
            mapOf(
                "type" to "createPost",
                "prefilledPost" to mapOf(
                    "cta" to mapOf(
                        "url" to "https://example.com/a",
                        "label" to "Read",
                        "localizedLabel" to perLanguage("en" to "Read", defaultLanguage = "fr"),
                    ),
                ),
            ),
        )
        val createPost = assertIs<InitialScreenSpec.CreatePost>(spec)
        assertNull(createPost.ctaLabel)
        assertNull(createPost.ctaLabelLanguage)
    }
}
