package com.octopuscommunity.octopus_sdk_flutter

import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.util.Log
import com.octopuscommunity.sdk.domain.model.Resource
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito

internal class OctopusProfilePictureInputTest {
    // android.net.Uri is a stub on the JVM; answer parse() with a mock carrying the given host.
    private fun <T> withUriHost(host: String?, block: () -> T): T =
        Mockito.mockStatic(Uri::class.java).use { uri ->
            val parsed = Mockito.mock(Uri::class.java)
            Mockito.`when`(parsed.host).thenReturn(host)
            uri.`when`<Uri> { Uri.parse(Mockito.anyString()) }.thenReturn(parsed)
            block()
        }

    @Test fun onlyHttpAndHttpsAreUrlsRegardlessOfCase() {
        val plugin = OctopusSDKFlutterPlugin()
        for (url in listOf("http://example.com/a.png", "HTTPS://example.com/a.png", "hTtPs://example.com/a.png")) {
            assertEquals(Resource.Remote(url), withUriHost("example.com") { plugin.toSdkImage(" \n$url\t ") })
        }
        for (input in listOf("http-not-a-url", "httpx://example.com/a.png", "ftp://example.com/a.png")) {
            assertEquals(false, OctopusProfilePictureInput.parse(input) is OctopusProfilePictureInput.Url)
        }
    }

    @Test fun rawAndDataUriBase64DecodeIdenticallyWithMissingPaddingAndLineBreaks() {
        for (input in listOf(
            "YWJjZA==", "YWJjZA", " \nYWJj\r\nZA\t ",
            "data:image/png;base64,YWJjZA==", " DATA:IMAGE/JPEG;BASE64,YWJj\nZA ",
            "data:application/octet-stream;base64,YWJjZA==", "data:image/png;charset=utf-8;base64,YWJjZA",
        )) {
            val parsed = OctopusProfilePictureInput.parse(input) as OctopusProfilePictureInput.Base64
            // The JVM has no Android decoder; validate the normalized payload with a strict one.
            assertContentEquals("abcd".toByteArray(), java.util.Base64.getDecoder().decode(parsed.payload))
        }
        assertEquals(OctopusProfilePictureInput.Base64("YWJjZA="), OctopusProfilePictureInput.parse("YWJjZA="))
        assertNull(OctopusProfilePictureInput.parse(null))
        assertNull(OctopusProfilePictureInput.parse(" \r\n\t "))
    }

    @Test fun urlWithoutHostLogsOnceAndReturnsNoPicture() {
        for (host in listOf(null, "")) {
            withUriHost(host) {
                Mockito.mockStatic(Log::class.java).use { log ->
                    assertNull(OctopusSDKFlutterPlugin().toSdkImage("http://"))
                    log.verify { Log.w("OctopusSDK", "Profile picture URL is invalid; connecting without a picture.") }
                    log.verifyNoMoreInteractions()
                }
            }
        }
    }

    @Test fun malformedBase64LogsOnceAndReturnsNoPicture() {
        Mockito.mockStatic(Base64::class.java).use { base64 ->
            base64.`when`<ByteArray> { Base64.decode("Y", Base64.DEFAULT) }
                .thenThrow(IllegalArgumentException("Invalid base64"))
            Mockito.mockStatic(Log::class.java).use { log ->
                assertNull(OctopusSDKFlutterPlugin().toSdkImage(" Y "))
                log.verify { Log.w("OctopusSDK", "Profile picture could not be decoded; connecting without a picture.") }
                log.verifyNoMoreInteractions()
            }
        }
    }

    @Test fun decodedNonImageLogsOnceAndReturnsNoPicture() {
        val bytes = "abcd".toByteArray()
        Mockito.mockStatic(Base64::class.java).use { base64 ->
            base64.`when`<ByteArray> { Base64.decode("YWJjZA==", Base64.DEFAULT) }.thenReturn(bytes)
            Mockito.mockStatic(BitmapFactory::class.java).use { bitmapFactory ->
                Mockito.mockStatic(Log::class.java).use { log ->
                    assertNull(OctopusSDKFlutterPlugin().toSdkImage("data:image/png;base64,YWJj\nZA"))
                    bitmapFactory.verify { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
                    log.verify { Log.w("OctopusSDK", "Profile picture could not be decoded; connecting without a picture.") }
                    log.verifyNoMoreInteractions()
                }
            }
        }
    }
}
