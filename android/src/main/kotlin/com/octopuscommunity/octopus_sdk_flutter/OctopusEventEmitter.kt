package com.octopuscommunity.octopus_sdk_flutter

import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Process-static event emitter for the Octopus Flutter plugin.
 *
 * The active [EventChannel.EventSink] is held as a process-static field rather
 * than a per-`FlutterPlugin`-instance reference. A Flutter app may host more
 * than one `FlutterEngine` in the same process (notably,
 * `firebase_messaging` spawns a headless background engine shortly after
 * launch, which re-runs every registered plugin's `onAttachedToEngine`). If
 * the active sink were tracked per plugin instance — or fetched from a
 * process-static plugin/emitter `INSTANCE` overwritten by every attach — the
 * second attach would reparent dispatch to an emitter whose sink is never
 * set, and every event sent to the *foreground* Dart isolate would silently
 * drop. Keeping the sink itself as the authority means whichever engine's
 * isolate actually subscribed to `octopus_sdk_flutter/events` owns dispatch,
 * regardless of how many plugin instances exist.
 */
object OctopusEventEmitter {
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        synchronized(this) {
            eventSink = sink
        }
        Log.d("OctopusEventEmitter", "Event sink set: ${sink != null}")
    }

    /**
     * Compare-and-clear: wipe the active sink only if it matches [sink].
     * Defensive against a stale `onCancel` from a secondary FlutterEngine
     * wiping the foreground engine's sink.
     */
    fun clearEventSink(sink: EventChannel.EventSink) {
        synchronized(this) {
            if (eventSink === sink) eventSink = null
        }
        Log.d("OctopusEventEmitter", "Event sink cleared")
    }

    fun sendEvent(eventName: String, data: Map<String, Any?>?) {
        val sink = eventSink
        Log.d("OctopusEventEmitter", "Sending event: $eventName, hasSink: ${sink != null}, data: $data")
        if (sink == null) return
        val eventData = mutableMapOf<String, Any?>("event" to eventName)
        data?.let { eventData.putAll(it) }
        sink.success(eventData)
    }
}
