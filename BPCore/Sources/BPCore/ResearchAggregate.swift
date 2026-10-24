import Foundation

/// The only thing the optional research donation ever sends: weekly averages, counts, and a coarse
/// category histogram. No dates finer than the ISO week, no notes, no identifiers.
public struct ResearchAggregate: Codable, Equatable, Sendable {
    public var schema: String = "bplog.weekly.v1"
    public var isoYear: Int
    public var isoWeek: Int
    public var readings: Int
    public var meanSystolic: Int
    public var meanDiastolic: Int
    public var meanPulse: Int?
    public var categoryCounts: [String: Int]

    public static func build(from samples: [BPSample], calendar: Calendar = Calendar(identifier: .iso8601)) -> [ResearchAggregate] {
        let grouped = Dictionary(grouping: samples) { s -> String in
            let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: s.date)
            return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
        }
        return grouped.values.compactMap { week -> ResearchAggregate? in
            guard let first = week.first, let avg = BPStats.average(week) else { return nil }
            let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first.date)
            var counts: [String: Int] = [:]
            for s in week { counts[s.category.shortTitle, default: 0] += 1 }
            return ResearchAggregate(isoYear: c.yearForWeekOfYear ?? 0, isoWeek: c.weekOfYear ?? 0, readings: week.count,
                                     meanSystolic: avg.systolic, meanDiastolic: avg.diastolic, meanPulse: avg.pulse, categoryCounts: counts)
        }
        .sorted { ($0.isoYear, $0.isoWeek) < ($1.isoYear, $1.isoWeek) }
    }
}
