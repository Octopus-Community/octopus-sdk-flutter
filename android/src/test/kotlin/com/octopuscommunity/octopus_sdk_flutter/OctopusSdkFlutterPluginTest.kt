package com.octopuscommunity.octopus_sdk_flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
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
}
