package com.octopuscommunity.octopus_sdk_flutter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/*
 * Decoder tests for the `initialScreen` wire payload. Pure `Map<*, *>` → sealed-class
 * functions, so they need no device and no Robolectric — see the sibling
 * OctopusSDKFlutterPluginTest for how to run them:
 *
 *   ROOT="$(git rev-parse --show-toplevel)" && cd "$ROOT/android" \
 *     && ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}" ./gradlew testDebugUnitTest
 *
 * The warning paths call android.util.Log, which the mockable android.jar stubs out — hence
 * `testOptions.unitTests.returnDefaultValues = true` in android/build.gradle.
 */

internal class MemberIdFromMapTest {
  @Test
  fun clientUserId_decodesWithThatSource() {
    assertEquals(
      MemberId(MemberId.Source.CLIENT_USER_ID, "cu-1"),
      MemberId.fromMap(mapOf("source" to "clientUserId", "id" to "cu-1"))
    )
  }

  @Test
  fun profileId_decodesWithThatSource() {
    assertEquals(
      MemberId(MemberId.Source.PROFILE_ID, "p-1"),
      MemberId.fromMap(mapOf("source" to "profileId", "id" to "p-1"))
    )
  }

  @Test
  fun absentMember_isNull() {
    assertNull(MemberId.fromMap(null))
  }

  @Test
  fun nonMapMember_isNull() {
    assertNull(MemberId.fromMap("cu-1"))
  }

  @Test
  fun emptyId_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to "clientUserId", "id" to "")))
  }

  @Test
  fun whitespaceOnlyId_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to "clientUserId", "id" to "   ")))
  }

  /**
   * The one case the whole shape of this decoder hangs on: a padded id is forwarded
   * **verbatim**, exactly like the `post` / `group` ids. This side must not trim, because
   * iOS does not either — the Dart producer (`memberIdToMap`) is what trims, and a bridge
   * that quietly normalized on top would put the two platforms back out of step the day the
   * other one stops.
   */
  @Test
  fun paddedNonBlankId_isForwardedUntrimmed() {
    assertEquals(
      MemberId(MemberId.Source.CLIENT_USER_ID, " cu-1 "),
      MemberId.fromMap(mapOf("source" to "clientUserId", "id" to " cu-1 "))
    )
  }

  @Test
  fun missingId_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to "clientUserId")))
  }

  @Test
  fun nonStringId_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to "clientUserId", "id" to 42)))
  }

  @Test
  fun unknownSource_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to "bogus", "id" to "cu-1")))
  }

  @Test
  fun missingSource_isNull() {
    assertNull(MemberId.fromMap(mapOf("id" to "cu-1")))
  }

  @Test
  fun nonStringSource_isNull() {
    assertNull(MemberId.fromMap(mapOf("source" to 1, "id" to "cu-1")))
  }

  /** A blank id loses to a good source: the id is checked first, on both platforms. */
  @Test
  fun blankIdWithValidSource_isNullRatherThanASourceError() {
    assertNull(MemberId.fromMap(mapOf("source" to "profileId", "id" to " ")))
  }
}

internal class InitialScreenSpecFromMapMemberTest {
  @Test
  fun activity_carriesTheDecodedMember() {
    assertEquals(
      InitialScreenSpec.Activity(MemberId(MemberId.Source.CLIENT_USER_ID, "cu-1")),
      InitialScreenSpec.fromMap(
        mapOf("type" to "activity", "member" to mapOf("source" to "clientUserId", "id" to "cu-1"))
      )
    )
  }

  @Test
  fun activity_withProfileIdMember_keepsThatSource() {
    assertEquals(
      InitialScreenSpec.Activity(MemberId(MemberId.Source.PROFILE_ID, "p-1")),
      InitialScreenSpec.fromMap(
        mapOf("type" to "activity", "member" to mapOf("source" to "profileId", "id" to "p-1"))
      )
    )
  }

  /** No own-user meaning to fall back on, so an undecodable member means the main feed. */
  @Test
  fun activity_withoutAMember_fallsBackToMainFeed() {
    assertEquals(InitialScreenSpec.MainFeed, InitialScreenSpec.fromMap(mapOf("type" to "activity")))
    assertEquals(
      InitialScreenSpec.MainFeed,
      InitialScreenSpec.fromMap(
        mapOf("type" to "activity", "member" to mapOf("source" to "clientUserId", "id" to ""))
      )
    )
  }

  @Test
  fun profile_carriesTheDecodedMember() {
    assertEquals(
      InitialScreenSpec.Profile(MemberId(MemberId.Source.CLIENT_USER_ID, "cu-1")),
      InitialScreenSpec.fromMap(
        mapOf("type" to "profile", "member" to mapOf("source" to "clientUserId", "id" to "cu-1"))
      )
    )
  }

  /** An absent member is the documented way to ask for the connected user's own profile. */
  @Test
  fun profile_withoutAMember_isTheOwnProfileForm() {
    assertEquals(
      InitialScreenSpec.Profile(null),
      InitialScreenSpec.fromMap(mapOf("type" to "profile"))
    )
    assertEquals(
      InitialScreenSpec.Profile(null),
      InitialScreenSpec.fromMap(
        mapOf("type" to "profile", "member" to mapOf("source" to "clientUserId", "id" to "   "))
      )
    )
  }
}
