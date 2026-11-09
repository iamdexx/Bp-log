import XCTest
@testable import BPCore

final class BLEBloodPressureTests: XCTestCase {
    private func sf(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0x0F)] }  // exponent 0, small positive mantissa

    func testMmHgWithPulseAndTime() {
        // flags: time(0x02) | pulse(0x04) | status(0x10)
        var p: [UInt8] = [0x16]
        p += sf(128) + sf(82) + sf(97)
        p += [0xE9, 0x07, 10, 24, 8, 30, 0]          // 2025-10-24 08:30:00
        p += sf(66)
        p += [0x04, 0x00]                             // irregular pulse bit
        let m = BLEBloodPressure.parse(Data(p))
        XCTAssertEqual(m?.systolic, 128); XCTAssertEqual(m?.diastolic, 82); XCTAssertEqual(m?.meanArterial, 97)
        XCTAssertEqual(m?.pulse, 66); XCTAssertEqual(m?.irregularPulse, true)
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: m!.date!)
        XCTAssertEqual([c.year, c.month, c.day, c.hour, c.minute], [2025, 10, 24, 8, 30])
    }

    func testKPaConverts() {
        // 16.0 kPa = mantissa 160, exponent -1 (0xF) -> 0xF0A0 ; 10.7 kPa -> 107 e-1 -> 0xF06B
        let p: [UInt8] = [0x01, 0xA0, 0xF0, 0x6B, 0xF0, 0xFF, 0x07]
        let m = BLEBloodPressure.parse(Data(p))
        XCTAssertEqual(m?.systolic, 120); XCTAssertEqual(m?.diastolic, 80); XCTAssertNil(m?.meanArterial)
    }

    func testRejectsShortOrImplausible() {
        XCTAssertNil(BLEBloodPressure.parse(Data([0x00, 0x01])))
        XCTAssertNil(BLEBloodPressure.parse(Data([0x00] + sf(80) + sf(120) + sf(90))))
    }
}
