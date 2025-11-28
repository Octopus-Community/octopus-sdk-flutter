import Foundation
import Flutter

class OctopusEventEmitter {
    private var eventSink: FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    
    // Callbacks for showNativeUI
    var onLoginRequired: (() -> Void)?
    var onModifyUser: ((String?) -> Void)?
    
    static var shared: OctopusEventEmitter?
    
    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
        print("iOS OctopusEventEmitter: Event sink set: \(eventSink != nil)")
    }
    
    func setMethodChannel(_ methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
        print("iOS OctopusEventEmitter: Method channel set")
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
    
    func emitUserTokenRequest(requestId: String) {
        print("iOS OctopusEventEmitter: Emitting userTokenRequest event: \(requestId)")
        eventSink?([
            "event": "userTokenRequest",
            "requestId": requestId
        ])
    }
    
    func emitNavigateToLogin() {
        print("iOS OctopusEventEmitter: Emitting navigateToLogin event")
        eventSink?(["event": "navigateToLogin"])
        NotificationCenter.default.post(name: NSNotification.Name("OctopusNavigateToLogin"), object: nil)
    }
}
