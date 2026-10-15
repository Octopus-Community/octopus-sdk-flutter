package com.octopuscommunity.octopus_sdk_flutter

import androidx.activity.OnBackPressedCallback
import androidx.activity.OnBackPressedDispatcher
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.assertSame
import android.view.ViewGroup
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMethodCodec
import io.flutter.plugin.common.MethodCall
import org.junit.Rule
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

internal class EmbeddedViewBackTest {
    private class Owner : LifecycleOwner {
        val registry = LifecycleRegistry.createUnsafe(this)
        override val lifecycle: Lifecycle get() = registry

        fun update(visible: Boolean, parent: Lifecycle.State = Lifecycle.State.RESUMED) {
            registry.currentState = embeddedViewLifecycleState(visible, parent)
        }
    }

    @Test
    fun backRequiresVisibleViewAndMoreThanOneScreen() {
        var sdkPops = 0
        var hostPops = 0
        val dispatcher = OnBackPressedDispatcher { hostPops++ }
        val owner = Owner()
        owner.update(true)
        val callback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() { sdkPops++ }
        }
        dispatcher.addCallback(owner, callback)
        assertFalse(dispatcher.hasEnabledCallbacks()) // visible root
        callback.isEnabled = true // native depth > 1
        assertTrue(dispatcher.hasEnabledCallbacks())
        dispatcher.onBackPressed()
        assertEquals(1, sdkPops)
        owner.update(false) // inactive tab or covered route
        assertFalse(dispatcher.hasEnabledCallbacks())
        dispatcher.onBackPressed()
        assertEquals(1, hostPops)
        assertEquals(1, sdkPops)
        owner.update(true)
        assertTrue(dispatcher.hasEnabledCallbacks())
        dispatcher.onBackPressed()
        assertEquals(2, sdkPops)
        owner.update(true, Lifecycle.State.CREATED) // background activity
        assertFalse(dispatcher.hasEnabledCallbacks())
    }

    @Test
    fun sheetAtRootDoesNotDispatchToHiddenDeepTab() {
        var tabPops = 0
        var sheetPops = 0
        var hostPops = 0
        val dispatcher = OnBackPressedDispatcher { hostPops++ }
        val tab = Owner().apply { update(true) }
        dispatcher.addCallback(tab, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { tabPops++ }
        })
        tab.update(false)
        val sheet = Owner().apply { update(true) }
        val callback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() { sheetPops++ }
        }
        dispatcher.addCallback(sheet, callback)
        dispatcher.onBackPressed()
        assertEquals(1, hostPops)
        assertEquals(0, tabPops)
        callback.isEnabled = true
        dispatcher.onBackPressed()
        assertEquals(1, sheetPops)
        assertEquals(0, tabPops)
        sheet.update(false)
        dispatcher.onBackPressed()
        assertEquals(2, hostPops)
        assertEquals(0, tabPops)
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class EmbeddedContentBackTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @org.junit.Test
    fun hidingPixelsDoesNotStopAnUncappedBackHandler() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        var sdkPops = 0
        val nativeView = ComposeView(activity).apply {
            setContent { BackHandler { sdkPops++ } }
        }
        activity.setContentView(nativeView)
        compose.waitForIdle()
        try {
            compose.runOnIdle {
                nativeView.alpha = 0f
                assertTrue(nativeView.isAttachedToWindow)
                assertTrue(activity.onBackPressedDispatcher.hasEnabledCallbacks())
                activity.onBackPressedDispatcher.onBackPressed()
            }
            assertEquals(1, sdkPops)
        } finally {
            nativeView.disposeComposition()
            controller.pause().stop().destroy()
        }
    }

    @org.junit.Test
    fun setVisibleGatesBackHandlersInTheRealEmbeddedContent() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        val messenger = mock(BinaryMessenger::class.java)
        lateinit var handler: BinaryMessenger.BinaryMessageHandler
        doAnswer { invocation ->
            handler = invocation.getArgument(1)
            null
        }.`when`(messenger).setMessageHandler(
            eq("octopus_sdk_flutter/native_view/7"),
            any(BinaryMessenger.BinaryMessageHandler::class.java)
        )
        val embedded = OctopusEmbeddedView.Factory(messenger)
            .create(activity, 7, null) as OctopusEmbeddedView
        var sdkPops = 0
        var hostPops = 0
        activity.onBackPressedDispatcher.addCallback(activity, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { hostPops++ }
        })
        val deep = mutableStateOf(true)
        val nativeView = (embedded.view as ViewGroup).getChildAt(0) as ComposeView
        // Replace only the SDK content: the real lifecycle provider and visibility
        // channel remain in use, without initialising a community or an API key.
        nativeView.setContent {
            embedded.EmbeddedContent {
                assertSame(embedded, LocalLifecycleOwner.current)
                assertSame(activity, LocalOnBackPressedDispatcherOwner.current)
                BackHandler(enabled = deep.value) { sdkPops++ }
            }
        }
        activity.setContentView(embedded.view)
        compose.waitForIdle()
        val dispatcher = activity.onBackPressedDispatcher

        fun setVisible(value: Boolean) {
            compose.runOnIdle {
                val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall("setVisible", value))
                message.flip()
                handler.onMessage(message) { reply ->
                    requireNotNull(reply).flip()
                    StandardMethodCodec.INSTANCE.decodeEnvelope(reply)
                }
            }
            compose.waitForIdle()
        }

        try {
            assertEquals(Lifecycle.State.CREATED, embedded.lifecycle.currentState)
            compose.runOnIdle { dispatcher.onBackPressed() } // initially hidden
            assertEquals(0, sdkPops)
            assertEquals(1, hostPops)
            setVisible(true)
            assertTrue(dispatcher.hasEnabledCallbacks())
            compose.runOnIdle {
                nativeView.alpha = 0f // retained native view, invisible pixels only
                dispatcher.onBackPressed()
            }
            assertEquals(1, sdkPops)
            setVisible(false)
            assertEquals(Lifecycle.State.CREATED, embedded.lifecycle.currentState)
            compose.runOnIdle { dispatcher.onBackPressed() }
            assertEquals(1, sdkPops)
            assertEquals(2, hostPops)
            controller.pause().stop().start().resume()
            compose.waitForIdle()
            assertEquals(Lifecycle.State.CREATED, embedded.lifecycle.currentState)
            setVisible(true)
            assertTrue(dispatcher.hasEnabledCallbacks())
            compose.runOnIdle { dispatcher.onBackPressed() }
            assertEquals(2, sdkPops)
            compose.runOnIdle { deep.value = false }
            compose.waitForIdle()
            compose.runOnIdle { dispatcher.onBackPressed() } // visible SDK root
            assertEquals(2, sdkPops)
            assertEquals(3, hostPops)
            compose.runOnIdle { deep.value = true }
            compose.waitForIdle()
            assertTrue(dispatcher.hasEnabledCallbacks())
            controller.pause().stop()
            assertFalse(dispatcher.hasEnabledCallbacks())
            controller.start().resume()
            compose.waitForIdle()
            assertTrue(dispatcher.hasEnabledCallbacks())
        } finally {
            embedded.dispose()
            controller.pause().stop().destroy()
        }
    }
}
