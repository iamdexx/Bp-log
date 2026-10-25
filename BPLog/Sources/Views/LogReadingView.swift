import SwiftUI
import SwiftData
import BPCore

/// Add or edit a reading. Big fields, number pad, nothing clever.
struct LogReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService

    var profileID: UUID? = nil
    var existing: Reading?

    @State private var tags: Set<ReadingTag> = []
    @State private var source = "manual"
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var pulse = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var arm = "Left"
    @State private var showScan = false
    @State private var showBluetooth = false
    @FocusState private var focus: Field?

    enum Field { case systolic, diastolic, pulse }

    private var sys: Int? { Int(systolic) }
    private var dia: Int? { Int(diastolic) }
    private var pul: Int? { pulse.isEmpty ? nil : Int(pulse) }

    private var problems: [BPValidation.Problem] {
        guard let sys, let dia else { return [] }
        if !pulse.isEmpty && pul == nil { return [.pulseOutOfRange] }
        return BPValidation.problems(systolic: sys, diastolic: dia, pulse: pul)
    }

    private var medsTakenFlag: Bool? {
        if tags.contains(.afterMeds) { return true }
        if tags.contains(.beforeMeds) { return false }
        return nil
    }

    private var canSave: Bool { sys != nil && dia != nil && problems.isEmpty }
    private var preview: BPCategory? { guard let sys, let dia, problems.isEmpty else { return nil }; return BPCategory.classify(systolic: sys, diastolic: dia) }

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil {
                    Section {
                        Button {
                            showScan = true
                        } label: {
                            Label("Scan the cuff screen with the camera", systemImage: "camera.viewfinder").font(.headline)
                        }
                        Button {
                            showBluetooth = true
                        } label: {
                            Label("Get it from a Bluetooth cuff", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                        }
                    } footer: {
                        Text("Or type the numbers below.")
                    }
                }
                Section {
                    HStack(spacing: 12) {
                        NumberField(title: "Systolic", subtitle: "top number", text: $systolic, field: .systolic, focus: $focus)
                        Text("/").font(.largeTitle).foregroundStyle(.secondary).padding(.top, 18)
                        NumberField(title: "Diastolic", subtitle: "bottom number", text: $diastolic, field: .diastolic, focus: $focus)
                    }
                    .padding(.vertical, 6)
                    .onChange(of: systolic) { _, v in if v.count >= 3 && focus == .systolic { focus = .diastolic } }
                    .onChange(of: diastolic) { _, v in if v.count >= 2 && Int(v) ?? 0 >= 40 && focus == .diastolic && v.count == 3 { focus = .pulse } }

                    HStack {
                        Label("Pulse", systemImage: "heart.fill")
                        Spacer()
                        TextField("optional", text: $pulse)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focus, equals: .pulse)
                            .frame(width: 100)
                        Text("bpm").foregroundStyle(.secondary)
                    }
                } footer: {
                    if let preview {
                        HStack { CategoryPill(category: preview); Text(preview.rangeText).font(.caption) }
                            .padding(.top, 4)
                    } else if !problems.isEmpty {
                        Text(problemText).foregroundStyle(.red)
                    }
                }

                Section {
                    DatePicker("When", selection: $date, in: ...Date())
                    Picker("Arm", selection: $arm) {
                        Text("Left").tag("Left"); Text("Right").tag("Right")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TagPicker(selected: $tags)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: { Text("What was going on") } footer: {
                    Text("Tap any that apply. Doctors like to know if a reading was before your pills or right after exercise.")
                }
            }
            .sheet(isPresented: $showBluetooth) {
                BluetoothScanView { m in
                    systolic = String(m.systolic); diastolic = String(m.diastolic)
                    pulse = m.pulse.map(String.init) ?? ""
                    if let d = m.date, abs(d.timeIntervalSinceNow) < 86_400 * 30 { date = d }
                    if m.irregularPulse { tags.insert(.irregularHeartbeat) }
                    source = "bluetooth"
                    focus = nil
                }
            }
            .sheet(isPresented: $showScan) {
                CuffScanView { r in
                    systolic = String(r.systolic); diastolic = String(r.diastolic)
                    pulse = r.pulse.map(String.init) ?? ""
                    focus = nil
                }
            }
            .navigationTitle(existing == nil ? "New reading" : "Edit reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .onAppear {
                if let existing {
                    systolic = "\(existing.systolic)"; diastolic = "\(existing.diastolic)"
                    pulse = existing.pulse.map(String.init) ?? ""
                    date = existing.date; note = existing.note; arm = existing.arm.isEmpty ? settings.defaultArm : existing.arm
                    tags = existing.tags
                } else {
                    arm = settings.defaultArm
                    focus = .systolic
                }
            }
        }
    }

    private var problemText: String {
        if problems.contains(.diastolicNotBelowSystolic) { return "The bottom number should be lower than the top number." }
        if problems.contains(.systolicOutOfRange) { return "Systolic should be between \(BPValidation.systolicRange.lowerBound) and \(BPValidation.systolicRange.upperBound)." }
        if problems.contains(.diastolicOutOfRange) { return "Diastolic should be between \(BPValidation.diastolicRange.lowerBound) and \(BPValidation.diastolicRange.upperBound)." }
        return "Pulse should be between \(BPValidation.pulseRange.lowerBound) and \(BPValidation.pulseRange.upperBound)."
    }

    private func save() {
        guard let sys, let dia else { return }
        let reading: Reading
        if let existing {
            reading = existing
            reading.systolic = sys; reading.diastolic = dia; reading.pulse = pul
            reading.date = date; reading.note = note; reading.arm = arm
            reading.tags = tags; reading.medsTaken = medsTakenFlag
        } else {
            reading = Reading(date: date, systolic: sys, diastolic: dia, pulse: pul, note: note, arm: arm, source: source, profileID: profileID, tags: tags, medsTaken: medsTakenFlag)
            context.insert(reading)
        }
        settings.defaultArm = arm
        try? context.save()
        if settings.healthKitSyncEnabled {
            Task { await health.save(reading) }
        }
        dismiss()
    }
}

private struct NumberField: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    let field: LogReadingView.Field
    var focus: FocusState<LogReadingView.Field?>.Binding

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.weight(.semibold))
            TextField("--", text: $text)
                .keyboardType(.numberPad)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .focused(focus, equals: field)
                .onChange(of: text) { _, v in
                    let digits = v.filter(\.isNumber)
                    if digits != v || digits.count > 3 { text = String(digits.prefix(3)) }
                }
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
