import SwiftUI
import BPCore

extension Color {
    init(hex: String) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

extension BPCategory {
    var color: Color { Color(hex: hexColor) }
}

struct CategoryPill: View {
    let category: BPCategory
    var compact = false
    /// Observed so the label re-renders when the guideline changes; `BPGuideline.active` alone is not state SwiftUI tracks.
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Text(compact ? settings.guideline.shortTitle(for: category) : settings.guideline.title(for: category))
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 3 : 6)
            .background(category.color, in: Capsule())
    }
}

struct BigButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }
}

struct ReadingRow: View {
    let reading: Reading

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(reading.category.color)
                .frame(width: 6, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(reading.systolic)/\(reading.diastolic)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    if let pulse = reading.pulse {
                        Text("· \(pulse) bpm").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(reading.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    if !reading.note.isEmpty { Text("· \(reading.note)").lineLimit(1) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !reading.tags.isEmpty {
                    Text(reading.tags.map(\.title).sorted().joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            CategoryPill(category: reading.category, compact: true)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    var systemImage = "heart.text.square"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}

struct LegendView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let guideline = settings.guideline
        VStack(alignment: .leading, spacing: 8) {
            ForEach(guideline.categories, id: \.self) { c in
                HStack(spacing: 10) {
                    Circle().fill(c.color).frame(width: 12, height: 12)
                    Text(guideline.title(for: c)).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(guideline.rangeText(for: c)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
