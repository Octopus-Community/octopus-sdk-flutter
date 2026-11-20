package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.graphics.Bitmap
import android.util.Base64
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.ClientUser
import com.octopuscommunity.sdk.domain.model.Resource
import com.octopuscommunity.sdk.domain.model.SyncFollowGroupAction
import com.octopuscommunity.sdk.domain.network.OctopusResult
import com.octopuscommunity.sdk.domain.repository.ConnectionRepository.ConnectionState
import com.octopuscommunity.sdk.domain.repository.GroupRepository
import com.octopuscommunity.sdk.domain.usecase.ConnectUseCase
import com.octopuscommunity.sdk.domain.usecase.DisconnectUseCase
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.dsl.module
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/** Exercises the real channel handlers against fake native collaborators; never connects. */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class ModernizationRegressionTest {
    private val dispatcher = StandardTestDispatcher()
    private lateinit var plugin: OctopusSDKFlutterPlugin
    private lateinit var pluginJob: Job
    private lateinit var context: Context
    private var wasInitialised = false
    private val connect = Mockito.mock(ConnectUseCase::class.java)
    private val disconnect = Mockito.mock(DisconnectUseCase::class.java)
    private val groups = Mockito.mock(GroupRepository::class.java)
    private val testModule = module {
        single { connect }
        single { disconnect }
        single { groups }
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        context = RuntimeEnvironment.getApplication()
        context.cacheDir.listFiles()?.filter { it.name.startsWith("octopus_image") }?.forEach { it.delete() }
        plugin = OctopusSDKFlutterPlugin()
        pluginJob = (OctopusSDKFlutterPlugin::class.java.getDeclaredField("scope").apply {
            isAccessible = true
        }.get(plugin) as CoroutineScope).coroutineContext[Job]!!
        // Keep tests compatible with the base revision: no production-only test constructor.
        OctopusSDKFlutterPlugin::class.java.getDeclaredField("context").apply {
            isAccessible = true
            set(plugin, context)
        }
        wasInitialised = OctopusSDK.isInitialised
        OctopusSDK.koin.loadModules(listOf(testModule))
        OctopusSDK.isInitialisedFlow.value = true
        ShadowLog.clear()
    }

    @After
    fun tearDown() {
        pluginJob.cancel()
        OctopusEventEmitter.setEventSink(null)
        OctopusSDKFlutterPlugin.bridgeTokenDeferreds.values.forEach { it.cancel() }
        OctopusSDKFlutterPlugin.bridgeTokenDeferreds.clear()
        OctopusSDK.isInitialisedFlow.value = wasInitialised
        OctopusSDK.koin.unloadModules(listOf(testModule))
        Dispatchers.resetMain()
    }

    @Test
    fun eventPayloadIsDeliveredWithoutLoggingUserData() {
        val sink = Mockito.mock(EventChannel.EventSink::class.java)
        OctopusEventEmitter.setEventSink(sink)
        val data = mapOf(
            "clientUserId" to "private-user-id",
            "nickname" to "private-nickname",
            "bio" to "private-bio",
            "entitlements" to listOf("private-entitlement"),
            "url" to "https://example.com/private-path",
        )
        OctopusSDKFlutterPlugin.sendEvent("profileModified", data)
        Mockito.verify(sink).success(mapOf("event" to "profileModified") + data)
        val logs = ShadowLog.getLogs().joinToString { it.msg }
        assertFalse(logs.contains("private-"), "Event data leaked into native logs")
    }

    @Test
    fun connectUserDoesNotLogProfileData() = runTest(dispatcher) {
        Mockito.`when`(connect.invoke(anyUser(), anyTokenProvider())).thenReturn(
            OctopusResult.Success(ConnectUseCase.Result(ConnectionState.NotConnected, null, null))
        )
        val result = result()
        plugin.onMethodCall(connectCall(), result)
        awaitPluginCalls()
        Mockito.verify(result).success(mapOf("type" to "success"))
        assertFalse(ShadowLog.getLogs().any { it.msg.contains("private-") })
    }

    @Test
    fun syncFollowGroupsSkipsMalformedEntriesAndKeepsValidActions() = runTest(dispatcher) {
        var received: List<SyncFollowGroupAction>? = null
        Mockito.`when`(groups.syncFollowGroups(Mockito.anyList())).thenAnswer {
            received = it.getArgument(0)
            OctopusResult.Success(emptyList<Any>())
        }
        val result = result()
        val valid = mapOf("groupId" to "group-a", "followed" to false, "actionDateMs" to 1234L)
        plugin.onMethodCall(MethodCall("syncFollowGroups", mapOf("actions" to listOf(
            valid, valid + ("groupId" to 3), valid + ("followed" to "yes"),
            valid + ("actionDateMs" to "yesterday"), emptyMap<String, Any>(), valid,
        ))), result)
        advanceUntilIdle()
        assertEquals(listOf("group-a", "group-a"), received?.map { it.groupId })
        assertEquals(listOf(false, false), received?.map { it.followed })
        assertEquals(listOf(1234L, 1234L), received?.map { it.actionDate.time })
        Mockito.verify(result).success(emptyList<Any>())
        Mockito.verifyNoMoreInteractions(result)
    }

    // Like iOS (`as? [[String: Any]]`), a batch holding a non-map entry is rejected whole.
    @Test
    fun syncFollowGroupsRejectsBatchesWithNonMapEntries() {
        val valid = mapOf("groupId" to "group-a", "followed" to false, "actionDateMs" to 1234L)
        for (actions in listOf(listOf(valid, null), listOf(valid, "invalid"), listOf(valid + (7 to "invalid key")))) {
            val result = result()
            plugin.onMethodCall(MethodCall("syncFollowGroups", mapOf("actions" to actions)), result)
            Mockito.verify(result).error("other", "actions list is required", null)
            Mockito.verifyNoMoreInteractions(result)
        }
        Mockito.verifyNoInteractions(groups)
    }

    // Like iOS, only a genuinely empty list skips the native call; a nonempty
    // batch with no valid action still reaches it so native errors surface.
    @Test
    fun syncFollowGroupsWithOnlyMalformedEntriesStillCallsNative() = runTest(dispatcher) {
        var received: List<SyncFollowGroupAction>? = null
        Mockito.`when`(groups.syncFollowGroups(Mockito.anyList())).thenAnswer {
            received = it.getArgument(0)
            OctopusResult.Success(emptyList<Any>())
        }
        val result = result()
        plugin.onMethodCall(MethodCall("syncFollowGroups", mapOf("actions" to listOf(
            emptyMap<String, Any>(), mapOf("groupId" to 3),
        ))), result)
        advanceUntilIdle()
        assertEquals(emptyList(), received)
        Mockito.verify(result).success(emptyList<Any>())
    }

    @Test
    fun syncFollowGroupsWithEmptyListReturnsEmptyWithoutNativeCall() {
        val result = result()
        plugin.onMethodCall(MethodCall("syncFollowGroups", mapOf("actions" to emptyList<Any>())), result)
        Mockito.verify(result).success(emptyList<Any>())
        Mockito.verifyNoInteractions(groups)
    }

    @Test
    fun syncFollowGroupsBeforeInitializeReturnsNotConnected() {
        OctopusSDK.isInitialisedFlow.value = false
        val result = result()
        plugin.onMethodCall(MethodCall("syncFollowGroups", mapOf("actions" to emptyList<Any>())), result)
        Mockito.verify(result).error("not_connected", "Call initialize() and connectUser() first", null)
        Mockito.verifyNoMoreInteractions(result)
        Mockito.verifyNoInteractions(groups)
    }

    @Test
    fun syncFollowGroupsRequiresAnActionsList() {
        for (arguments in listOf(null, emptyMap<String, Any>(), mapOf("actions" to "invalid"))) {
            val result = result()
            plugin.onMethodCall(MethodCall("syncFollowGroups", arguments), result)
            Mockito.verify(result).error("other", "actions list is required", null)
            Mockito.verifyNoMoreInteractions(result)
        }
        Mockito.verifyNoInteractions(groups)
    }

    @Test
    fun bridgeTokenTimesOutWithNoTokenAndRemovesPendingRequest() = runTest(dispatcher) {
        val pending = async { OctopusSDKFlutterPlugin.requestBridgeToken("timeout", "fingerprint") }
        runCurrent()
        advanceTimeBy(59_999)
        assertFalse(pending.isCompleted)
        advanceTimeBy(1)
        runCurrent()
        assertTrue(pending.isCompleted, "Bridge token request remains parked after 60 seconds")
        assertEquals(null, pending.await())
        assertFalse(OctopusSDKFlutterPlugin.bridgeTokenDeferreds.containsKey("timeout"))
        // A late Dart reply must be acknowledged without reviving the request.
        val result = result()
        plugin.onMethodCall(MethodCall("provideBridgeToken", mapOf("requestId" to "timeout", "token" to "late")), result)
        Mockito.verify(result).success(null)
        assertTrue(OctopusSDKFlutterPlugin.bridgeTokenDeferreds.isEmpty())
    }

    @Test
    fun bridgeTokenPreservesExplicitNullAndSuccessfulReplies() = runTest(dispatcher) {
        for (token in listOf(null, "signed-reply")) {
            val pending = async { OctopusSDKFlutterPlugin.requestBridgeToken("reply", "fingerprint") }
            runCurrent()
            plugin.onMethodCall(MethodCall("provideBridgeToken", mapOf("requestId" to "reply", "token" to token)), result())
            runCurrent()
            assertEquals(token, pending.await())
            assertTrue(OctopusSDKFlutterPlugin.bridgeTokenDeferreds.isEmpty())
        }
        val pending = async { OctopusSDKFlutterPlugin.requestBridgeToken("cancel", "fingerprint") }
        runCurrent()
        pending.cancel()
        runCurrent()
        assertTrue(OctopusSDKFlutterPlugin.bridgeTokenDeferreds.isEmpty())
    }

    @Test
    fun avatarFileExistsDuringConnectAndIsDeletedAfterSuccess() = runTest(dispatcher) {
        var consumed: File? = null
        Mockito.`when`(connect.invoke(anyUser(), anyTokenProvider())).thenAnswer {
            val picture = it.getArgument<ClientUser>(0).profile?.picture as Resource.Local
            consumed = File(picture.uri.path!!)
            assertTrue(consumed!!.readBytes().isNotEmpty(), "Avatar deleted before the SDK consumed it")
            OctopusResult.Success(ConnectUseCase.Result(ConnectionState.NotConnected, null, null))
        }
        val result = result()
        plugin.onMethodCall(connectCall(png()), result)
        awaitPluginCalls()
        Mockito.verify(result).success(mapOf("type" to "success"))
        assertFalse(consumed!!.exists(), "Consumed avatar remains in cache")
    }

    @Test
    fun avatarFileIsDeletedWhenConnectThrows() = runTest(dispatcher) {
        Mockito.`when`(connect.invoke(anyUser(), anyTokenProvider())).thenThrow(IllegalStateException("fake refusal"))
        val result = result()
        plugin.onMethodCall(connectCall(png()), result)
        awaitPluginCalls()
        Mockito.verify(result).error("CONNECT_ERROR", "fake refusal", null)
        assertTrue(context.cacheDir.listFiles()!!.none { it.name.startsWith("octopus_image") })
    }

    @Test
    fun disconnectDeletesOldPluginAvatarsAndPreservesHostFiles() = runTest(dispatcher) {
        val old = File.createTempFile("octopus_image", ".png", context.cacheDir).apply { writeText("old avatar") }
        val unrelated = File(context.cacheDir, "host-avatar.png").apply { writeText("keep") }
        val similar = File(context.cacheDir, "octopus_image-host.png").apply { writeText("keep") }
        val result = result()
        plugin.onMethodCall(MethodCall("disconnectUser", null), result)
        awaitPluginCalls()
        Mockito.verify(result).success(null)
        assertFalse(old.exists(), "Old plugin avatar survives disconnect")
        assertTrue(unrelated.exists())
        assertTrue(similar.exists())
        unrelated.delete()
        similar.delete()
    }

    // advanceUntilIdle only drains the test dispatcher. Joining the plugin's jobs
    // also waits for real Dispatchers.IO work, including the finally cleanup.
    private suspend fun awaitPluginCalls() {
        pluginJob.children.toList().joinAll()
    }

    // Mockito's Java matchers return null; supply a dummy after registering the matcher
    // so Kotlin's non-null parameter check does not fail before reaching the mock.
    private fun anyUser(): ClientUser = Mockito.any(ClientUser::class.java) ?: ClientUser("", null)
    private fun anyTokenProvider(): suspend () -> String = Mockito.any<suspend () -> String>() ?: { "" }

    private fun result() = Mockito.mock(MethodChannel.Result::class.java)

    private fun connectCall(picture: String? = null) = MethodCall("connectUser", mapOf(
        "userId" to "private-user-id", "providerId" to "fake-provider", "nickname" to "private-nickname",
        "bio" to "private-bio", "picture" to picture,
    ))

    private fun png(): String {
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }
}
