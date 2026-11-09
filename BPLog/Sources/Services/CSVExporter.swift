import Foundation
import BPCore

/// Spreadsheet export of the readings. Same columns as the PDF table plus arm and tags.
enum CSVExporter {
    static let header = ["Date", "Time", "Systolic", "Diastolic", "Pulse", "Range", "Arm", "Tags", "Meds taken", "Note", "Source"]

    static func render(_ readings: [Reading], guideline: BPGuideline = BPGuideline.active) -> String {
        let date = DateFormatter(); date.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter(); time.dateFormat = "HH:mm"
        var lines = [header.joined(separator: ",")]
        for r in readings.sorted(by: { $0.date < $1.date }) {
            let row: [String] = [
                date.string(from: r.date),
                time.string(from: r.date),
                String(r.systolic),
                String(r.diastolic),
                r.pulse.map(String.init) ?? "",
                guideline.title(for: guideline.classify(systolic: r.systolic, diastolic: r.diastolic)),
                r.arm,
                r.tags.map(\.title).sorted().joined(separator: "; "),
                r.medsTaken.map { $0 ? "yes" : "no" } ?? "",
                r.note,
                r.source
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        if field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
