import XCTest
@testable import BPCore

final class BPCategoryTests: XCTestCase {
    func testAHABands() {
        XCTAssertEqual(BPCategory.classify(systolic: 118, diastolic: 76), .normal)
        XCTAssertEqual(BPCategory.classify(systolic: 119, diastolic: 79), .normal)
        XCTAssertEqual(BPCategory.classify(systolic: 120, diastolic: 79), .elevated)
        XCTAssertEqual(BPCategory.classify(systolic: 129, diastolic: 79), .elevated)
        XCTAssertEqual(BPCategory.classify(systolic: 125, diastolic: 80), .stage1)
        XCTAssertEqual(BPCategory.classify(systolic: 130, diastolic: 70), .stage1)
        XCTAssertEqual(BPCategory.classify(systolic: 139, diastolic: 89), .stage1)
        XCTAssertEqual(BPCategory.classify(systolic: 140, diastolic: 85), .stage2)
        XCTAssertEqual(BPCategory.classify(systolic: 135, diastolic: 90), .stage2)
        XCTAssertEqual(BPCategory.classify(systolic: 180, diastolic: 120), .stage2)
        XCTAssertEqual(BPCategory.classify(systolic: 181, diastolic: 100), .crisis)
        XCTAssertEqual(BPCategory.classify(systolic: 150, diastolic: 121), .crisis)
        XCTAssertEqual(BPCategory.classify(systolic: 88, diastolic: 58), .low)
        XCTAssertEqual(BPCategory.classify(systolic: 95, diastolic: 55), .low)
    }

    func testOrdering() {
        XCTAssertTrue(BPCategory.normal < BPCategory.stage1)
        XCTAssertTrue(BPCategory.stage2 < BPCategory.crisis)
    }

    func testValidation() {
        XCTAssertTrue(BPValidation.problems(systolic: 120, diastolic: 80, pulse: 70).isEmpty)
        XCTAssertEqual(BPValidation.problems(systolic: 80, diastolic: 90, pulse: nil), [.diastolicNotBelowSystolic])
        XCTAssertEqual(BPValidation.problems(systolic: 300, diastolic: 80, pulse: 10), [.systolicOutOfRange, .pulseOutOfRange])
    }
}
