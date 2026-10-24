import Foundation
import SwiftUI

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

    private init() {}
}
