import SwiftUI
import SwiftData

/// Toolbar menu to switch who you are logging for.
struct ProfileMenu: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    @State private var manage = false

    var body: some View {
        Menu {
            Button { settings.activeProfileID = "" } label: {
                Label(defaultName, systemImage: settings.activeProfileID.isEmpty ? "checkmark" : "person")
            }
            ForEach(profiles) { p in
                Button { settings.activeProfileID = p.id.uuidString } label: {
                    Label(p.name, systemImage: settings.activeProfileID == p.id.uuidString ? "checkmark" : "person")
                }
            }
            Divider()
            Button { manage = true } label: { Label("Add or edit people", systemImage: "person.badge.plus") }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                Text(activeName).lineLimit(1)
            }
        }
        .accessibilityLabel("Switch person. Currently \(activeName)")
        .sheet(isPresented: $manage) { NavigationStack { ProfilesView() } }
    }

    private var defaultName: String { settings.patientName.isEmpty ? "Me" : settings.patientName }
    private var activeName: String {
        if settings.activeProfileID.isEmpty { return defaultName }
        return profiles.first { $0.id.uuidString == settings.activeProfileID }?.name ?? defaultName
    }
}

struct ProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.fill")
                    TextField("Your name", text: $settings.patientName)
                }
            } header: { Text("You") } footer: { Text("Shown on the doctor report.") }

            Section {
                ForEach(profiles) { p in
                    HStack {
                        Image(systemName: "person")
                        TextField("Name", text: Binding(get: { p.name }, set: { p.name = $0; try? context.save() }))
                    }
                }
                .onDelete { idx in
                    for i in idx {
                        let p = profiles[i]
                        if settings.activeProfileID == p.id.uuidString { settings.activeProfileID = "" }
                        context.delete(p)
                    }
                    try? context.save()
                }
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                    TextField("Add a person (spouse, parent...)", text: $newName)
                        .onSubmit(add)
                    if !newName.isEmpty { Button("Add", action: add) }
                }
            } header: { Text("Other people") } footer: {
                Text("Each person has their own readings, meds and report. Swipe left to remove someone; their readings go with them.")
            }
        }
        .navigationTitle("People")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let p = Profile(name: name, sortOrder: (profiles.last?.sortOrder ?? 0) + 1)
        context.insert(p)
        try? context.save()
        settings.activeProfileID = p.id.uuidString
        newName = ""
    }
}
