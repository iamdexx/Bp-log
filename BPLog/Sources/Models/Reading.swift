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
    /// nil = the default (first) profile, so readings from before profiles existed stay visible.
    var profileID: UUID?
    /// Comma-separated `ReadingTag` raw values.
    var tagsRaw: String = ""
    var medsTaken: Bool?

    init(date: Date = Date(), systolic: Int, diastolic: Int, pulse: Int? = nil, note: String = "", arm: String = "", source: String = "manual", healthKitUUID: String? = nil, profileID: UUID? = nil, tags: Set<ReadingTag> = [], medsTaken: Bool? = nil) {
        self.id = UUID()
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.note = note
        self.arm = arm
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.profileID = profileID
        self.tagsRaw = ReadingTag.encode(tags)
        self.medsTaken = medsTaken
    }

    var tags: Set<ReadingTag> {
        get { ReadingTag.decode(tagsRaw) }
        set { tagsRaw = ReadingTag.encode(newValue) }
    }

    /// Tags are folded into the note so the report and stats layer see them without knowing about `ReadingTag`.
    var sample: BPSample {
        let tagText = tags.map(\.title).sorted().joined(separator: ", ")
        let full = [tagText, note].filter { !$0.isEmpty }.joined(separator: ". ")
        return BPSample(id: id, date: date, systolic: systolic, diastolic: diastolic, pulse: pulse, note: full)
    }
    var category: BPCategory { sample.category }
}

/// Context chips on a reading. Doctors ask for these when a number looks odd.
enum ReadingTag: String, CaseIterable, Codable, Identifiable {
    case beforeMeds, afterMeds, afterExercise, stressed, sitting, lyingDown, irregularHeartbeat, afterCaffeine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beforeMeds: return "Before meds"
        case .afterMeds: return "After meds"
        case .afterExercise: return "After exercise"
        case .stressed: return "Stressed"
        case .sitting: return "Sitting"
        case .lyingDown: return "Lying down"
        case .irregularHeartbeat: return "Irregular heartbeat"
        case .afterCaffeine: return "After coffee"
        }
    }

    var symbol: String {
        switch self {
        case .beforeMeds: return "pills"
        case .afterMeds: return "pills.fill"
        case .afterExercise: return "figure.walk"
        case .stressed: return "bolt.heart"
        case .sitting: return "chair"
        case .lyingDown: return "bed.double"
        case .irregularHeartbeat: return "waveform.path.ecg"
        case .afterCaffeine: return "cup.and.saucer"
        }
    }

    static func encode(_ tags: Set<ReadingTag>) -> String {
        tags.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func decode(_ raw: String) -> Set<ReadingTag> {
        Set(raw.split(separator: ",").compactMap { ReadingTag(rawValue: String($0)) })
    }
}

/// A person whose readings are kept separately (you, a spouse, a parent). Free, unlimited.
@Model
final class Profile {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

enum MedSchedule: String, CaseIterable, Codable, Identifiable {
    case morning, evening, both, asNeeded
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        case .both: return "Morning and evening"
        case .asNeeded: return "As needed"
        }
    }
    var dosesPerDay: Int { self == .both ? 2 : 1 }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = ""
    var scheduleRaw: String = MedSchedule.morning.rawValue
    var isActive: Bool = true
    var createdAt: Date = Date()
    var profileID: UUID?

    init(name: String, dose: String = "", schedule: MedSchedule = .morning, profileID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.dose = dose
        self.scheduleRaw = schedule.rawValue
        self.isActive = true
        self.createdAt = Date()
        self.profileID = profileID
    }

    var schedule: MedSchedule {
        get { MedSchedule(rawValue: scheduleRaw) ?? .morning }
        set { scheduleRaw = newValue.rawValue }
    }
}

/// One "I took it" tap.
@Model
final class MedDose {
    var id: UUID = UUID()
    var medicationID: UUID = UUID()
    var date: Date = Date()
    var profileID: UUID?

    init(medicationID: UUID, date: Date = Date(), profileID: UUID? = nil) {
        self.id = UUID()
        self.medicationID = medicationID
        self.date = date
        self.profileID = profileID
    }
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
    var profileID: UUID?

    init(date: Date = Date(), kind: VitalKind, value: Double, note: String = "", source: String = "manual", healthKitUUID: String? = nil, profileID: UUID? = nil) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.value = value
        self.note = note
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.profileID = profileID
    }

    var kind: VitalKind { VitalKind(rawValue: kindRaw) ?? .heartRate }
}

extension Array where Element == Reading {
    var samples: [BPSample] { map(\.sample) }
}
