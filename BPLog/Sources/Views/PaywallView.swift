import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreService
    @State private var selected: String = StoreService.yearlyID
    @State private var purchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Remove the ads").font(.title.weight(.bold))
                Text("Every feature is already free. Going ad-free just gives you a cleaner screen and supports an independent app.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)

                VStack(spacing: 12) {
                    if let y = store.yearly {
                        PlanRow(title: "Yearly", price: y.displayPrice + " / year", detail: store.perMonthText(for: y),
                                badge: store.yearlySavingPercent.map { "Save \($0)%" }, selected: selected == y.id) { selected = y.id }
                    }
                    if let m = store.monthly {
                        PlanRow(title: "Monthly", price: m.displayPrice + " / month", detail: "Cancel any time", badge: nil, selected: selected == m.id) { selected = m.id }
                    }
                    if store.products.isEmpty {
                        ProgressView().padding()
                        if let err = store.lastError { Text(err).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                .padding(.horizontal)

                Spacer()

                BigButton(title: purchasing ? "Working..." : "Continue") {
                    guard let p = store.products.first(where: { $0.id == selected }) else { return }
                    purchasing = true
                    Task {
                        await store.purchase(p)
                        purchasing = false
                        if store.isPro { dismiss() }
                    }
                }
                .disabled(purchasing || store.products.isEmpty)
                .padding(.horizontal)

                Button("Keep using it free with ads") { dismiss() }.font(.subheadline)

                HStack(spacing: 16) {
                    Button("Restore") { Task { await store.restore(); if store.isPro { dismiss() } } }
                    Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link("Privacy", destination: URL(string: "https://eticahub.com/bplog/privacy")!)
                }
                .font(.caption).foregroundStyle(.secondary)
                Text("Subscriptions renew automatically until cancelled in Settings > Apple ID > Subscriptions.")
                    .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center).padding(.horizontal)
            }
            .padding(.vertical)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
            .task { if store.products.isEmpty { await store.refresh() } }
        }
    }
}

private struct PlanRow: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.title2).foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge).font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green, in: Capsule()).foregroundStyle(.white)
                        }
                    }
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price).font(.subheadline.weight(.semibold))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
