import SwiftUI
import SwiftData
import BPCore

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var editing: Reading?
    @State private var showLog = false
    @State private var filter: BPCategory?

    private var filtered: [Reading] { filter.map { f in readings.filter { $0.category == f } } ?? readings }

    private var grouped: [(day: Date, items: [Reading])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if readings.isEmpty {
                    EmptyState(title: "No readings yet", message: "Your history will show up here, newest first.")
                } else {
                    List {
                        ForEach(grouped, id: \.day) { group in
                            Section {
                                ForEach(group.items) { r in
                                    Button { editing = r } label: { ReadingRow(reading: r) }
                                        .buttonStyle(.plain)
                                }
                                .onDelete { idx in delete(idx.map { group.items[$0] }) }
                            } header: {
                                HStack {
                                    Text(group.day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                    Spacer()
                                    if let avg = BPStats.average(group.items.samples), group.items.count > 1 {
                                        Text("avg \(avg.systolic)/\(avg.diastolic)").monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All readings") { filter = nil }
                        ForEach(BPCategory.allCases, id: \.self) { c in
                            Button(c.title) { filter = c }
                        }
                    } label: {
                        Label(filter?.shortTitle ?? "Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLog = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log a reading")
                }
            }
            .sheet(item: $editing) { LogReadingView(existing: $0) }
            .sheet(isPresented: $showLog) { LogReadingView() }
        }
    }

    private func delete(_ items: [Reading]) {
        for r in items {
            if settings.healthKitSyncEnabled { Task { await health.deleteReading(r) } }
            context.delete(r)
        }
        try? context.save()
    }
}
