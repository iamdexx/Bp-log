import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.modelContext) private var context
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var showLog = false

    var body: some View {
        Group {
            if settings.hasOnboarded {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .task(id: settings.healthKitSyncEnabled) {
            guard settings.healthKitSyncEnabled else { return }
            _ = await health.importNew(into: context)
        }
        .task {
            await ResearchDonationService.donateIfDue(samples: readings.samples, settings: settings)
        }
    }

    private var mainTabs: some View {
        VStack(spacing: 0) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "heart.text.square.fill") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle.portrait") }
                VitalsView()
                    .tabItem { Label("Vitals", systemImage: "waveform.path.ecg") }
                ReportView()
                    .tabItem { Label("Report", systemImage: "doc.text.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            AdSlot()
        }
    }
}
