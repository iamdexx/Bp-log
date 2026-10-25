import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct BPLogApp: App {
    @StateObject private var store = StoreService()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var health = HealthKitService.shared
    @StateObject private var lock = AppLockService()

    let container = SharedContainer.make()

    init() {
        MobileAds.shared.start()
        BPLogShortcuts.updateAppShortcutParameters()
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
