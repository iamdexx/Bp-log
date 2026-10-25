import AppIntents
import SwiftData
import WidgetKit
import BPCore

/// "Hey Siri, log my blood pressure in BP Log" -> Siri asks for the two numbers, saves, reads back the range.
struct LogBloodPressureIntent: AppIntent {
    static var title: LocalizedStringResource = "Log blood pressure"
    static var description = IntentDescription("Saves a blood pressure reading to BP Log.")
    static var openAppWhenRun = false

    @Parameter(title: "Systolic (top number)", inclusiveRange: (60, 260)) var systolic: Int
    @Parameter(title: "Diastolic (bottom number)", inclusiveRange: (30, 160)) var diastolic: Int
    @Parameter(title: "Pulse", inclusiveRange: (25, 230)) var pulse: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$systolic) over \(\.$diastolic)") { \.$pulse }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let problems = BPValidation.problems(systolic: systolic, diastolic: diastolic, pulse: pulse)
        guard problems.isEmpty else {
            throw $systolic.needsValueError("The bottom number has to be lower than the top number. What is the top number?")
        }
        let container = SharedContainer.make()
        let reading = Reading(systolic: systolic, diastolic: diastolic, pulse: pulse, source: "siri", profileID: AppSettings.shared.activeProfileUUID)
        container.mainContext.insert(reading)
        try container.mainContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        let c = reading.category
        return .result(dialog: "Saved \(systolic) over \(diastolic). That is \(c.title.lowercased()).")
    }
}

struct OpenLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Open BP Log to a new reading"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openNewReading, object: nil)
        return .result()
    }
}

extension Notification.Name { static let openNewReading = Notification.Name("openNewReading") }

struct BPLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogBloodPressureIntent(),
                    phrases: ["Log my blood pressure in \(.applicationName)", "Add a blood pressure reading to \(.applicationName)", "Record my blood pressure in \(.applicationName)"],
                    shortTitle: "Log blood pressure", systemImageName: "heart.text.square.fill")
        AppShortcut(intent: OpenLogIntent(),
                    phrases: ["Open \(.applicationName) to log a reading"],
                    shortTitle: "New reading", systemImageName: "plus.circle.fill")
    }
}
