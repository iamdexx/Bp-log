import XCTest
import SwiftData
import BPCore
@testable import BPLog

final class ReadingModelTests: XCTestCase {
    /// The test host is the real app, which applies whatever guideline the simulator has saved; pin the one this test expects.
    @MainActor
    func testReadingRoundTripsInMemory() throws {
        let saved = BPGuideline.active
        BPGuideline.active = .aha2017
        defer { BPGuideline.active = saved }
        let container = try ModelContainer(for: Reading.self, VitalEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(Reading(systolic: 142, diastolic: 91, pulse: 70, note: "after coffee"))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<Reading>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].category, .stage2)
        XCTAssertEqual(fetched[0].sample.note, "after coffee")
    }

    func testVitalKindUnits() {
        XCTAssertEqual(VitalKind.weight.unit(metric: false), "lb")
        XCTAssertEqual(VitalKind.weight.unit(metric: true), "kg")
        XCTAssertEqual(VitalKind.bloodOxygen.unit(metric: false), "%")
    }
}
