import SwiftUI
import SwiftData
import BPCore

struct SettingsView: View {
    var profileID: UUID? = nil
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var lock: AppLockService
    @Environment(\.modelContext) private var context
    @State private var showPaywall = false
    @State private var importResult: String?
    @State private var lockError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.isPro {
                        Label("Ad-free plan active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Button("Manage subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") { UIApplication.shared.open(url) }
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Remove ads", systemImage: "sparkles")
                        }
                        Text("Everything in BP Log is free. Paying only removes the banner ad.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                } header: { Text("Plan") }

                Section {
                    NavigationLink { MedicationsView(profileID: profileID) } label: { Label("Medications", systemImage: "pills.fill") }
                    NavigationLink { ProfilesView() } label: { Label("People (family profiles)", systemImage: "person.2.fill") }
                } header: { Text("Tracking") } footer: {
                    Text("Add the people you log for. Each has separate readings, meds and reports. Free, no limit.")
                }

                Section {
                    Picker("Guideline", selection: Binding(get: { settings.guideline }, set: { settings.guideline = $0 })) {
                        ForEach(BPGuideline.allCases) { Text($0.title).tag($0) }
                    }
                    if settings.guideline == .custom {
                        Stepper("Top number under \(settings.targetSystolic)", value: $settings.targetSystolic, in: 100...180, step: 5)
                        Stepper("Bottom number under \(settings.targetDiastolic)", value: $settings.targetDiastolic, in: 60...110, step: 5)
                    }
                    LegendView().padding(.vertical, 4)
                } header: { Text("Blood pressure ranges") } footer: {
                    Text(settings.guideline.sourceText + " Colors, labels and the report follow this choice.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { settings.appLockEnabled },
                        set: { on in
                            Task {
                                if on {
                                    guard AppLockService.isAvailable else { lockError = "Set a passcode or Face ID on this iPhone first."; return }
                                    if await lock.unlock(reason: "Confirm it's you to turn on the lock") { settings.appLockEnabled = true; lockError = nil }
                                } else {
                                    if await lock.unlock(reason: "Confirm it's you to turn off the lock") { settings.appLockEnabled = false }
                                }
                            }
                        })) {
                        Label("Lock with \(AppLockService.biometryName)", systemImage: "lock.fill")
                    }
                    if let lockError { Text(lockError).font(.footnote).foregroundStyle(.red) }
                } header: { Text("Privacy") } footer: {
                    Text("Asks for \(AppLockService.biometryName) every time you come back to the app.")
                }

                Section("Apple Health") {
                    Toggle("Sync with Apple Health", isOn: Binding(
                        get: { settings.healthKitSyncEnabled },
                        set: { on in
                            if on { Task { settings.healthKitSyncEnabled = await health.requestAuthorization() } }
                            else { settings.healthKitSyncEnabled = false }
                        }))
                    if settings.healthKitSyncEnabled {
                        Button("Import readings from Health now") {
                            Task {
                                let n = await health.importNew(into: context)
                                importResult = n == 0 ? "Nothing new to import." : "Imported \(n) new entries."
                            }
                        }
                        if let importResult { Text(importResult).font(.footnote).foregroundStyle(.secondary) }
                    }
                    if !health.isAvailable { Text("Apple Health is not available on this device.").font(.footnote).foregroundStyle(.secondary) }
                }

                Section {
                    Toggle("Daily reminders", isOn: Binding(
                        get: { settings.remindersEnabled },
                        set: { on in
                            Task {
                                if on, await ReminderService.requestPermission() {
                                    settings.remindersEnabled = true
                                    await ReminderService.schedule(morningMinutes: settings.morningReminderMinutes, eveningMinutes: settings.eveningReminderMinutes)
                                } else {
                                    settings.remindersEnabled = false
                                    ReminderService.cancel()
                                }
                            }
                        }))
                    if settings.remindersEnabled {
                        TimeRow(title: "Morning", minutes: $settings.morningReminderMinutes)
                        TimeRow(title: "Evening", minutes: $settings.eveningReminderMinutes)
                    }
                } header: { Text("Reminders") } footer: {
                    Text("Doctors usually want one reading in the morning before meds and one in the evening.")
                }
                .onChange(of: settings.morningReminderMinutes) { reschedule() }
                .onChange(of: settings.eveningReminderMinutes) { reschedule() }

                Section("Preferences") {
                    TextField("Name on reports", text: $settings.patientName)
                    Picker("Weight unit", selection: $settings.useMetricWeight) {
                        Text("Pounds").tag(false); Text("Kilograms").tag(true)
                    }
                }

                Section {
                    Toggle("Donate anonymized data to research", isOn: $settings.researchDonationEnabled)
                } header: { Text("EticaLabs research") } footer: {
                    Text("Off by default. If you turn this on, once a week the app shares your weekly averages and how many readings fell in each range. Nothing else: no name, no dates, no notes, no device id. You can turn it off any time. Research intake is not live yet, so nothing is sent until it is.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Link("Privacy policy", destination: URL(string: "https://eticahub.com/bplog/privacy")!)
                    Link("Terms of use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text("BP Log is a logbook, not a medical device. It does not measure blood pressure and does not diagnose or treat any condition. Always follow your doctor's advice.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func reschedule() {
        guard settings.remindersEnabled else { return }
        Task { await ReminderService.schedule(morningMinutes: settings.morningReminderMinutes, eveningMinutes: settings.eveningReminderMinutes) }
    }
}

struct TimeRow: View {
    let title: String
    @Binding var minutes: Int

    private var date: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            minutes = (c.hour ?? 8) * 60 + (c.minute ?? 0)
        })
    }

    var body: some View {
        DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
    }
}
