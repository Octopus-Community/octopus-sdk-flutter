import Foundation
import Flutter

class OctopusEventEmitter {
    private var eventSink: FlutterEventSink?
    
    // Callbacks for showNativeUI
    var onLoginRequired: (() -> Void)?
    var onModifyUser: ((String?) -> Void)?
    
    static var shared: OctopusEventEmitter?
    
    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
        print("iOS OctopusEventEmitter: Event sink set: \(eventSink != nil)")
    }
    
    func emitLoginRequired() {
        print("iOS OctopusEventEmitter: Emitting loginRequired event")
        eventSink?(["event": "loginRequired"])
        onLoginRequired?()
    }
    
    func emitEditUser(fieldToEdit: String?) {
        print("iOS OctopusEventEmitter: Emitting editUser event: \(fieldToEdit ?? "nil")")
        var eventBody: [String: Any] = ["event": "editUser"]
        if let fieldToEdit = fieldToEdit {
            eventBody["fieldToEdit"] = fieldToEdit
        }
        eventSink?(eventBody)
        onModifyUser?(fieldToEdit)
    }
    
    func emitNavigateToLogin() {
        print("iOS OctopusEventEmitter: Emitting navigateToLogin event")
        eventSink?(["event": "navigateToLogin"])
        NotificationCenter.default.post(name: NSNotification.Name("OctopusNavigateToLogin"), object: nil)
    }

    func sendEvent(_ eventName: String, data: [String: Any]? = nil) {
        print("iOS OctopusEventEmitter: Sending event: \(eventName)")
        var eventData: [String: Any] = ["event": eventName]
        if let data { eventData.merge(data) { _, new in new } }
        eventSink?(eventData)
    }
}
