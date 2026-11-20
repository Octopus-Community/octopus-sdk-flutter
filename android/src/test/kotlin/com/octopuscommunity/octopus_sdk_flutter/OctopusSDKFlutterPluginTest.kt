package com.octopuscommunity.octopus_sdk_flutter

import android.net.Uri
import com.octopuscommunity.sdk.domain.model.ConnectionMode
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.domain.model.Resource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito

/*
 * Unit test of the Kotlin portion of this plugin's implementation. It runs from the plugin's
 * own module — there is no `example/android/gradlew`, and building the example app does not
 * run these tests:
 *
 *   ROOT="$(git rev-parse --show-toplevel)" && cd "$ROOT/android" \
 *     && ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}" ./gradlew testDebugUnitTest
 *
 * Or directly from an IDE that supports JUnit, such as Android Studio.
 */

internal class OctopusSDKFlutterPluginTest {
  @Test
  fun initializationPaths_requireTheWrapperVersionBeforeCallingTheNativeSdk() {
    for (method in listOf("initialize", "switchCommunity")) {
      val result = Mockito.mock(MethodChannel.Result::class.java)
      OctopusSDKFlutterPlugin().onMethodCall(
        MethodCall(method, mapOf("apiKey" to "test-key")),
        result
      )
      Mockito.verify(result).error("INVALID_ARGS", "wrapperVersion is required", null)
      Mockito.verifyNoMoreInteractions(result)
    }
  }

  /**
   * `toSdkImage` must trim once and dispatch on the trimmed value: a padded URL used to fall
   * into the base64 branch, throw and yield `null` (the picture silently dropped).
   */
  @Test
  fun toSdkImage_paddedUrl_isTreatedAsRemote() {
    val plugin = OctopusSDKFlutterPlugin()

    // android.net.Uri is a stub on the JVM; toSdkImage checks the parsed host.
    Mockito.mockStatic(Uri::class.java).use { uri ->
      val parsed = Mockito.mock(Uri::class.java)
      Mockito.`when`(parsed.host).thenReturn("example.com")
      uri.`when`<Uri> { Uri.parse(Mockito.anyString()) }.thenReturn(parsed)

      assertEquals(
        Resource.Remote(url = "https://example.com/a.png"),
        plugin.toSdkImage("  \n https://example.com/a.png \t")
      )
      assertEquals(
        Resource.Remote(url = "https://example.com/a.png"),
        plugin.toSdkImage("https://example.com/a.png")
      )
    }
  }

  @Test
  fun toSdkImage_nullOrBlank_returnsNull() {
    val plugin = OctopusSDKFlutterPlugin()

    assertNull(plugin.toSdkImage(null))
    assertNull(plugin.toSdkImage("   \n\t "))
  }

  @Test
  fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
    val plugin = OctopusSDKFlutterPlugin()

    val call = MethodCall("getPlatformVersion", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
  }

  /**
   * The `showCreatePostScreen` guard added for the create-post editor, exercised host-side.
   *
   * No Robolectric is needed: the guard runs before any `context` access, and
   * `OctopusSDK.isInitialised` starts `false` in a JVM test process where nothing ever called
   * `initialize()` — so a bare plugin reaching this branch is exactly the pre-initialisation
   * state a host hits. The complementary case (initialised → activity started) is not
   * reachable host-side, since `initialize()` needs a real Android context.
   */
  @Test
  fun onMethodCall_showCreatePostScreen_beforeInitialize_returnsNotInitializedError() {
    val plugin = OctopusSDKFlutterPlugin()

    val call = MethodCall("showCreatePostScreen", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).error("NOT_INITIALIZED", "Call initialize() first", null)
    // Nothing else reached the Result — in particular no `success(null)`, which is what a
    // guard that let the call through would have reported.
    Mockito.verifyNoMoreInteractions(mockResult)
  }

  @Test
  fun onMethodCall_olderDebugOverrides_failureReturnsOverrideError() {
    val plugin = OctopusSDKFlutterPlugin()
    for ((method, argument) in listOf(
      "debugOverrideProfileFieldsLock" to "lock",
      "debugOverrideContentOptions" to "options",
      "debugOverrideTermsAcceptanceMode" to "mode",
    )) {
      val result = Mockito.mock(MethodChannel.Result::class.java)
      // An invalid wire type fails while parsing, before calling the native SDK.
      // The bridge must return the same error code as a failed native override.
      plugin.onMethodCall(MethodCall(method, mapOf(argument to 42)), result)
      Mockito.verify(result).error(
        Mockito.eq("OVERRIDE_ERROR"), Mockito.anyString(), Mockito.isNull(),
      )
      Mockito.verifyNoMoreInteractions(result)
    }
  }

  @Test
  fun contentOptions_textRequired_defaultsAndNullableClear() {
    val plugin = OctopusSDKFlutterPlugin()
    for (value in listOf(true, false, null, "wrong-type")) {
      val options = plugin.parseContentOptions(MethodCall("debugOverrideContentOptions",
        mapOf("options" to mapOf("post" to mapOf("textRequired" to value)))))
      assertEquals(value as? Boolean ?: true, options?.post?.textRequired)
    }
    assertEquals(true, plugin.parseContentOptions(MethodCall("debugOverrideContentOptions",
      mapOf("options" to emptyMap<String, Any>())))?.post?.textRequired)
    assertNull(plugin.parseContentOptions(MethodCall("debugOverrideContentOptions", mapOf("options" to null))))
  }

  @Test
  fun contentOptions_postTapOptions_forwardAllCombinationsIndependently() {
    val plugin = OctopusSDKFlutterPlugin()
    for (image in listOf(false, true)) {
      for (group in listOf(false, true)) {
        val options = plugin.parseContentOptions(MethodCall("debugOverrideContentOptions",
          mapOf("options" to mapOf("post" to mapOf(
            "enablePictures" to false,
            "textRequired" to false,
            "imageTapOpensPost" to image,
            "groupNameTapOpensGroup" to group,
          )))))!!
        assertEquals(image, options.post.imageTapOpensPost)
        assertEquals(group, options.post.groupNameTapOpensGroup)
        assertEquals(false, options.post.enablePictures)
        assertEquals(true, options.post.enablePolls)
        assertEquals(false, options.post.textRequired)
        assertEquals(true, options.comment.enablePictures)
        assertEquals(true, options.reply.enablePictures)
      }
    }
  }

  @Test
  fun contentOptions_postTapOptions_absentOrMalformedDefaultsToFalse() {
    val plugin = OctopusSDKFlutterPlugin()
    for (map in listOf(
      emptyMap<String, Any?>(),
      mapOf("post" to null),
      mapOf("post" to "wrong-type"),
      mapOf("post" to emptyMap<String, Any?>()),
      mapOf("post" to mapOf("imageTapOpensPost" to null, "groupNameTapOpensGroup" to null)),
      mapOf("post" to mapOf("imageTapOpensPost" to "true", "groupNameTapOpensGroup" to 1)),
      mapOf("post" to mapOf("imageTapOpensPost" to true)),
      mapOf("post" to mapOf("groupNameTapOpensGroup" to true)),
    )) {
      val options = plugin.parseContentOptions(MethodCall("debugOverrideContentOptions", mapOf("options" to map)))!!
      val post = map["post"] as? Map<*, *>
      assertEquals(post?.get("imageTapOpensPost") == true, options.post.imageTapOpensPost)
      assertEquals(post?.get("groupNameTapOpensGroup") == true, options.post.groupNameTapOpensGroup)
      assertEquals(true, options.post.enablePictures)
      assertEquals(true, options.post.enablePolls)
      assertEquals(true, options.post.textRequired)
    }
    assertNull(plugin.parseContentOptions(MethodCall("debugOverrideContentOptions", null)))
    assertNull(plugin.parseContentOptions(MethodCall("debugOverrideContentOptions", mapOf("options" to null))))
  }

  @Test
  fun consentTexts_roundTripsAllVariantsWithoutNormalizingFields() {
    val plugin = OctopusSDKFlutterPlugin()
    for (wire in listOf(
      mapOf("mode" to "implicit", "notice" to "Unicode 世界\n[link](https://example.com)"),
      mapOf("mode" to "multiCheckbox", "termsLabel" to "", "privacyLabel" to "   ", "rulesLabel" to null),
      mapOf("mode" to "singleCheckbox", "label" to null, "belowText" to "first\n\nsecond"),
    )) assertEquals(wire, plugin.serializeConsentTexts(plugin.parseConsentTexts(wire)))
    assertNull(plugin.parseConsentTexts(null))
    assertNull(plugin.serializeConsentTexts(null))
    assertNull(plugin.parseConsentTexts(mapOf("mode" to "future")))
    assertEquals(mapOf("mode" to "implicit", "notice" to null),
      plugin.serializeConsentTexts(plugin.parseConsentTexts(mapOf("mode" to "implicit", "notice" to 42))))
  }

  @Test
  fun newDebugOverrides_beforeInitialize_returnNotInitialized() {
    val plugin = OctopusSDKFlutterPlugin()
    for (method in listOf("debugOverrideForceNicknameChoice", "debugOverrideConsentTexts")) {
      val result = Mockito.mock(MethodChannel.Result::class.java)
      plugin.onMethodCall(MethodCall(method, null), result)
      Mockito.verify(result).error("NOT_INITIALIZED", "Call initialize() first", null)
      Mockito.verifyNoMoreInteractions(result)
    }
  }

  @Test
  fun removedAuthenticationMethods_areNotImplemented() {
    val plugin = OctopusSDKFlutterPlugin()
    for (method in listOf("initializeOctopusAuth", "switchCommunityOctopusAuth")) {
      val result = Mockito.mock(MethodChannel.Result::class.java)
      plugin.onMethodCall(MethodCall(method, null), result)
      Mockito.verify(result).notImplemented()
      Mockito.verifyNoMoreInteractions(result)
    }
  }

  @Test
  fun connectionModeFor_sso_carriesAppManagedFields() {
    assertEquals(
      ConnectionMode.SSO(appManagedFields = setOf(ProfileField.NICKNAME, ProfileField.PICTURE)),
      connectionModeFor(
        appManagedFields = setOf(ProfileField.NICKNAME, ProfileField.PICTURE),
      ),
    )
    assertEquals(ConnectionMode.SSO(), connectionModeFor())
  }
}
