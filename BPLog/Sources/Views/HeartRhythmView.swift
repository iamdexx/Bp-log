import SwiftUI
import HealthKit

/// ECG recordings and irregular-rhythm alerts from Apple Health. Read only; the Watch records them.
struct HeartRhythmView: View {
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var settings: AppSettings
    @State private var ecgs: [HealthKitService.ECGRecord] = []
    @State private var alerts: [Date] = []
    @State private var loaded = false

    var body: some View {
        List {
            if !settings.healthKitSyncEnabled {
                Section {
                    Text("Turn on Apple Health sync in Settings to see ECGs and irregular rhythm alerts here.")
                        .foregroundStyle(.secondary)
                }
            } else if loaded && ecgs.isEmpty && alerts.isEmpty {
                Section {
                    EmptyState(title: "Nothing recorded yet", message: "ECGs you take on an Apple Watch, and any irregular rhythm notifications, show up here next to your blood pressure.", systemImage: "applewatch")
                }
            }
            if !alerts.isEmpty {
                Section("Irregular rhythm alerts") {
                    ForEach(alerts, id: \.self) { d in
                        Label(d.formatted(date: .abbreviated, time: .shortened), systemImage: "exclamationmark.heart.fill").foregroundStyle(.orange)
                    }
                }
            }
            if !ecgs.isEmpty {
                Section("ECG recordings") {
                    ForEach(ecgs) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.headline).foregroundStyle(e.isConcern ? .red : .primary)
                                Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let hr = e.averageHeartRate { Text("\(hr) bpm").monospacedDigit().foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Section {
                Text("These come from Apple Health and are shown as recorded. BP Log does not interpret them. If you see atrial fibrillation or repeated alerts, talk to your doctor.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Heart rhythm")
        .task {
            guard settings.healthKitSyncEnabled else { loaded = true; return }
            async let a = health.fetchECGs()
            async let b = health.fetchIrregularRhythmEvents()
            ecgs = await a; alerts = await b; loaded = true
        }
    }
}
