import WidgetKit
import SwiftUI

/// Watch face complication: latest reading from the phone's summary.
struct FaceEntry: TimelineEntry {
    let date: Date
    let sys: Int?
    let dia: Int?
    let label: String
}

struct FaceProvider: TimelineProvider {
    private func read() -> FaceEntry {
        let d = UserDefaults(suiteName: "group.com.eticahub.bplog.watch")?.dictionary(forKey: "summary") ?? [:]
        return FaceEntry(date: Date(), sys: d["sys"] as? Int, dia: d["dia"] as? Int, label: d["label"] as? String ?? "")
    }
    func placeholder(in context: Context) -> FaceEntry { FaceEntry(date: Date(), sys: 122, dia: 78, label: "Normal") }
    func getSnapshot(in context: Context, completion: @escaping (FaceEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FaceEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct FaceView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FaceEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "heart.text.square.fill").font(.caption2)
                    Text(entry.sys.map(String.init) ?? "--").font(.system(.body, design: .rounded).weight(.bold)).monospacedDigit()
                    Text(entry.dia.map(String.init) ?? "--").font(.caption2).monospacedDigit()
                }
            case .accessoryInline:
                Text(entry.sys != nil ? "BP \(entry.sys!)/\(entry.dia!) \(entry.label)" : "BP: tap to log")
            default:
                HStack {
                    Image(systemName: "heart.text.square.fill")
                    VStack(alignment: .leading) {
                        Text(entry.sys != nil ? "\(entry.sys!)/\(entry.dia!)" : "--/--").font(.headline).monospacedDigit()
                        Text(entry.label.isEmpty ? "Blood pressure" : entry.label).font(.caption2)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

@main
struct BPLogWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BPLogFace", provider: FaceProvider()) { FaceView(entry: $0) }
            .configurationDisplayName("Blood pressure")
            .description("Your latest reading. Tap to log a new one.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
