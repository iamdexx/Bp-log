import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit
import BPCore

/// Phone side of the Apple Watch link. Receives readings logged on the wrist and pushes a summary back for the watch face.
@MainActor
final class WatchSyncService: NSObject, ObservableObject {
    static let shared = WatchSyncService()
    private var container: ModelContainer?

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Latest reading and 7-day average, sent as application context so the watch always has the newest copy.
    func pushSummary(_ samples: [BPSample]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        var ctx: [String: Any] = ["updated": Date().timeIntervalSince1970]
        if let l = samples.max(by: { $0.date < $1.date }) {
            ctx["sys"] = l.systolic; ctx["dia"] = l.diastolic; ctx["date"] = l.date.timeIntervalSince1970
            ctx["label"] = l.category.shortTitle; ctx["hex"] = l.category.hexColor
            if let p = l.pulse { ctx["pulse"] = p }
        }
        if let a = BPStats.average(samples, lastDays: 7) { ctx["weekSys"] = a.systolic; ctx["weekDia"] = a.diastolic; ctx["weekCount"] = a.count }
        try? WCSession.default.updateApplicationContext(ctx)
    }

    private func insert(_ info: [String: Any]) {
        guard let container, let sys = info["sys"] as? Int, let dia = info["dia"] as? Int,
              BPValidation.problems(systolic: sys, diastolic: dia, pulse: info["pulse"] as? Int).isEmpty else { return }
        let date = (info["date"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let ctx = container.mainContext
        let r = Reading(date: date, systolic: sys, diastolic: dia, pulse: info["pulse"] as? Int, source: "watch", profileID: AppSettings.shared.activeProfileUUID)
        ctx.insert(r)
        try? ctx.save()
        WidgetCenter.shared.reloadAllTimelines()
        let all = (try? ctx.fetch(FetchDescriptor<Reading>())) ?? []
        pushSummary(all.filter { $0.profileID == AppSettings.shared.activeProfileUUID }.map(\.sample))
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ s: WCSession) {}
    nonisolated func sessionDidDeactivate(_ s: WCSession) { s.activate() }
    nonisolated func session(_ s: WCSession, didReceiveUserInfo info: [String: Any] = [:]) {
        Task { @MainActor in self.insert(info) }
    }
    nonisolated func session(_ s: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in self.insert(message); replyHandler(["ok": true]) }
    }
}
