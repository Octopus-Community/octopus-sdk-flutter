package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.Lifecycle.Event.ON_CREATE
import androidx.lifecycle.Lifecycle.Event.ON_DESTROY
import androidx.lifecycle.Lifecycle.Event.ON_PAUSE
import androidx.lifecycle.Lifecycle.Event.ON_RESUME
import androidx.lifecycle.Lifecycle.Event.ON_START
import androidx.lifecycle.Lifecycle.Event.ON_STOP
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import com.octopuscommunity.sdk.domain.model.ProfileField
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val DEFAULT_PRIMARY_MAIN = 0xFF2196F3L
private const val DEFAULT_ON_PRIMARY = 0xFFFFFFFFL

class OctopusEmbeddedView(
    private val context: Context,
    private val showBackButton: Boolean = false,
    private val themeMode: String? = null,
    private val primaryMain: Color? = null,
    private val primaryLowContrast: Color? = null,
    private val primaryHighContrast: Color? = null,
    private val onPrimary: Color? = null,
    private val logoBase64: String? = null,
    private val navBarTitle: String? = null,
    private val navBarPrimaryColor: Boolean = false,
    private val fontSizeTitle1: Int? = null,
    private val fontSizeTitle2: Int? = null,
    private val fontSizeBody1: Int? = null,
    private val fontSizeBody2: Int? = null,
    private val fontSizeCaption1: Int? = null,
    private val fontSizeCaption2: Int? = null,
    private val onNavigateToLoginCallbackId: String? = null,
    private val onModifyUserCallbackId: String? = null,
    private val onBackCallbackId: String? = null
) : PlatformView, LifecycleOwner, ViewModelStoreOwner {

    class Factory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView = when (args) {
            is Map<*, *> -> OctopusEmbeddedView(
                context = context,
                showBackButton = args["showBackButton"] as? Boolean ?: false,
                themeMode = args["themeMode"] as? String,
                primaryMain = args.getColor("primaryMain"),
                primaryLowContrast = args.getColor("primaryLowContrast"),
                primaryHighContrast = args.getColor("primaryHighContrast"),
                onPrimary = args.getColor("onPrimary"),
                logoBase64 = args["logoBase64"] as? String,
                navBarTitle = args["navBarTitle"] as? String,
                navBarPrimaryColor = args["navBarPrimaryColor"] as? Boolean ?: false,
                fontSizeTitle1 = args["fontSizeTitle1"] as? Int,
                fontSizeTitle2 = args["fontSizeTitle2"] as? Int,
                fontSizeBody1 = args["fontSizeBody1"] as? Int,
                fontSizeBody2 = args["fontSizeBody2"] as? Int,
                fontSizeCaption1 = args["fontSizeCaption1"] as? Int?,
                fontSizeCaption2 = args["fontSizeCaption2"] as? Int?,
                onNavigateToLoginCallbackId = args["onNavigateToLoginCallbackId"] as? String,
                onModifyUserCallbackId = args["onModifyUserCallbackId"] as? String,
                onBackCallbackId = args["onBackCallbackId"] as? String
            )

            else -> OctopusEmbeddedView(context)
        }
    }

    private val containerView = FrameLayout(context)

    override val lifecycle: Lifecycle = LifecycleRegistry(this)
    override val viewModelStore = ViewModelStore()

    private val lifecycleRegistry = lifecycle as LifecycleRegistry

    init {
        containerView.addView(
            ComposeView(context).apply {
                isScrollContainer = true
                isVerticalScrollBarEnabled = true
                isHorizontalScrollBarEnabled = false

                setContent {
                    MaterialTheme {
                        OctopusComposeWidget(
                            modifier = Modifier
                                .fillMaxSize()
                                .consumeWindowInsets(WindowInsets.navigationBars)
                                .consumeWindowInsets(WindowInsets.ime),
                            showBackButton = showBackButton,
                            themeMode = themeMode,
                            primaryMain = primaryMain,
                            primaryLowContrast = primaryLowContrast,
                            primaryHighContrast = primaryHighContrast,
                            onPrimary = onPrimary,
                            logoBase64 = logoBase64,
                            navBarTitle = navBarTitle,
                            navBarPrimaryColor = navBarPrimaryColor,
                            fontSizeTitle1 = fontSizeTitle1,
                            fontSizeTitle2 = fontSizeTitle2,
                            fontSizeBody1 = fontSizeBody1,
                            fontSizeBody2 = fontSizeBody2,
                            fontSizeCaption1 = fontSizeCaption1,
                            fontSizeCaption2 = fontSizeCaption2,
                            onNavigateToLogin = {
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToLogin called - sending event"
                                )
                                OctopusSdkFlutterPlugin.sendEvent("loginRequired", null)
                            },
                            onNavigateToProfileEdit = { profileField: ProfileField? ->
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToProfileEdit called - sending event"
                                )
                                val fieldToEdit = when (profileField) {
                                    ProfileField.NICKNAME -> "NICKNAME"
                                    ProfileField.PICTURE -> "AVATAR"
                                    ProfileField.BIO -> "BIO"
                                    null -> null
                                }
                                OctopusSdkFlutterPlugin.sendEvent(
                                    "editUser",
                                    mapOf("fieldToEdit" to fieldToEdit)
                                )
                            },
                            onBack = {
                                onBackCallbackId?.let {
                                    OctopusSdkFlutterPlugin.triggerCallback("onBack", it)
                                }
                            },
                        )
                    }
                }
            },
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        listOf(ON_CREATE, ON_START, ON_RESUME).forEach {
            lifecycleRegistry.handleLifecycleEvent(it)
        }
    }

    override fun getView() = containerView

    override fun dispose() {
        listOf(ON_PAUSE, ON_STOP, ON_DESTROY).forEach {
            lifecycleRegistry.handleLifecycleEvent(it)
        }
        viewModelStore.clear()
    }
}

private fun Map<*, *>.getColor(key: String): Color? =
    when (val value = get(key)) {
        is Number -> value.toLong() and 0xFFFFFFFF
        is String -> value.toLongOrNull()?.and(0xFFFFFFFF)
        else -> null
    }?.let {
        Color(it)
    }
