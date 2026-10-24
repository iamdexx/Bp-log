import Foundation
import UserNotifications

enum ReminderService {
    static let morningID = "bplog.reminder.morning"
    static let eveningID = "bplog.reminder.evening"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(morningMinutes: Int, eveningMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        for (id, minutes, body) in [(morningID, morningMinutes, "Good morning. Take your blood pressure before coffee or meds, then log it."),
                                     (eveningID, eveningMinutes, "Evening check. Sit quietly for 5 minutes, then take your reading.")] {
            var comps = DateComponents()
            comps.hour = minutes / 60
            comps.minute = minutes % 60
            let content = UNMutableNotificationContent()
            content.title = "BP Log"
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
    }
}
