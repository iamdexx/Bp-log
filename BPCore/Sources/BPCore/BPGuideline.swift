import Foundation

/// Which published blood pressure classification the app uses for colours and labels.
/// All guidelines map onto the six `BPCategory` levels so charts, pills and the PDF stay the same shape.
public enum BPGuideline: Hashable, Codable, Sendable, CaseIterable, Identifiable {
    case aha2017
    case escEsh
    case whoIsh
    case jnc7
    case custom

    public static var allCases: [BPGuideline] { [.aha2017, .escEsh, .whoIsh, .jnc7, .custom] }
    public var id: String { rawKey }

    /// Process-wide guideline used by `BPSample.category` and `BPCategory` labels. The app sets it from Settings.
    nonisolated(unsafe) public static var active: BPGuideline = .aha2017
    /// Doctor-given target used by `.custom`. "At target" means strictly below both numbers.
    nonisolated(unsafe) public static var customTarget: (systolic: Int, diastolic: Int) = (130, 80)

    public var rawKey: String {
        switch self {
        case .aha2017: return "aha2017"
        case .escEsh: return "escEsh"
        case .whoIsh: return "whoIsh"
        case .jnc7: return "jnc7"
        case .custom: return "custom"
        }
    }

    public init(rawKey: String) {
        self = BPGuideline.allCases.first { $0.rawKey == rawKey } ?? .aha2017
    }

    public var title: String {
        switch self {
        case .aha2017: return "AHA / ACC (United States)"
        case .escEsh: return "ESC / ESH (Europe)"
        case .whoIsh: return "WHO / ISH"
        case .jnc7: return "JNC 7"
        case .custom: return "My doctor's target"
        }
    }

    public var shortTitle: String {
        switch self {
        case .aha2017: return "AHA"
        case .escEsh: return "ESC/ESH"
        case .whoIsh: return "WHO"
        case .jnc7: return "JNC 7"
        case .custom: return "Doctor's target"
        }
    }

    public var sourceText: String {
        switch self {
        case .aha2017: return "American Heart Association / American College of Cardiology, 2017."
        case .escEsh: return "European Society of Cardiology / European Society of Hypertension."
        case .whoIsh: return "World Health Organization / International Society of Hypertension."
        case .jnc7: return "Seventh Joint National Committee (JNC 7), United States, 2003."
        case .custom: return "The target your doctor gave you. Below both numbers counts as at target."
        }
    }

    public func classify(systolic s: Int, diastolic d: Int) -> BPCategory {
        switch self {
        case .aha2017:
            if s > 180 || d > 120 { return .crisis }
            if s >= 140 || d >= 90 { return .stage2 }
            if s >= 130 || d >= 80 { return .stage1 }
            if s >= 120 { return .elevated }
            if s < 90 || d < 60 { return .low }
            return .normal
        case .escEsh, .whoIsh:
            // Optimal, normal, high-normal, grade 1, grade 2, grade 3.
            if s >= 180 || d >= 110 { return .crisis }
            if s >= 160 || d >= 100 { return .stage2 }
            if s >= 140 || d >= 90 { return .stage1 }
            if s >= 130 || d >= 85 { return .elevated }
            if s < 90 || d < 60 { return .low }
            return .normal
        case .jnc7:
            if s > 180 || d > 120 { return .crisis }
            if s >= 160 || d >= 100 { return .stage2 }
            if s >= 140 || d >= 90 { return .stage1 }
            if s >= 120 || d >= 80 { return .elevated }
            if s < 90 || d < 60 { return .low }
            return .normal
        case .custom:
            let t = BPGuideline.customTarget
            if s > 180 || d > 120 { return .crisis }
            if s < 90 || d < 60 { return .low }
            if s < t.systolic && d < t.diastolic { return .normal }
            if s >= t.systolic + 20 || d >= t.diastolic + 10 { return .stage2 }
            return .stage1
        }
    }

    public func title(for c: BPCategory) -> String {
        switch (self, c) {
        case (.aha2017, _), (.jnc7, .low), (.jnc7, .crisis):
            switch c {
            case .low: return "Low"
            case .normal: return "Normal"
            case .elevated: return "Elevated"
            case .stage1: return "High (Stage 1)"
            case .stage2: return "High (Stage 2)"
            case .crisis: return "Very High"
            }
        case (.escEsh, _), (.whoIsh, _):
            switch c {
            case .low: return "Low"
            case .normal: return "Optimal / Normal"
            case .elevated: return "High-normal"
            case .stage1: return "Grade 1 hypertension"
            case .stage2: return "Grade 2 hypertension"
            case .crisis: return "Grade 3 hypertension"
            }
        case (.jnc7, _):
            switch c {
            case .normal: return "Normal"
            case .elevated: return "Prehypertension"
            case .stage1: return "Stage 1 hypertension"
            default: return "Stage 2 hypertension"
            }
        case (.custom, _):
            switch c {
            case .low: return "Low"
            case .normal: return "At target"
            case .elevated, .stage1: return "Above target"
            case .stage2: return "Well above target"
            case .crisis: return "Very High"
            }
        }
    }

    public func shortTitle(for c: BPCategory) -> String {
        switch self {
        case .aha2017:
            switch c {
            case .low: return "Low"; case .normal: return "Normal"; case .elevated: return "Elevated"
            case .stage1: return "Stage 1"; case .stage2: return "Stage 2"; case .crisis: return "Crisis"
            }
        case .escEsh, .whoIsh:
            switch c {
            case .low: return "Low"; case .normal: return "Normal"; case .elevated: return "High-normal"
            case .stage1: return "Grade 1"; case .stage2: return "Grade 2"; case .crisis: return "Grade 3"
            }
        case .jnc7:
            switch c {
            case .low: return "Low"; case .normal: return "Normal"; case .elevated: return "Pre-HTN"
            case .stage1: return "Stage 1"; case .stage2: return "Stage 2"; case .crisis: return "Crisis"
            }
        case .custom:
            switch c {
            case .low: return "Low"; case .normal: return "At target"; case .elevated, .stage1: return "Above"
            case .stage2: return "Well above"; case .crisis: return "Crisis"
            }
        }
    }

    public func rangeText(for c: BPCategory) -> String {
        switch self {
        case .aha2017:
            switch c {
            case .low: return "under 90 / under 60"
            case .normal: return "under 120 and under 80"
            case .elevated: return "120 to 129 and under 80"
            case .stage1: return "130 to 139 or 80 to 89"
            case .stage2: return "140 or more, or 90 or more"
            case .crisis: return "over 180 or over 120"
            }
        case .escEsh, .whoIsh:
            switch c {
            case .low: return "under 90 / under 60"
            case .normal: return "under 130 and under 85"
            case .elevated: return "130 to 139 or 85 to 89"
            case .stage1: return "140 to 159 or 90 to 99"
            case .stage2: return "160 to 179 or 100 to 109"
            case .crisis: return "180 or more, or 110 or more"
            }
        case .jnc7:
            switch c {
            case .low: return "under 90 / under 60"
            case .normal: return "under 120 and under 80"
            case .elevated: return "120 to 139 or 80 to 89"
            case .stage1: return "140 to 159 or 90 to 99"
            case .stage2: return "160 or more, or 100 or more"
            case .crisis: return "over 180 or over 120"
            }
        case .custom:
            let t = BPGuideline.customTarget
            switch c {
            case .low: return "under 90 / under 60"
            case .normal: return "under \(t.systolic) and under \(t.diastolic)"
            case .elevated, .stage1: return "\(t.systolic) or more, or \(t.diastolic) or more"
            case .stage2: return "\(t.systolic + 20) or more, or \(t.diastolic + 10) or more"
            case .crisis: return "over 180 or over 120"
            }
        }
    }

    /// Categories that actually occur under this guideline (custom has no separate "elevated").
    public var categories: [BPCategory] {
        self == .custom ? [.low, .normal, .stage1, .stage2, .crisis] : BPCategory.allCases
    }
}
