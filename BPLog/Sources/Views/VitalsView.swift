import SwiftUI
import SwiftData
import Charts

struct VitalsView: View {
    let profileID: UUID?
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @Query private var entries: [VitalEntry]

    init(profileID: UUID?) {
        self.profileID = profileID
        _entries = Query(filter: #Predicate<VitalEntry> { $0.profileID == profileID }, sort: [SortDescriptor(\VitalEntry.date, order: .reverse)])
    }
    @State private var kind: VitalKind = .weight
    @State private var showAdd = false

    private var forKind: [VitalEntry] { entries.filter { $0.kind == kind } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Vital", selection: $kind) {
                    ForEach(VitalKind.allCases) { k in Text(k.title).tag(k) }
                }
                .pickerStyle(.segmented)
                .padding()

                NavigationLink { HeartRhythmView() } label: {
                    Label("ECG and irregular rhythm (from Apple Watch)", systemImage: "waveform.path.ecg.rectangle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                if forKind.isEmpty {
                    EmptyState(title: "No \(kind.title.lowercased()) yet", message: "Tap + to add one. These also go to Apple Health if sync is on.", systemImage: kind.symbol)
                } else {
                    List {
                        Section {
                            chart
                        }
                        Section("Entries") {
                            ForEach(forKind) { e in
                                HStack {
                                    Text(display(e)).font(.title3.weight(.semibold)).monospacedDigit()
                                    Text(kind.unit(metric: settings.useMetricWeight)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(e.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .onDelete { idx in
                                for i in idx { context.delete(forKind[i]) }
                                try? context.save()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vitals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add")
                }
            }
            .sheet(isPresented: $showAdd) { AddVitalView(profileID: profileID, kind: kind) }
        }
    }

    private var chart: some View {
        let points = forKind.sorted { $0.date < $1.date }.suffix(60)
        return Chart(Array(points)) { e in
            LineMark(x: .value("Date", e.date), y: .value(kind.title, displayValue(e)))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", e.date), y: .value(kind.title, displayValue(e))).symbolSize(20)
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }

    private func displayValue(_ e: VitalEntry) -> Double {
        if kind == .weight && !settings.useMetricWeight { return e.value * 2.20462 }
        return e.value
    }

    private func display(_ e: VitalEntry) -> String {
        let v = displayValue(e)
        return kind.allowsDecimals ? String(format: "%.1f", v) : "\(Int(v.rounded()))"
    }
}

struct AddVitalView: View {
    var profileID: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @State var kind: VitalKind
    @State private var text = ""
    @State private var date = Date()
    @FocusState private var focused: Bool

    private var value: Double? {
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let canonical = (kind == .weight && !settings.useMetricWeight) ? v / 2.20462 : v
        return kind.range.contains(canonical) ? canonical : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { ForEach(VitalKind.allCases) { Text($0.title).tag($0) } }
                HStack {
                    TextField("Value", text: $text)
                        .keyboardType(kind.allowsDecimals ? .decimalPad : .numberPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .focused($focused)
                    Text(kind.unit(metric: settings.useMetricWeight)).font(.title3).foregroundStyle(.secondary)
                }
                DatePicker("When", selection: $date, in: ...Date())
            }
            .navigationTitle("Add \(kind.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value else { return }
                        let e = VitalEntry(date: date, kind: kind, value: value, profileID: profileID)
                        context.insert(e)
                        try? context.save()
                        if settings.healthKitSyncEnabled { Task { await health.save(e) } }
                        dismiss()
                    }
                    .disabled(value == nil)
                }
            }
            .onAppear { focused = true }
        }
    }
}
