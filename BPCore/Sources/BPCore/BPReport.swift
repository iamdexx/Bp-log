import Foundation

/// Everything the PDF renderer needs, computed once so the layout code stays dumb.
public struct BPReport: Sendable {
    public var period: ReportPeriod
    public var generatedAt: Date
    public var start: Date
    public var end: Date
    public var samples: [BPSample]
    public var overall: BPAverage?
    public var byTimeOfDay: [TimeOfDay: BPAverage]
    public var categoryCounts: [BPCategory: Int]
    public var daily: [(day: Date, average: BPAverage)]
    public var range: (systolic: ClosedRange<Int>, diastolic: ClosedRange<Int>)?
    public var patientName: String

    public init(samples all: [BPSample], period: ReportPeriod, patientName: String = "", now: Date = Date(), calendar: Calendar = .current) {
        self.period = period
        self.generatedAt = now
        self.patientName = patientName
        let inPeriod = BPStats.samples(all, lastDays: period.days, now: now, calendar: calendar).sorted { $0.date < $1.date }
        self.samples = inPeriod
        self.end = now
        self.start = calendar.date(byAdding: .day, value: -(period.days - 1), to: calendar.startOfDay(for: now)) ?? now
        self.overall = BPStats.average(inPeriod)
        self.byTimeOfDay = BPStats.averagesByTimeOfDay(inPeriod, calendar: calendar)
        self.categoryCounts = BPStats.categoryCounts(inPeriod)
        self.daily = BPStats.dailyAverages(inPeriod, calendar: calendar)
        self.range = BPStats.minMax(inPeriod)
    }

    public var readingsPerDay: Double {
        guard period.days > 0 else { return 0 }
        return Double(samples.count) / Double(period.days)
    }

    /// Share of readings at or above Stage 1.
    public var highShare: Double {
        guard !samples.isEmpty else { return 0 }
        let high = samples.filter { $0.category >= .stage1 }.count
        return Double(high) / Double(samples.count)
    }
}
