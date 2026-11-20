package com.octopuscommunity.octopus_sdk_flutter

import com.octopuscommunity.sdk.domain.model.Resource
import java.io.File
import java.nio.file.Files
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The several photos a post carries, through both bridge entry points: the prefilled images of the
 * create-post activity, and the medias of a client post. Robolectric gives the real `Uri` and a
 * cache directory; how to run them is in OctopusSDKFlutterPluginTest.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class MultiPhotoBridgeTest {
    private val context = RuntimeEnvironment.getApplication()
    private val cacheDir: File = Files.createTempDirectory("octopus-bridge-test").toFile()

    @After
    fun tearDown() {
        cacheDir.deleteRecursively()
    }

    @Test
    fun createPostIntent_carriesEachNonEmptyImageAsItsOwnFile_inOrder() {
        val first = byteArrayOf(1, 2, 3)
        val second = byteArrayOf(4, 5)
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf("prefilledPost" to mapOf("text" to "A prefilled text", "images" to listOf(first, ByteArray(0), second)))
        )

        val prefilled = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!

        assertEquals("A prefilled text", prefilled.text)
        val files = prefilled.images.map { File(it.path!!) }
        assertEquals(2, files.size)
        assertEquals(2, files.toSet().size)
        assertContentEquals(first, files[0].readBytes())
        assertContentEquals(second, files[1].readBytes())

        OctopusCreatePostActivity.cleanupPrefilledImageFiles(intent)
        assertTrue(files.none { it.exists() })
    }

    @Test
    fun createPostIntent_withoutPrefill_buildsNoPrefilledPost() {
        val intent = OctopusCreatePostActivity.newIntent(context, mapOf("prefilledPost" to null))
        assertNull(OctopusCreatePostActivity.prefilledPostFromIntent(intent))
        // Nothing to clean, and cleaning must not fail.
        OctopusCreatePostActivity.cleanupPrefilledImageFiles(intent)
    }

    @Test
    fun createPostIntent_imagesOnly_buildsAPrefilledPost() {
        val intent = OctopusCreatePostActivity.newIntent(
            context,
            mapOf("prefilledPost" to mapOf("images" to listOf(byteArrayOf(1))))
        )
        try {
            val prefilled = OctopusCreatePostActivity.prefilledPostFromIntent(intent)!!
            assertNull(prefilled.text)
            assertEquals(1, prefilled.images.size)
        } finally {
            OctopusCreatePostActivity.cleanupPrefilledImageFiles(intent)
        }
    }

    @Test
    fun decodeClientPost_mapsMediasInOrder_andDeletesTheirFilesAfterwards() {
        val bytes = byteArrayOf(9, 8, 7)
        val decoded = OctopusSDKFlutterPlugin().decodeClientPost(
            mapOf(
                "objectId" to "obj-1",
                "text" to "Some bridge post text",
                "attachment" to null,
                "medias" to listOf(
                    mapOf("type" to "remoteImage", "url" to "https://example.com/a.jpg"),
                    mapOf("type" to "localImage", "bytes" to bytes),
                ),
            ),
            cacheDir,
        )

        val medias = decoded.clientPost.medias
        assertEquals(2, medias.size)
        assertEquals(Resource.Remote(url = "https://example.com/a.jpg"), medias[0])
        val local = medias[1] as Resource.Local
        val file = File(local.uri.path!!)
        assertContentEquals(bytes, file.readBytes())
        assertEquals(listOf(file.absoluteFile), decoded.tempFiles.map { it.absoluteFile })
        @Suppress("DEPRECATION")
        assertNull(decoded.clientPost.attachment)

        decoded.deleteTempFiles()
        assertTrue(cacheDir.listFiles().orEmpty().isEmpty())
    }

    @Test
    fun decodeClientPost_legacyAttachment_staysTheNativeAttachment() {
        val decoded = OctopusSDKFlutterPlugin().decodeClientPost(
            mapOf(
                "objectId" to "obj-1",
                "text" to "Some bridge post text",
                "attachment" to mapOf("type" to "remoteImage", "url" to "https://example.com/a.jpg"),
                "medias" to emptyList<Any>(),
            ),
            cacheDir,
        )

        @Suppress("DEPRECATION")
        assertEquals(Resource.Remote(url = "https://example.com/a.jpg"), decoded.clientPost.attachment)
        assertTrue(decoded.clientPost.medias.isEmpty())
    }

    @Test
    fun decodeClientPost_attachmentAndMedias_isRefused_withoutLeavingFiles() {
        assertFailsWith<IllegalArgumentException> {
            OctopusSDKFlutterPlugin().decodeClientPost(
                mapOf(
                    "objectId" to "obj-1",
                    "text" to "Some bridge post text",
                    "attachment" to mapOf("type" to "localImage", "bytes" to byteArrayOf(1)),
                    "medias" to listOf(mapOf("type" to "localImage", "bytes" to byteArrayOf(2))),
                ),
                cacheDir,
            )
        }
        assertTrue(cacheDir.listFiles().orEmpty().isEmpty())
    }
}
