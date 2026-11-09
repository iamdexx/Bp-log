import UIKit
import BPCore

/// Renders a `BPReport` to a US Letter PDF a doctor can read in ten seconds:
/// summary box, AHA breakdown, daily averages table, then every reading.
enum PDFReportBuilder {
    private static let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 40

    static func render(_ report: BPReport, medications: [String] = []) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: "Blood Pressure Log", kCGPDFContextCreator as String: "BP Log by EticaHub"]
            return f
        }())
        return renderer.pdfData { ctx in
            var y = startPage(ctx, report: report)

            y = drawSummary(report, at: y)
            if !medications.isEmpty { y = drawMedications(medications, at: y) }
            y = drawTimeOfDay(report, at: y)
            y = drawCategoryBreakdown(report, at: y)
            y = drawTable(title: "Daily averages", header: ["Date", "Readings", "Systolic", "Diastolic", "Pulse", "Range"],
                          rows: report.daily.map { d in
                              [Self.dayFormatter.string(from: d.day), "\(d.average.count)", "\(d.average.systolic)", "\(d.average.diastolic)",
                               d.average.pulse.map(String.init) ?? "", d.average.category.shortTitle]
                          }, ctx: ctx, report: report, y: y)
            y = drawTable(title: "All readings", header: ["Date", "Time", "Systolic", "Diastolic", "Pulse", "Range", "Note"],
                          rows: report.samples.map { s in
                              [Self.dayFormatter.string(from: s.date), Self.timeFormatter.string(from: s.date), "\(s.systolic)", "\(s.diastolic)",
                               s.pulse.map(String.init) ?? "", s.category.shortTitle, s.note]
                          }, ctx: ctx, report: report, y: y)
            _ = y
        }
    }

    // MARK: Pages

    private static func startPage(_ ctx: UIGraphicsPDFRendererContext, report: BPReport) -> CGFloat {
        ctx.beginPage()
        let title = "Blood Pressure Log"
        title.draw(at: CGPoint(x: margin, y: margin), withAttributes: attrs(22, weight: .bold))
        let sub = "\(report.period.title): \(dayFormatter.string(from: report.start)) to \(dayFormatter.string(from: report.end))"
        sub.draw(at: CGPoint(x: margin, y: margin + 28), withAttributes: attrs(12, color: .darkGray))
        if !report.patientName.isEmpty {
            let name = "Patient: \(report.patientName)"
            let w = (name as NSString).size(withAttributes: attrs(12)).width
            name.draw(at: CGPoint(x: pageSize.width - margin - w, y: margin + 4), withAttributes: attrs(12))
        }
        let footer = "Generated \(dayFormatter.string(from: report.generatedAt)) by BP Log by EticaHub. Readings were entered by the patient on a home monitor. This is a log, not a diagnosis."
        footer.draw(in: CGRect(x: margin, y: pageSize.height - margin - 20, width: pageSize.width - margin * 2, height: 30), withAttributes: attrs(8, color: .gray))
        return margin + 56
    }

    private static func ensureRoom(_ needed: CGFloat, y: inout CGFloat, ctx: UIGraphicsPDFRendererContext, report: BPReport) {
        if y + needed > pageSize.height - margin - 30 {
            y = startPage(ctx, report: report)
        }
    }

    // MARK: Sections

    private static func drawSummary(_ r: BPReport, at y0: CGFloat) -> CGFloat {
        var y = y0
        let box = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 86)
        let path = UIBezierPath(roundedRect: box, cornerRadius: 8)
        UIColor(white: 0.96, alpha: 1).setFill()
        path.fill()
        if let avg = r.overall {
            let color = UIColor(hex: avg.category.hexColor)
            "\(avg.systolic) / \(avg.diastolic)".draw(at: CGPoint(x: box.minX + 16, y: y + 14), withAttributes: attrs(30, weight: .bold))
            "mmHg average over \(avg.count) readings".draw(at: CGPoint(x: box.minX + 16, y: y + 52), withAttributes: attrs(11, color: .darkGray))
            let pill = CGRect(x: box.minX + 220, y: y + 20, width: 140, height: 26)
            color.setFill()
            UIBezierPath(roundedRect: pill, cornerRadius: 13).fill()
            let t = avg.category.title
            let tw = (t as NSString).size(withAttributes: attrs(12, weight: .semibold, color: .white)).width
            t.draw(at: CGPoint(x: pill.midX - tw / 2, y: pill.minY + 5), withAttributes: attrs(12, weight: .semibold, color: .white))
            if let pulse = avg.pulse {
                "Pulse \(pulse) bpm".draw(at: CGPoint(x: box.minX + 220, y: y + 54), withAttributes: attrs(11, color: .darkGray))
            }
            if let range = r.range {
                "Systolic \(range.systolic.lowerBound) to \(range.systolic.upperBound)".draw(at: CGPoint(x: box.minX + 390, y: y + 18), withAttributes: attrs(11))
                "Diastolic \(range.diastolic.lowerBound) to \(range.diastolic.upperBound)".draw(at: CGPoint(x: box.minX + 390, y: y + 36), withAttributes: attrs(11))
                String(format: "%.1f readings per day", r.readingsPerDay).draw(at: CGPoint(x: box.minX + 390, y: y + 54), withAttributes: attrs(11, color: .darkGray))
            }
        } else {
            "No readings in this period.".draw(at: CGPoint(x: box.minX + 16, y: y + 34), withAttributes: attrs(14, color: .darkGray))
        }
        y += 86 + 18
        return y
    }

    private static func drawMedications(_ meds: [String], at y0: CGFloat) -> CGFloat {
        var y = y0
        "Current medications".draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(13, weight: .semibold))
        y += 18
        let text = meds.joined(separator: ", ")
        let rect = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 60)
        let height = (text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: attrs(11), context: nil).height
        (text as NSString).draw(in: CGRect(x: margin, y: y, width: rect.width, height: height), withAttributes: attrs(11))
        return y + height + 14
    }

    private static func drawTimeOfDay(_ r: BPReport, at y0: CGFloat) -> CGFloat {
        var y = y0
        "By time of day".draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(13, weight: .semibold))
        y += 20
        var x = margin
        for tod in TimeOfDay.allCases {
            let avg = r.byTimeOfDay[tod]
            let text = avg.map { "\(tod.title): \($0.systolic)/\($0.diastolic) (\($0.count))" } ?? "\(tod.title): none"
            text.draw(at: CGPoint(x: x, y: y), withAttributes: attrs(11, color: avg == nil ? .gray : .black))
            x += 133
        }
        return y + 26
    }

    private static func drawCategoryBreakdown(_ r: BPReport, at y0: CGFloat) -> CGFloat {
        var y = y0
        "Readings by range (\(BPGuideline.active.shortTitle))".draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(13, weight: .semibold))
        y += 20
        let total = max(1, r.samples.count)
        let barWidth = pageSize.width - margin * 2
        var x = margin
        for cat in BPCategory.allCases {
            let n = r.categoryCounts[cat] ?? 0
            let w = barWidth * CGFloat(n) / CGFloat(total)
            if w > 0 {
                UIColor(hex: cat.hexColor).setFill()
                UIBezierPath(rect: CGRect(x: x, y: y, width: w, height: 14)).fill()
                x += w
            }
        }
        y += 20
        x = margin
        for cat in BPCategory.allCases {
            let n = r.categoryCounts[cat] ?? 0
            UIColor(hex: cat.hexColor).setFill()
            UIBezierPath(ovalIn: CGRect(x: x, y: y + 2, width: 8, height: 8)).fill()
            let t = "\(cat.shortTitle) \(n)"
            t.draw(at: CGPoint(x: x + 12, y: y), withAttributes: attrs(10))
            x += (t as NSString).size(withAttributes: attrs(10)).width + 28
        }
        return y + 28
    }

    private static func drawTable(title: String, header: [String], rows: [[String]], ctx: UIGraphicsPDFRendererContext, report: BPReport, y y0: CGFloat) -> CGFloat {
        var y = y0
        ensureRoom(60, y: &y, ctx: ctx, report: report)
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(13, weight: .semibold))
        y += 20
        let widths = columnWidths(count: header.count)
        func drawRow(_ cells: [String], bold: Bool, color: UIColor? = nil) {
            var x = margin
            for (i, cell) in cells.enumerated() {
                let rect = CGRect(x: x, y: y, width: widths[i] - 6, height: 14)
                let a = attrs(9.5, weight: bold ? .semibold : .regular, color: (i == 5 ? color : nil) ?? .black)
                (cell as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: a, context: nil)
                x += widths[i]
            }
            y += 16
        }
        drawRow(header, bold: true)
        UIColor.lightGray.setStroke()
        let line = UIBezierPath(); line.move(to: CGPoint(x: margin, y: y - 2)); line.addLine(to: CGPoint(x: pageSize.width - margin, y: y - 2)); line.stroke()
        if rows.isEmpty {
            "No readings.".draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(10, color: .gray))
            y += 16
        }
        for row in rows {
            ensureRoom(18, y: &y, ctx: ctx, report: report)
            let cat = BPCategory.allCases.first { $0.shortTitle == (row.count > 5 ? row[5] : "") }
            drawRow(row, bold: false, color: cat.map { UIColor(hex: $0.hexColor) })
        }
        return y + 16
    }

    private static func columnWidths(count: Int) -> [CGFloat] {
        let total = pageSize.width - margin * 2
        switch count {
        case 6: return [90, 60, 70, 70, 60, total - 350]
        default: return [80, 55, 60, 60, 50, 70, total - 375]
        }
    }

    // MARK: Helpers

    private static func attrs(_ size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .black) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    }

    static let dayFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f }()
    static let timeFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f }()
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
