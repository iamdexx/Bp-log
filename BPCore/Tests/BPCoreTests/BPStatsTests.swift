import XCTest
@testable import BPCore

final class BPStatsTests: XCTestCase {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 8) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testAverageRounds() {
        let s = [BPSample(date: date(2026, 1, 1), systolic: 121, diastolic: 81, pulse: 70),
                 BPSample(date: date(2026, 1, 2), systolic: 124, diastolic: 78, pulse: nil)]
        let avg = BPStats.average(s)!
        XCTAssertEqual(avg.systolic, 123)   // 122.5 rounds half away from zero
        XCTAssertEqual(avg.diastolic, 80)
        XCTAssertEqual(avg.pulse, 70)
        XCTAssertEqual(avg.count, 2)
        XCTAssertNil(BPStats.average([]))
    }

    func testLastDaysWindowIncludesTodayAndExcludesOlder() {
        let now = date(2026, 3, 10, 20)
        let s = [BPSample(date: date(2026, 3, 10, 7), systolic: 120, diastolic: 80),
                 BPSample(date: date(2026, 3, 4, 7), systolic: 130, diastolic: 80),   // 7th day back, in
                 BPSample(date: date(2026, 3, 3, 23), systolic: 160, diastolic: 100), // 8th day back, out
                 BPSample(date: date(2026, 3, 11, 7), systolic: 170, diastolic: 100)] // future, out
        let week = BPStats.samples(s, lastDays: 7, now: now, calendar: cal)
        XCTAssertEqual(week.map(\.systolic).sorted(), [120, 130])
    }

    func testTimeOfDay() {
        XCTAssertEqual(TimeOfDay.of(date(2026, 1, 1, 7), calendar: cal), .morning)
        XCTAssertEqual(TimeOfDay.of(date(2026, 1, 1, 13), calendar: cal), .afternoon)
        XCTAssertEqual(TimeOfDay.of(date(2026, 1, 1, 19), calendar: cal), .evening)
        XCTAssertEqual(TimeOfDay.of(date(2026, 1, 1, 23), calendar: cal), .night)
        XCTAssertEqual(TimeOfDay.of(date(2026, 1, 1, 2), calendar: cal), .night)
    }

    func testDailyAveragesSorted() {
        let s = [BPSample(date: date(2026, 1, 3), systolic: 130, diastolic: 80),
                 BPSample(date: date(2026, 1, 1, 8), systolic: 120, diastolic: 80),
                 BPSample(date: date(2026, 1, 1, 20), systolic: 124, diastolic: 84)]
        let daily = BPStats.dailyAverages(s, calendar: cal)
        XCTAssertEqual(daily.count, 2)
        XCTAssertEqual(daily[0].day, date(2026, 1, 1, 0))
        XCTAssertEqual(daily[0].average.systolic, 122)
        XCTAssertEqual(daily[0].average.diastolic, 82)
        XCTAssertEqual(daily[1].average.systolic, 130)
    }

    func testReport() {
        let now = date(2026, 3, 10, 20)
        let s = [BPSample(date: date(2026, 3, 10, 7), systolic: 142, diastolic: 91),
                 BPSample(date: date(2026, 3, 9, 19), systolic: 118, diastolic: 76),
                 BPSample(date: date(2026, 1, 1, 7), systolic: 200, diastolic: 130)]
        let r = BPReport(samples: s, period: .week, patientName: "Test", now: now, calendar: cal)
        XCTAssertEqual(r.samples.count, 2)
        XCTAssertEqual(r.overall?.systolic, 130)
        XCTAssertEqual(r.byTimeOfDay[.morning]?.systolic, 142)
        XCTAssertEqual(r.byTimeOfDay[.evening]?.systolic, 118)
        XCTAssertEqual(r.categoryCounts[.stage2], 1)
        XCTAssertEqual(r.categoryCounts[.normal], 1)
        XCTAssertEqual(r.highShare, 0.5, accuracy: 0.001)
        XCTAssertEqual(r.start, date(2026, 3, 4, 0))
    }

    func testResearchAggregateHasNoIdentifiers() throws {
        let s = [BPSample(date: date(2026, 3, 10, 7), systolic: 142, diastolic: 91, pulse: 70, note: "secret note"),
                 BPSample(date: date(2026, 3, 11, 7), systolic: 138, diastolic: 89, pulse: 72)]
        let agg = ResearchAggregate.build(from: s)
        XCTAssertEqual(agg.count, 1)
        XCTAssertEqual(agg[0].readings, 2)
        XCTAssertEqual(agg[0].meanSystolic, 140)
        let json = String(decoding: try JSONEncoder().encode(agg), as: UTF8.self)
        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("2026-03"))
    }
}
