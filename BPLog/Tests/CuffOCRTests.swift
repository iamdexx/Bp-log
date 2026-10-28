import XCTest
@testable import BPLog

final class CuffOCRTests: XCTestCase {
    func testPicksThreeBigNumbersTopToBottom() {
        // y is normalized with 1 at the top. Clock "10:45" shows as small tokens.
        let tokens: [(Int, CGFloat, CGFloat)] = [(10, 0.95, 0.03), (45, 0.95, 0.03), (128, 0.7, 0.2), (82, 0.45, 0.2), (67, 0.2, 0.15)]
        let r = CuffOCR.pick(tokens)
        XCTAssertEqual(r, .init(systolic: 128, diastolic: 82, pulse: 67))
    }

    func testRejectsImplausible() {
        XCTAssertNil(CuffOCR.pick([(60, 0.7, 0.2), (120, 0.4, 0.2)]))
        XCTAssertNil(CuffOCR.pick([(128, 0.7, 0.2)]))
    }

    func testAcceptsLowButValidReading() {
        let r = CuffOCR.pick([(68, 0.7, 0.2), (38, 0.45, 0.2), (28, 0.2, 0.15)])
        XCTAssertEqual(r, .init(systolic: 68, diastolic: 38, pulse: 28))
    }

    func testPulseOptional() {
        let r = CuffOCR.pick([(140, 0.7, 0.2), (90, 0.4, 0.2)])
        XCTAssertEqual(r, .init(systolic: 140, diastolic: 90, pulse: nil))
    }
}
