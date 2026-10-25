import Foundation
import SwiftData

/// One SwiftData store shared by the app, the widget and Siri intents via the App Group.
enum SharedContainer {
    static let appGroup = "group.com.eticahub.bplog"
    static let schema = Schema([Reading.self, VitalEntry.self, Profile.self, Medication.self, MedDose.self])

    static func make(cloud: Bool = true) -> ModelContainer {
        if cloud, let c = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, groupContainer: .identifier(appGroup), cloudKitDatabase: .automatic)]) { return c }
        if let c = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, groupContainer: .identifier(appGroup), cloudKitDatabase: .none)]) { return c }
        // Last resort (for example the App Group is not provisioned yet): a plain local store.
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
    }
}
