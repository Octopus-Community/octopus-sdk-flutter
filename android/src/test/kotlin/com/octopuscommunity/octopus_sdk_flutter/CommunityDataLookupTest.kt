package com.octopuscommunity.octopus_sdk_flutter

import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.Profile
import com.octopuscommunity.sdk.domain.network.OctopusResult
import com.octopuscommunity.sdk.domain.repository.ProfileRepository
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.dsl.module
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Exercises both channel lookup paths with a fake repository; never initializes a community. */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class CommunityDataLookupTest {
    private val dispatcher = StandardTestDispatcher()
    private val profiles = Mockito.mock(ProfileRepository::class.java)
    private val testModule = module { single { profiles } }
    private var wasInitialised = false
    private lateinit var plugin: OctopusSDKFlutterPlugin
    private val identifiers = listOf("profileId" to "octopus-id", "clientUserId" to "host-id")

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        plugin = OctopusSDKFlutterPlugin()
        wasInitialised = OctopusSDK.isInitialised
        OctopusSDK.koin.loadModules(listOf(testModule))
        OctopusSDK.isInitialisedFlow.value = true
    }

    @After
    fun tearDown() {
        OctopusSDK.isInitialisedFlow.value = wasInitialised
        OctopusSDK.koin.unloadModules(listOf(testModule))
        Dispatchers.resetMain()
    }

    @Test
    fun bothIdentifiers_returnSerializedDataOnSuccess() = runTest(dispatcher) {
        val profile = Mockito.mock(Profile::class.java)
        Mockito.`when`(profile.userId).thenReturn("octopus-id")
        Mockito.`when`(profile.messageCount).thenReturn(7)
        Mockito.`when`(profile.gamificationLevelIndex).thenReturn(2)
        Mockito.`when`(profile.gamificationScore).thenReturn(17)
        for ((key, id) in identifiers) {
            Mockito.clearInvocations(profiles)
            Mockito.`when`(lookup(key, id)).thenReturn(OctopusResult.Success(profile))
            val result = invokeLookup(key, id)
            advanceUntilIdle()
            Mockito.verify(result).success(mapOf(
                "profileId" to "octopus-id", "messageCount" to 7,
                "gamification" to mapOf("level" to 2, "score" to 17),
            ))
            Mockito.verifyNoMoreInteractions(result)
            verifyIdentifier(key, id)
        }
    }

    @Test
    fun bothIdentifiers_returnNullOnSuccessfulAbsence() = runTest(dispatcher) {
        for ((key, id) in identifiers) {
            Mockito.`when`(lookup(key, id)).thenReturn(OctopusResult.Success(null))
            val result = invokeLookup(key, id)
            advanceUntilIdle()
            Mockito.verify(result).success(null)
            Mockito.verifyNoMoreInteractions(result)
        }
    }

    @Test
    fun bothIdentifiers_reportEveryNativeFailureAsFetchFailed() = runTest(dispatcher) {
        val failures = listOf(
            OctopusResult.Failure.NoNetwork,
            OctopusResult.Failure.ContentUnavailable,
            OctopusResult.Failure.UserNotAuthenticated("Authentication required"),
            OctopusResult.Failure.PermissionDenied("Lookup not allowed"),
            OctopusResult.Failure.StatusError(13, "Lookup failed", IllegalStateException("Unavailable")),
        )
        for ((key, id) in identifiers) {
            for (failure in failures) {
                Mockito.`when`(lookup(key, id)).thenReturn(failure)
                val result = invokeLookup(key, id)
                advanceUntilIdle()
                Mockito.verify(result).error("FETCH_FAILED", "Community data lookup failed", null)
                Mockito.verifyNoMoreInteractions(result)
            }
        }
    }

    @Test
    fun bothIdentifiers_reportUnexpectedExceptionsAsFetchFailed() = runTest(dispatcher) {
        for ((key, id) in identifiers) {
            Mockito.`when`(lookup(key, id)).thenThrow(IllegalStateException("Lookup failed"))
            val result = invokeLookup(key, id)
            advanceUntilIdle()
            Mockito.verify(result).error("FETCH_FAILED", "Lookup failed", null)
            Mockito.verifyNoMoreInteractions(result)
        }
    }

    @Test
    fun bothIdentifiers_preserveCancellationWithoutReportingFailure() = runTest(dispatcher) {
        for ((key, id) in identifiers) {
            Mockito.`when`(lookup(key, id)).thenThrow(CancellationException("Lookup cancelled"))
            val result = invokeLookup(key, id)
            advanceUntilIdle()
            Mockito.verifyNoInteractions(result)
        }
    }

    private suspend fun lookup(key: String, id: String): OctopusResult<Profile?, Nothing> =
        if (key == "profileId") profiles.fetchProfile(id) else profiles.fetchProfileByClientUserId(id)

    private fun invokeLookup(key: String, id: String): MethodChannel.Result {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("fetchCommunityData", mapOf(key to id)), result)
        return result
    }

    private suspend fun verifyIdentifier(key: String, id: String) {
        if (key == "profileId") Mockito.verify(profiles).fetchProfile(id)
        else Mockito.verify(profiles).fetchProfileByClientUserId(id)
        Mockito.verifyNoMoreInteractions(profiles)
    }
}
