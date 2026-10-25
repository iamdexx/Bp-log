import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var lock: AppLockService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if settings.hasOnboarded {
                MainTabs(profileID: settings.activeProfileUUID)
                    .id(settings.activeProfileID)
            } else {
                OnboardingView()
            }
            if lock.isLocked {
                LockView().transition(.opacity).zIndex(1)
            }
        }
        .onAppear { if settings.appLockEnabled { lock.lock() } }
        .onChange(of: scenePhase) { _, phase in
            guard settings.appLockEnabled else { return }
            if phase == .background { lock.lock() }
        }
        .onChange(of: settings.guidelineRaw) { settings.applyGuideline() }
        .onChange(of: settings.targetSystolic) { settings.applyGuideline() }
        .onChange(of: settings.targetDiastolic) { settings.applyGuideline() }
    }
}

/// Everything below here is scoped to one person. RootView re-creates it when the profile changes.
private struct MainTabs: View {
    let profileID: UUID?
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.modelContext) private var context
    @Query private var readings: [Reading]

    init(profileID: UUID?) {
        self.profileID = profileID
        _readings = Query(filter: #Predicate<Reading> { $0.profileID == profileID }, sort: [SortDescriptor(\Reading.date, order: .reverse)])
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                HomeView(profileID: profileID)
                    .tabItem { Label("Home", systemImage: "heart.text.square.fill") }
                HistoryView(profileID: profileID)
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle.portrait") }
                VitalsView(profileID: profileID)
                    .tabItem { Label("Vitals", systemImage: "waveform.path.ecg") }
                ReportView(profileID: profileID)
                    .tabItem { Label("Report", systemImage: "doc.text.fill") }
                SettingsView(profileID: profileID)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            AdSlot()
        }
        .task(id: settings.healthKitSyncEnabled) {
            guard settings.healthKitSyncEnabled, profileID == nil else { return }
            _ = await health.importNew(into: context)
        }
        .task {
            await ResearchDonationService.donateIfDue(samples: readings.samples, settings: settings)
        }
    }
}
