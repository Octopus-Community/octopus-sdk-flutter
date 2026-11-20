package com.octopuscommunity.octopus_sdk_flutter

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * The Android-only `fontFamilyNavBarTitle` / `fontSizeNavBarTitle` keys are merged onto the bar
 * title's own style. These pin the override and what the merge keeps.
 */
internal class NavBarTitleStyleTest {
    // Stands in for the bar's ambient text style (Material `titleLarge` on the small bar).
    private val barStyle = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 22.sp, fontWeight = FontWeight.Normal)

    @Test fun nothingSetKeepsTheExistingSlot() {
        assertNull(navBarTitleStyleOverride(fontFamily = null, fontSizeSp = null))
    }

    @Test fun nonPositiveSizeAloneIsIgnored() {
        assertNull(navBarTitleStyleOverride(fontFamily = null, fontSizeSp = 0))
        assertNull(navBarTitleStyleOverride(fontFamily = null, fontSizeSp = -4))
    }

    @Test fun sizeAloneKeepsTheBarFont() {
        val merged = barStyle.merge(assertNotNull(navBarTitleStyleOverride(null, 18)))
        assertEquals(18.sp, merged.fontSize)
        assertEquals(FontFamily.SansSerif, merged.fontFamily)
        assertEquals(FontWeight.Normal, merged.fontWeight)
    }

    @Test fun fontAloneKeepsTheBarSize() {
        val override = assertNotNull(navBarTitleStyleOverride(FontFamily.Serif, null))
        assertEquals(TextUnit.Unspecified, override.fontSize)
        val merged = barStyle.merge(override)
        assertEquals(FontFamily.Serif, merged.fontFamily)
        assertEquals(22.sp, merged.fontSize)
    }

    @Test fun fontAndSizeBothApply() {
        val merged = barStyle.merge(assertNotNull(navBarTitleStyleOverride(FontFamily.Serif, 18)))
        assertEquals(FontFamily.Serif, merged.fontFamily)
        assertEquals(18.sp, merged.fontSize)
    }

    @Test fun unresolvedFontWithSizeStillAppliesTheSize() {
        // An unresolved resource reaches here as a null family: the base family stays.
        val merged = barStyle.merge(assertNotNull(navBarTitleStyleOverride(null, 20)))
        assertEquals(FontFamily.SansSerif, merged.fontFamily)
        assertEquals(20.sp, merged.fontSize)
    }

    @Test fun nativeDefaultIsTheAmbientStyleAt17spSemibold() {
        // Native Android 1.16 `OctopusTopAppBarTitle` with no style: ambient copy, 17sp semibold.
        val native = nativeNavBarTitleStyle(barStyle)
        assertEquals(17.sp, native.fontSize)
        assertEquals(FontWeight.SemiBold, native.fontWeight)
        assertEquals(FontFamily.SansSerif, native.fontFamily)
    }

    @Test fun fontAloneOnTheNativeDefaultKeeps17spSemibold() {
        val merged = nativeNavBarTitleStyle(barStyle)
            .merge(assertNotNull(navBarTitleStyleOverride(FontFamily.Serif, null)))
        assertEquals(FontFamily.Serif, merged.fontFamily)
        assertEquals(17.sp, merged.fontSize)
        assertEquals(FontWeight.SemiBold, merged.fontWeight)
    }

    @Test fun sizeAloneOnTheNativeDefaultKeepsSemibold() {
        val merged = nativeNavBarTitleStyle(barStyle)
            .merge(assertNotNull(navBarTitleStyleOverride(null, 20)))
        assertEquals(20.sp, merged.fontSize)
        assertEquals(FontWeight.SemiBold, merged.fontWeight)
        assertEquals(FontFamily.SansSerif, merged.fontFamily)
    }

    @Test fun mainFeedTitleFollowsTheIosPrecedence() {
        // A decoded custom logo wins, then `navBarTitle`, then the native default (null).
        assertNull(mainFeedTitleText(navBarTitle = "Host", hasCustomLogo = true))
        assertEquals("Host", mainFeedTitleText(navBarTitle = "Host", hasCustomLogo = false))
        assertNull(mainFeedTitleText(navBarTitle = null, hasCustomLogo = false))
        assertNull(mainFeedTitleText(navBarTitle = null, hasCustomLogo = true))
    }

    @Test fun overrideWinsOverTheGlobalFontStyle() {
        // The style the global `fontFamily` / `fontWeight` keys build (body1-based).
        val globalStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        val merged = globalStyle.merge(assertNotNull(navBarTitleStyleOverride(FontFamily.Serif, 24)))
        assertEquals(FontFamily.Serif, merged.fontFamily)
        assertEquals(24.sp, merged.fontSize)
        // What the title setting does not cover stays from the global style.
        assertEquals(FontWeight.Bold, merged.fontWeight)
    }
}
