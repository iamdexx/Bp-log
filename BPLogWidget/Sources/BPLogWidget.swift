import WidgetKit
import SwiftUI
import SwiftData
import BPCore

struct BPEntry: TimelineEntry {
    let date: Date
    let latest: BPSample?
    let weekAverage: BPAverage?
}

struct BPProvider: TimelineProvider {
    func placeholder(in context: Context) -> BPEntry {
        BPEntry(date: Date(), latest: BPSample(date: Date(), systolic: 122, diastolic: 78, pulse: 68), weekAverage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BPEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BPEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Default profile only (profileID == nil); the widget has no profile switcher.
    @MainActor private func loadSamples() -> [BPSample] {
        let container = SharedContainer.make(cloud: false)
        var d = FetchDescriptor<Reading>(predicate: #Predicate { $0.profileID == nil }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = 200
        return ((try? container.mainContext.fetch(d)) ?? []).map(\.sample)
    }

    private func load() -> BPEntry {
        let samples = MainActor.assumeIsolated { loadSamples() }
        return BPEntry(date: Date(), latest: samples.first, weekAverage: BPStats.average(samples, lastDays: 7))
    }
}

struct BPWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BPEntry

    var body: some View {
        Group {
            if let s = entry.latest {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blood pressure").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(s.systolic)").font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("/\(s.diastolic)").font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: s.category.hexColor))
                    .minimumScaleFactor(0.7)
                    Text(s.category.shortTitle).font(.caption.weight(.semibold)).foregroundStyle(Color(hex: s.category.hexColor))
                    Text(s.date, style: .relative).font(.caption2).foregroundStyle(.secondary) + Text(" ago").font(.caption2).foregroundStyle(.secondary)
                    if family != .systemSmall, let a = entry.weekAverage {
                        Spacer(minLength: 2)
                        Text("7-day average \(a.systolic)/\(a.diastolic), \(a.count) readings").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "heart.text.square").font(.title)
                    Text("Tap to log your first reading").font(.caption).multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "bplog://log"))
    }
}

@main
struct BPLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BPLogLatest", provider: BPProvider()) { BPWidgetView(entry: $0) }
            .configurationDisplayName("Latest reading")
            .description("Your last blood pressure reading and 7-day average. Tap to log a new one.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension Color {
    init(hex: String) {
        var h = hex; if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
