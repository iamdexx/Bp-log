import Foundation
import SwiftData
import BPCore

@Model
final class Reading {
    var id: UUID = UUID()
    var date: Date = Date()
    var systolic: Int = 120
    var diastolic: Int = 80
    var pulse: Int?
    var note: String = ""
    var arm: String = ""
    var source: String = "manual"
    var healthKitUUID: String?

    init(date: Date = Date(), systolic: Int, diastolic: Int, pulse: Int? = nil, note: String = "", arm: String = "", source: String = "manual", healthKitUUID: String? = nil) {
        self.id = UUID()
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.note = note
        self.arm = arm
        self.source = source
        self.healthKitUUID = healthKitUUID
    }

    var sample: BPSample { BPSample(id: id, date: date, systolic: systolic, diastolic: diastolic, pulse: pulse, note: note) }
    var category: BPCategory { sample.category }
}

enum VitalKind: String, Codable, CaseIterable, Identifiable {
    case heartRate, bloodOxygen, weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate: return "Heart rate"
        case .bloodOxygen: return "Blood oxygen"
        case .weight: return "Weight"
        }
    }

    var symbol: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .bloodOxygen: return "lungs.fill"
        case .weight: return "scalemass.fill"
        }
    }

    func unit(metric: Bool) -> String {
        switch self {
        case .heartRate: return "bpm"
        case .bloodOxygen: return "%"
        case .weight: return metric ? "kg" : "lb"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .heartRate: return 25...230
        case .bloodOxygen: return 50...100
        case .weight: return 20...400
        }
    }

    var allowsDecimals: Bool { self == .weight }
}

@Model
final class VitalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = VitalKind.heartRate.rawValue
    /// Stored in canonical units: bpm, percent, kilograms.
    var value: Double = 0
    var note: String = ""
    var source: String = "manual"
    var healthKitUUID: String?

    init(date: Date = Date(), kind: VitalKind, value: Double, note: String = "", source: String = "manual", healthKitUUID: String? = nil) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.value = value
        self.note = note
        self.source = source
        self.healthKitUUID = healthKitUUID
    }

    var kind: VitalKind { VitalKind(rawValue: kindRaw) ?? .heartRate }
}

extension Array where Element == Reading {
    var samples: [BPSample] { map(\.sample) }
}
