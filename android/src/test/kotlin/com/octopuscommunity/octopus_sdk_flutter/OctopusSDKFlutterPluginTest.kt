package com.octopuscommunity.octopus_sdk_flutter

import com.octopuscommunity.sdk.domain.model.ConnectionMode
import com.octopuscommunity.sdk.domain.model.ProfileField
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
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

  /**
   * #423: `initializeOctopusAuth` and `switchCommunityOctopusAuth` used to omit
   * `connectionMode`, and the native default is `ConnectionMode.SSO()` — so the Octopus Auth
   * entry point started the SDK in SSO mode. Both paths now go through [connectionModeFor].
   */
  @Test
  fun connectionModeFor_octopusAuth_isOctopusAuthNotTheNativeSsoDefault() {
    assertEquals(ConnectionMode.OctopusAuth, connectionModeFor(octopusAuth = true))
    // appManagedFields are an SSO concept; they never leak into the Octopus Auth mode.
    assertEquals(
      ConnectionMode.OctopusAuth,
      connectionModeFor(octopusAuth = true, appManagedFields = setOf(ProfileField.NICKNAME)),
    )
  }

  @Test
  fun connectionModeFor_sso_carriesAppManagedFields() {
    assertEquals(
      ConnectionMode.SSO(appManagedFields = setOf(ProfileField.NICKNAME, ProfileField.PICTURE)),
      connectionModeFor(
        octopusAuth = false,
        appManagedFields = setOf(ProfileField.NICKNAME, ProfileField.PICTURE),
      ),
    )
    assertEquals(ConnectionMode.SSO(), connectionModeFor(octopusAuth = false))
  }
}
