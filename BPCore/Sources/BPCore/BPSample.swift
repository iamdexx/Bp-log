import Foundation

/// A single blood pressure measurement, independent of any storage layer.
public struct BPSample: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var systolic: Int
    public var diastolic: Int
    public var pulse: Int?
    public var note: String

    public init(id: UUID = UUID(), date: Date, systolic: Int, diastolic: Int, pulse: Int? = nil, note: String = "") {
        self.id = id
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.note = note
    }

    public var category: BPCategory { BPCategory.classify(systolic: systolic, diastolic: diastolic) }

    /// Pulse pressure (systolic minus diastolic).
    public var pulsePressure: Int { systolic - diastolic }

    /// Mean arterial pressure, rounded.
    public var meanArterialPressure: Int { Int((Double(diastolic) + Double(systolic - diastolic) / 3).rounded()) }
}

public enum BPValidation {
    public static let systolicRange = 60...260
    public static let diastolicRange = 30...160
    public static let pulseRange = 25...230

    public enum Problem: Equatable, Sendable {
        case systolicOutOfRange
        case diastolicOutOfRange
        case pulseOutOfRange
        case diastolicNotBelowSystolic
    }

    public static func problems(systolic: Int, diastolic: Int, pulse: Int?) -> [Problem] {
        var out: [Problem] = []
        if !systolicRange.contains(systolic) { out.append(.systolicOutOfRange) }
        if !diastolicRange.contains(diastolic) { out.append(.diastolicOutOfRange) }
        if let pulse, !pulseRange.contains(pulse) { out.append(.pulseOutOfRange) }
        if diastolic >= systolic { out.append(.diastolicNotBelowSystolic) }
        return out
    }
}
