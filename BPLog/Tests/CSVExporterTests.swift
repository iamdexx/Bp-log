import XCTest
@testable import BPLog

final class CSVExporterTests: XCTestCase {
    func testTagsRoundTrip() {
        let r = Reading(systolic: 128, diastolic: 82, tags: [.afterMeds, .sitting])
        XCTAssertEqual(r.tags, [.afterMeds, .sitting])
        XCTAssertEqual(r.tagsRaw, "afterMeds,sitting")
        XCTAssertTrue(r.sample.note.contains("After meds"))
    }

    func testCSVEscapesAndOrders() {
        let a = Reading(date: Date(timeIntervalSince1970: 86_400 * 2), systolic: 150, diastolic: 95, note: "said \"hi\", felt odd")
        let b = Reading(date: Date(timeIntervalSince1970: 86_400), systolic: 118, diastolic: 76, pulse: 64, arm: "Left")
        let csv = CSVExporter.render([a, b])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[0]), CSVExporter.header.joined(separator: ","))
        XCTAssertTrue(lines[1].contains(",118,76,64,"), "oldest first")
        XCTAssertTrue(lines[2].contains("\"said \"\"hi\"\", felt odd\""))
    }
}
