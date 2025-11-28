package com.octopuscommunity.octopus_sdk_flutter

import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class OctopusEventEmitter {
    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    
    companion object {
        @Volatile
        private var INSTANCE: OctopusEventEmitter? = null
        
        fun getInstance(): OctopusEventEmitter? = INSTANCE
        
        fun setInstance(instance: OctopusEventEmitter) {
            INSTANCE = instance
        }
    }
    
    fun setEventSink(eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
        Log.d("OctopusEventEmitter", "Event sink set: ${eventSink != null}")
    }
    
    fun setMethodChannel(methodChannel: MethodChannel) {
        this.methodChannel = methodChannel
        Log.d("OctopusEventEmitter", "Method channel set")
    }
    
    fun emitLoginRequired() {
        Log.d("OctopusEventEmitter", "Emitting loginRequired event")
        eventSink?.success(mapOf("event" to "loginRequired"))
    }
    
    fun emitEditUser(fieldToEdit: String?) {
        Log.d("OctopusEventEmitter", "Emitting editUser event: $fieldToEdit")
        eventSink?.success(mapOf(
            "event" to "editUser",
            "fieldToEdit" to fieldToEdit
        ))
    }
    
    fun emitUserTokenRequest(requestId: String) {
        Log.d("OctopusEventEmitter", "Emitting userTokenRequest event: $requestId")
        eventSink?.success(mapOf(
            "event" to "userTokenRequest",
            "requestId" to requestId
        ))
    }
    
    fun emitNavigateToLogin() {
        Log.d("OctopusEventEmitter", "Emitting navigateToLogin event")
        eventSink?.success(mapOf("event" to "navigateToLogin"))
    }

    fun sendEvent(eventName: String, data: Map<String, Any?>?) {
        Log.d("OctopusEventEmitter", "Sending event: $eventName, data: $data")
        val eventData = mutableMapOf<String, Any?>("event" to eventName)
        data?.let { eventData.putAll(it) }
        eventSink?.success(eventData)
    }
}
