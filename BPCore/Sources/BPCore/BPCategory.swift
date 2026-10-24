import Foundation

/// American Heart Association / ACC 2017 blood pressure categories.
public enum BPCategory: Int, CaseIterable, Codable, Sendable, Comparable {
    case low = 0
    case normal
    case elevated
    case stage1
    case stage2
    case crisis

    public static func < (a: BPCategory, b: BPCategory) -> Bool { a.rawValue < b.rawValue }

    public static func classify(systolic: Int, diastolic: Int) -> BPCategory {
        if systolic > 180 || diastolic > 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90 { return .stage2 }
        if systolic >= 130 || diastolic >= 80 { return .stage1 }
        if systolic >= 120 { return .elevated }
        if systolic < 90 || diastolic < 60 { return .low }
        return .normal
    }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .stage1: return "High (Stage 1)"
        case .stage2: return "High (Stage 2)"
        case .crisis: return "Very High"
        }
    }

    public var shortTitle: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .stage1: return "Stage 1"
        case .stage2: return "Stage 2"
        case .crisis: return "Crisis"
        }
    }

    /// Plain-language range text shown on the chart legend.
    public var rangeText: String {
        switch self {
        case .low: return "under 90 / under 60"
        case .normal: return "under 120 and under 80"
        case .elevated: return "120 to 129 and under 80"
        case .stage1: return "130 to 139 or 80 to 89"
        case .stage2: return "140 or more, or 90 or more"
        case .crisis: return "over 180 or over 120"
        }
    }

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
