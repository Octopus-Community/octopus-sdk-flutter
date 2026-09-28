package com.octopuscommunity.octopus_sdk_flutter

import android.graphics.Bitmap
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue
import org.mockito.Mockito

internal class OctopusIconDecoderTest {
    @Test fun base64AndDataUrisHaveIdenticalPayloads() {
        assertEquals("AQID", iconBase64Payload("AQID"))
        assertEquals("AQID", iconBase64Payload("data:image/png;base64,AQID"))
        assertEquals("", iconBase64Payload("data:image/png;base64"))
    }

    @Test fun glyphsAreDownsampledAfterBoundsPass() {
        val bitmap = Mockito.mock(Bitmap::class.java)
        var passes = 0
        val result = decodeBoundedIcon("common.activityButton") { options ->
            passes++
            if (options.inJustDecodeBounds) {
                options.outWidth = 4000
                options.outHeight = 3000
                null
            } else {
                assertEquals(32, options.inSampleSize)
                assertFalse(options.inScaled)
                bitmap
            }
        }
        assertEquals(2, passes)
        assertSame(bitmap, result)
    }

    @Test fun illustrationsKeepMoreResolutionThanGlyphs() {
        assertEquals(1024, iconMaxEdge("screenStates.emptyContent"))
        assertEquals(128, iconMaxEdge("content.reaction.heart"))
        decodeBoundedIcon("screenStates.emptyContent") { options ->
            if (options.inJustDecodeBounds) {
                options.outWidth = 4000
                options.outHeight = 3000
            } else {
                assertEquals(4, options.inSampleSize)
            }
            null
        }
    }

    @Test fun smallImagesAreNotUpscaled() {
        decodeBoundedIcon("common.moreActions") { options ->
            if (options.inJustDecodeBounds) {
                options.outWidth = 24
                options.outHeight = 24
            } else {
                assertEquals(1, options.inSampleSize)
            }
            null
        }
    }

    @Test fun invalidBoundsNeverReachPixelDecode() {
        var calls = 0
        assertNull(decodeBoundedIcon("common.moreActions") { options ->
            calls++
            assertTrue(options.inJustDecodeBounds)
            options.outWidth = -1
            options.outHeight = -1
            null
        })
        assertEquals(1, calls)
    }

    @Test fun oomAndMalformedImagesFallBackWithoutEscaping() {
        assertNull(decodeBoundedIcon("content.reaction.heart") { throw OutOfMemoryError("test") })
        assertNull(decodeBoundedIcon("common.radio.off") { throw IllegalArgumentException("test") })
        var calls = 0
        assertNull(decodeBoundedIcon("common.radio.on") { options ->
            calls++
            if (options.inJustDecodeBounds) {
                options.outWidth = 24
                options.outHeight = 24
                null
            } else throw OutOfMemoryError("pixel decode")
        })
        assertEquals(2, calls)
    }
}
