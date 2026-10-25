import Foundation
import SwiftData

/// One SwiftData store shared by the app, the widget and Siri intents via the App Group.
enum SharedContainer {
    static let appGroup = "group.com.eticahub.bplog"
    static let schema = Schema([Reading.self, VitalEntry.self, Profile.self, Medication.self, MedDose.self])

    /// `groupContainer: .identifier` traps (it does not throw) when the App Group is missing from the entitlements,
    /// e.g. an unsigned simulator build, so ask the system for the container URL first and only use it when there is one.
    static var groupStoreURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent("BPLog.store")
    }

    static func make(cloud: Bool = true) -> ModelContainer {
        if let url = groupStoreURL {
            if cloud, let c = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)]) { return c }
            if let c = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]) { return c }
        }
        // Last resort (for example the App Group is not provisioned yet): a plain local store.
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
    }
}
