package com.octopuscommunity.octopus_sdk_flutter

import android.app.Application
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.findViewTreeViewModelStoreOwner
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.savedstate.compose.LocalSavedStateRegistryOwner
import androidx.savedstate.findViewTreeSavedStateRegistryOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotSame
import kotlin.test.assertSame
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class EmbeddedViewOwnershipTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    class ProbeViewModel(val state: SavedStateHandle) : ViewModel() {
        var clearCount = 0
        var running = false
        val work = viewModelScope.launch {
            running = true
            try {
                awaitCancellation()
            } finally {
                running = false
            }
        }

        override fun onCleared() { clearCount++ }
    }

    @Test
    fun fiveMountsUseDistinctStoresAndClearTheirViewModelsAndScopesAfterComposition() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val activity = controller.get()
        val host = FrameLayout(activity)
        activity.setContentView(host)
        val stores = mutableSetOf<Any>()
        val models = mutableSetOf<ProbeViewModel>()
        var compositionDisposals = 0
        try {
            repeat(5) { index ->
                val embedded = OctopusEmbeddedView.Factory(mock(BinaryMessenger::class.java))
                    .create(activity, index, null) as OctopusEmbeddedView
                val nativeView = (embedded.view as FrameLayout).getChildAt(0) as ComposeView
                lateinit var model: ProbeViewModel
                nativeView.setContent {
                    embedded.EmbeddedContent {
                        assertSame(embedded, LocalViewModelStoreOwner.current)
                        assertSame(embedded, LocalSavedStateRegistryOwner.current)
                        model = viewModel<ProbeViewModel>()
                        DisposableEffect(Unit) {
                            onDispose {
                                assertEquals(0, model.clearCount)
                                compositionDisposals++
                            }
                        }
                    }
                }
                host.addView(embedded.view)
                compose.waitForIdle()
                assertSame(embedded, nativeView.findViewTreeViewModelStoreOwner())
                assertSame(embedded, nativeView.findViewTreeSavedStateRegistryOwner())
                assertNotSame(activity.viewModelStore, embedded.viewModelStore)
                assertTrue(stores.add(embedded.viewModelStore))
                assertTrue(models.add(model))
                assertTrue(model.running)
                assertEquals(null, model.state.get<Int>("mount"))
                model.state["mount"] = index
                compose.runOnIdle {
                    // Flutter may dispose before the native view is detached.
                    embedded.dispose()
                    embedded.dispose()
                    host.removeView(embedded.view)
                }
                compose.waitForIdle()
                assertEquals(index + 1, compositionDisposals)
                assertEquals(1, model.clearCount)
                assertTrue(model.work.isCancelled)
                assertFalse(model.running)
                assertTrue(embedded.viewModelStore.keys().isEmpty())
            }
            assertEquals(5, stores.size)
            assertEquals(5, models.size)
        } finally {
            controller.pause().stop().destroy()
        }
    }

    class ApplicationProbeViewModel(application: Application, val state: SavedStateHandle) :
        AndroidViewModel(application)

    @Test
    fun defaultFactoryCreatesAndroidViewModelWithApplicationAndSavedStateHandle() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val embedded = OctopusEmbeddedView.Factory(mock(BinaryMessenger::class.java))
            .create(controller.get(), 9, null) as OctopusEmbeddedView
        try {
            val model = ViewModelProvider(embedded)[ApplicationProbeViewModel::class.java]
            assertSame(controller.get().application, model.getApplication<Application>())
            model.state["value"] = 42
            assertEquals(42, model.state.get<Int>("value"))
        } finally {
            embedded.dispose()
            controller.pause().stop().destroy()
        }
    }

    @Test
    fun embeddedCallbacksCarryTheirViewIdAndStopAfterDisposal() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        val events = mutableListOf<Any?>()
        val sink = object : EventChannel.EventSink {
            override fun success(event: Any?) { events.add(event) }
            override fun error(code: String, message: String?, details: Any?) = Unit
            override fun endOfStream() = Unit
        }
        OctopusEventEmitter.setEventSink(sink)
        val factory = OctopusEmbeddedView.Factory(mock(BinaryMessenger::class.java))
        val tab = factory.create(controller.get(), 7, null) as OctopusEmbeddedView
        val modal = factory.create(controller.get(), 8, null) as OctopusEmbeddedView
        try {
            tab.sendViewEvent("loginRequired")
            modal.sendViewEvent("backRequested")
            modal.sendViewEvent("navigateToProfile", mapOf("clientUserId" to "user-1"))
            assertEquals(listOf<Any?>(
                mapOf("event" to "loginRequired", "viewId" to 7),
                mapOf("event" to "backRequested", "viewId" to 8),
                mapOf("event" to "navigateToProfile", "viewId" to 8, "clientUserId" to "user-1")
            ), events)
            modal.dispose()
            modal.sendViewEvent("backRequested")
            assertEquals(3, events.size)
        } finally {
            tab.dispose()
            modal.dispose()
            OctopusEventEmitter.clearEventSink(sink)
            controller.pause().stop().destroy()
        }
    }
}
