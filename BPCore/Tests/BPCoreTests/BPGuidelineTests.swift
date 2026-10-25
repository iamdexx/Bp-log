import XCTest
@testable import BPCore

final class BPGuidelineTests: XCTestCase {
    override func tearDown() { BPGuideline.active = .aha2017; BPGuideline.customTarget = (130, 80) }

    func testESC() {
        let g = BPGuideline.escEsh
        XCTAssertEqual(g.classify(systolic: 118, diastolic: 76), .normal)
        XCTAssertEqual(g.classify(systolic: 128, diastolic: 84), .normal)
        XCTAssertEqual(g.classify(systolic: 135, diastolic: 84), .elevated)
        XCTAssertEqual(g.classify(systolic: 145, diastolic: 80), .stage1)
        XCTAssertEqual(g.classify(systolic: 165, diastolic: 95), .stage2)
        XCTAssertEqual(g.classify(systolic: 150, diastolic: 112), .crisis)
    }

    func testJNC7() {
        let g = BPGuideline.jnc7
        XCTAssertEqual(g.classify(systolic: 125, diastolic: 82), .elevated)
        XCTAssertEqual(g.classify(systolic: 150, diastolic: 95), .stage1)
        XCTAssertEqual(g.classify(systolic: 162, diastolic: 80), .stage2)
    }

    func testCustomTarget() {
        BPGuideline.customTarget = (140, 90)
        let g = BPGuideline.custom
        XCTAssertEqual(g.classify(systolic: 139, diastolic: 89), .normal)
        XCTAssertEqual(g.classify(systolic: 142, diastolic: 85), .stage1)
        XCTAssertEqual(g.classify(systolic: 160, diastolic: 85), .stage2)
        XCTAssertEqual(g.title(for: .normal), "At target")
    }

    func testActiveGuidelineDrivesSampleCategory() {
        let s = BPSample(date: Date(), systolic: 135, diastolic: 84)
        XCTAssertEqual(s.category, .stage1)
        BPGuideline.active = .escEsh
        XCTAssertEqual(s.category, .elevated)
        XCTAssertEqual(BPCategory.elevated.title, "High-normal")
    }

    func testRawKeyRoundTrip() {
        for g in BPGuideline.allCases { XCTAssertEqual(BPGuideline(rawKey: g.rawKey), g) }
        XCTAssertEqual(BPGuideline(rawKey: "garbage"), .aha2017)
    }
}
