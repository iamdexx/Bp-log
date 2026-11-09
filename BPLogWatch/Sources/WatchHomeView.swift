import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var link: PhoneLink
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let sys = link.summary["sys"] as? Int, let dia = link.summary["dia"] as? Int {
                        Text("\(sys)/\(dia)")
                            .font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(Color(hex: link.summary["hex"] as? String ?? "#2E9E5B"))
                        Text(link.summary["label"] as? String ?? "").font(.footnote.weight(.semibold))
                        if let t = link.summary["date"] as? TimeInterval {
                            Text(Date(timeIntervalSince1970: t), style: .relative).font(.caption2).foregroundStyle(.secondary)
                        }
                        if let ws = link.summary["weekSys"] as? Int, let wd = link.summary["weekDia"] as? Int {
                            Text("7-day avg \(ws)/\(wd)").font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No readings yet").font(.headline)
                        Text("Log one here or on your iPhone.").font(.caption2).foregroundStyle(.secondary)
                    }
                    Button { showLog = true } label: { Label("Log reading", systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#55c28a"))
                    if let sent = link.lastSent {
                        Text("Sent \(sent, style: .time)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("BP Log")
            .sheet(isPresented: $showLog) { WatchLogView() }
        }
    }
}

/// Three dials, digital crown friendly. Sends to the phone, which stores it and syncs Health.
struct WatchLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var link: PhoneLink
    @State private var step = 0
    @State private var sys = 120.0
    @State private var dia = 80.0
    @State private var pulse = 70.0
    @State private var includePulse = true

    var body: some View {
        VStack(spacing: 8) {
            Text(["Top number", "Bottom number", "Pulse"][step]).font(.footnote).foregroundStyle(.secondary)
            Text("\(Int(current.wrappedValue.rounded()))")
                .font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
                .focusable()
                .digitalCrownRotation(current, from: range.lowerBound, through: range.upperBound, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            HStack {
                Button("-") { current.wrappedValue = max(range.lowerBound, current.wrappedValue - 1) }
                Button("+") { current.wrappedValue = min(range.upperBound, current.wrappedValue + 1) }
            }
            .font(.title3)
            if step < 2 {
                Button("Next") { step += 1 }.buttonStyle(.borderedProminent)
            } else {
                Button("Save") {
                    link.send(systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()), pulse: includePulse ? Int(pulse.rounded()) : nil)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).tint(.green)
                .disabled(dia >= sys)
                Button("Save without pulse") {
                    link.send(systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()), pulse: nil)
                    dismiss()
                }
                .font(.caption2)
                .disabled(dia >= sys)
            }
        }
    }

    private var current: Binding<Double> { [$sys, $dia, $pulse][step] }
    private var range: ClosedRange<Double> { [60...260, 30...160, 25...230][step] }
}

extension Color {
    init(hex: String) {
        var h = hex; if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
