import Foundation

public struct BPAverage: Equatable, Sendable {
    public var systolic: Int
    public var diastolic: Int
    public var pulse: Int?
    public var count: Int

    public var category: BPCategory { BPCategory.classify(systolic: systolic, diastolic: diastolic) }
}

public enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    case morning, afternoon, evening, night

    public static func of(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    public var title: String { rawValue.capitalized }
}

public enum ReportPeriod: Int, CaseIterable, Codable, Sendable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90

    public var id: Int { rawValue }
    public var days: Int { rawValue }
    public var title: String {
        switch self {
        case .week: return "7 days"
        case .month: return "30 days"
        case .quarter: return "90 days"
        }
    }
}

public enum BPStats {
    public static func average(_ samples: [BPSample]) -> BPAverage? {
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)
        let sys = Double(samples.reduce(0) { $0 + $1.systolic }) / n
        let dia = Double(samples.reduce(0) { $0 + $1.diastolic }) / n
        let pulses = samples.compactMap(\.pulse)
        let pulse = pulses.isEmpty ? nil : Int((Double(pulses.reduce(0, +)) / Double(pulses.count)).rounded())
        return BPAverage(systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()), pulse: pulse, count: samples.count)
    }

    /// Samples whose date is within the last `days` days before `now` (inclusive of today).
    public static func samples(_ samples: [BPSample], lastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> [BPSample] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) else { return [] }
        return samples.filter { $0.date >= start && $0.date <= now }
    }

    public static func average(_ samples: [BPSample], lastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> BPAverage? {
        average(self.samples(samples, lastDays: days, now: now, calendar: calendar))
    }

    public static func averagesByTimeOfDay(_ samples: [BPSample], calendar: Calendar = .current) -> [TimeOfDay: BPAverage] {
        var out: [TimeOfDay: BPAverage] = [:]
        for tod in TimeOfDay.allCases {
            if let avg = average(samples.filter { TimeOfDay.of($0.date, calendar: calendar) == tod }) {
                out[tod] = avg
            }
        }
        return out
    }

    public static func categoryCounts(_ samples: [BPSample]) -> [BPCategory: Int] {
        var out: [BPCategory: Int] = [:]
        for s in samples { out[s.category, default: 0] += 1 }
        return out
    }

    /// Daily averages, oldest first. Used for the trend chart and the PDF table.
    public static func dailyAverages(_ samples: [BPSample], calendar: Calendar = .current) -> [(day: Date, average: BPAverage)] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted().compactMap { day in
            guard let avg = average(grouped[day] ?? []) else { return nil }
            return (day, avg)
        }
    }

    public static func minMax(_ samples: [BPSample]) -> (systolic: ClosedRange<Int>, diastolic: ClosedRange<Int>)? {
        guard let s0 = samples.first else { return nil }
        var sMin = s0.systolic, sMax = s0.systolic, dMin = s0.diastolic, dMax = s0.diastolic
        for s in samples {
            sMin = min(sMin, s.systolic); sMax = max(sMax, s.systolic)
            dMin = min(dMin, s.diastolic); dMax = max(dMax, s.diastolic)
        }
        return (sMin...sMax, dMin...dMax)
    }
}
