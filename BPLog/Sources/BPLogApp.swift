import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct BPLogApp: App {
    @StateObject private var store = StoreService()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var health = HealthKitService.shared
    @StateObject private var lock = AppLockService()

    let container: ModelContainer = {
        let schema = Schema([Reading.self, VitalEntry.self, Profile.self, Medication.self, MedDose.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let c = try? ModelContainer(for: schema, configurations: [cloud]) { return c }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [local])
    }()

    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(health)
                .environmentObject(lock)
        }
        .modelContainer(container)
    }
}
