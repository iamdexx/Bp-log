import Foundation
import SwiftUI
import BPCore

/// Small on-device preferences. Nothing here leaves the phone.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("hasOnboarded") var hasOnboarded = false
    @AppStorage("patientName") var patientName = ""
    @AppStorage("useMetricWeight") var useMetricWeight = false
    @AppStorage("healthKitSyncEnabled") var healthKitSyncEnabled = false
    @AppStorage("remindersEnabled") var remindersEnabled = false
    @AppStorage("morningReminderMinutes") var morningReminderMinutes = 8 * 60
    @AppStorage("eveningReminderMinutes") var eveningReminderMinutes = 20 * 60
    @AppStorage("researchDonationEnabled") var researchDonationEnabled = false
    @AppStorage("lastResearchDonationISOWeek") var lastResearchDonationISOWeek = ""
    @AppStorage("defaultArm") var defaultArm = "Left"
    @AppStorage("lastReviewPromptReadingCount") var lastReviewPromptReadingCount = 0
    /// Empty string = the default profile (readings with profileID == nil).
    @AppStorage("activeProfileID") var activeProfileID = ""
    @AppStorage("guideline") var guidelineRaw = BPGuideline.aha2017.rawKey
    @AppStorage("targetSystolic") var targetSystolic = 130
    @AppStorage("targetDiastolic") var targetDiastolic = 80
    @AppStorage("appLockEnabled") var appLockEnabled = false

    private init() { applyGuideline() }

    var activeProfileUUID: UUID? { UUID(uuidString: activeProfileID) }

    var guideline: BPGuideline {
        get { BPGuideline(rawKey: guidelineRaw) }
        set { guidelineRaw = newValue.rawKey; applyGuideline() }
    }

    /// Pushes the chosen guideline into BPCore so every category label and colour follows it.
    func applyGuideline() {
        BPGuideline.customTarget = (targetSystolic, targetDiastolic)
        BPGuideline.active = BPGuideline(rawKey: guidelineRaw)
    }
}
