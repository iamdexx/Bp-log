import Foundation

/// Six-level blood pressure category. Thresholds and labels come from `BPGuideline.active`.
public enum BPCategory: Int, CaseIterable, Codable, Sendable, Comparable {
    case low = 0
    case normal
    case elevated
    case stage1
    case stage2
    case crisis

    public static func < (a: BPCategory, b: BPCategory) -> Bool { a.rawValue < b.rawValue }

    /// Classifies under the active guideline (`BPGuideline.active`, AHA by default).
    public static func classify(systolic: Int, diastolic: Int) -> BPCategory {
        BPGuideline.active.classify(systolic: systolic, diastolic: diastolic)
    }

    public var title: String { BPGuideline.active.title(for: self) }

    public var shortTitle: String { BPGuideline.active.shortTitle(for: self) }

    /// Plain-language range text shown on the chart legend.
    public var rangeText: String { BPGuideline.active.rangeText(for: self) }

    /// Short, non-diagnostic guidance. The app is a log, not a doctor.
    public var guidance: String {
        switch self {
        case .low: return "Lower than usual. If you feel dizzy or faint, mention it to your doctor."
        case .normal: return "In the normal range. Keep logging to see your trend."
        case .elevated: return "A little above normal. Worth watching over the next weeks."
        case .stage1: return "In the high range. Share this log with your doctor at your next visit."
        case .stage2: return "In the high range. Share this log with your doctor soon."
        case .crisis: return "Wait 5 minutes and measure again. If it is still this high, or you have chest pain, shortness of breath or vision changes, call emergency services."
        }
    }

    /// Hex colour used across the app, the chart and the PDF.
    public var hexColor: String {
        switch self {
        case .low: return "#5B8DEF"
        case .normal: return "#2E9E5B"
        case .elevated: return "#D9B300"
        case .stage1: return "#E8862A"
        case .stage2: return "#D64545"
        case .crisis: return "#8E1B1B"
        }
    }
}
