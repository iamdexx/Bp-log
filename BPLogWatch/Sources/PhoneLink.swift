import Foundation
import WatchConnectivity
import WidgetKit

/// Watch side: sends readings to the phone, keeps the phone's latest summary for the face and the app.
final class PhoneLink: NSObject, ObservableObject {
    static let shared = PhoneLink()
    static let defaults = UserDefaults(suiteName: "group.com.eticahub.bplog.watch") ?? .standard

    @Published var summary: [String: Any] = PhoneLink.defaults.dictionary(forKey: "summary") ?? [:]
    @Published var lastSent: Date?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(systolic: Int, diastolic: Int, pulse: Int?) {
        var info: [String: Any] = ["sys": systolic, "dia": diastolic, "date": Date().timeIntervalSince1970]
        if let pulse { info["pulse"] = pulse }
        let s = WCSession.default
        if s.isReachable {
            s.sendMessage(info, replyHandler: nil) { _ in s.transferUserInfo(info) }
        } else {
            s.transferUserInfo(info)   // queued, delivered when the phone is around
        }
        lastSent = Date()
    }

    private func store(_ ctx: [String: Any]) {
        DispatchQueue.main.async {
            self.summary = ctx
            PhoneLink.defaults.set(ctx, forKey: "summary")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

extension PhoneLink: WCSessionDelegate {
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if !s.receivedApplicationContext.isEmpty { store(s.receivedApplicationContext) }
    }
    func session(_ s: WCSession, didReceiveApplicationContext ctx: [String: Any]) { store(ctx) }
}
