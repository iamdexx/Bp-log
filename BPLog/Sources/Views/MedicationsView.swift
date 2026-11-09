import SwiftUI
import SwiftData

/// Your blood pressure meds and a one-tap "took it" log. Shows up on Home and in Settings.
struct MedicationsView: View {
    let profileID: UUID?
    @Environment(\.modelContext) private var context
    @Query private var meds: [Medication]
    @Query private var doses: [MedDose]
    @State private var editing: Medication?
    @State private var adding = false

    init(profileID: UUID?) {
        self.profileID = profileID
        _meds = Query(filter: #Predicate<Medication> { $0.profileID == profileID }, sort: [SortDescriptor(\Medication.createdAt)])
        let dayStart = Calendar.current.startOfDay(for: Date())
        _doses = Query(filter: #Predicate<MedDose> { $0.profileID == profileID && $0.date >= dayStart }, sort: [SortDescriptor(\MedDose.date)])
    }

    private var active: [Medication] { meds.filter(\.isActive) }
    private var retired: [Medication] { meds.filter { !$0.isActive } }

    var body: some View {
        List {
            if meds.isEmpty {
                Section {
                    EmptyState(title: "No medications yet", message: "Add your blood pressure meds and tap them each day when you take them. Readings then show whether they were before or after.", systemImage: "pills")
                }
            }
            if !active.isEmpty {
                Section("Today") {
                    ForEach(active) { m in
                        MedRow(med: m, takenToday: doses.filter { $0.medicationID == m.id }.count, onTake: { take(m) }, onUndo: { undo(m) })
                            .contentShape(Rectangle())
                            .onTapGesture { editing = m }
                    }
                }
            }
            if !retired.isEmpty {
                Section("Stopped") {
                    ForEach(retired) { m in
                        Button { editing = m } label: {
                            HStack { Text(m.name); Spacer(); Text(m.dose).foregroundStyle(.secondary) }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Medications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add medication")
            }
        }
        .sheet(isPresented: $adding) { MedicationEditView(profileID: profileID) }
        .sheet(item: $editing) { MedicationEditView(profileID: profileID, existing: $0) }
    }

    private func take(_ m: Medication) {
        context.insert(MedDose(medicationID: m.id, profileID: profileID))
        try? context.save()
    }

    private func undo(_ m: Medication) {
        if let last = doses.last(where: { $0.medicationID == m.id }) {
            context.delete(last)
            try? context.save()
        }
    }
}

struct MedRow: View {
    let med: Medication
    let takenToday: Int
    let onTake: () -> Void
    let onUndo: () -> Void

    private var done: Bool { takenToday >= med.schedule.dosesPerDay && med.schedule != .asNeeded }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: done ? onUndo : onTake) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Taken, tap to undo" : "Mark as taken")
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.headline)
                Text([med.dose, med.schedule.title].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if med.schedule == .asNeeded, takenToday > 0 {
                Text("\(takenToday) today").font(.caption).foregroundStyle(.secondary)
            } else if med.schedule == .both {
                Text("\(min(takenToday, 2))/2").font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MedicationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profileID: UUID?
    var existing: Medication?
    @State private var name = ""
    @State private var dose = ""
    @State private var schedule: MedSchedule = .morning
    @State private var isActive = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (for example Lisinopril)", text: $name)
                    TextField("Dose (for example 10 mg)", text: $dose)
                    Picker("When", selection: $schedule) {
                        ForEach(MedSchedule.allCases) { Text($0.title).tag($0) }
                    }
                }
                if existing != nil {
                    Section {
                        Toggle("Still taking it", isOn: $isActive)
                        Button("Delete medication", role: .destructive) {
                            if let existing { context.delete(existing); try? context.save() }
                            dismiss()
                        }
                    } footer: { Text("Turning this off keeps the history but hides it from Today.") }
                }
            }
            .navigationTitle(existing == nil ? "Add medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existing { name = existing.name; dose = existing.dose; schedule = existing.schedule; isActive = existing.isActive }
            }
        }
    }

    private func save() {
        if let existing {
            existing.name = name; existing.dose = dose; existing.schedule = schedule; existing.isActive = isActive
        } else {
            context.insert(Medication(name: name, dose: dose, schedule: schedule, profileID: profileID))
        }
        try? context.save()
        dismiss()
    }
}

/// Compact "Today's meds" card for the Home tab.
struct MedsTodayCard: View {
    let profileID: UUID?
    @Environment(\.modelContext) private var context
    @Query private var meds: [Medication]
    @Query private var doses: [MedDose]

    init(profileID: UUID?) {
        self.profileID = profileID
        _meds = Query(filter: #Predicate<Medication> { $0.profileID == profileID && $0.isActive }, sort: [SortDescriptor(\Medication.createdAt)])
        let dayStart = Calendar.current.startOfDay(for: Date())
        _doses = Query(filter: #Predicate<MedDose> { $0.profileID == profileID && $0.date >= dayStart }, sort: [SortDescriptor(\MedDose.date)])
    }

    var body: some View {
        if !meds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Today's meds", systemImage: "pills.fill").font(.headline)
                    Spacer()
                    NavigationLink("Manage") { MedicationsView(profileID: profileID) }.font(.subheadline)
                }
                ForEach(meds) { m in
                    MedRow(med: m, takenToday: doses.filter { $0.medicationID == m.id }.count,
                           onTake: { context.insert(MedDose(medicationID: m.id, profileID: profileID)); try? context.save() },
                           onUndo: { if let d = doses.last(where: { $0.medicationID == m.id }) { context.delete(d); try? context.save() } })
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
