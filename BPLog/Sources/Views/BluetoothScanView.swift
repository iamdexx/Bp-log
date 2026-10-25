import SwiftUI
import BPCore

/// "Get it from the cuff" sheet. Pairing-free: the cuff advertises after a reading, we connect and read it.
struct BluetoothScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ble = BluetoothCuffService()
    let onResult: (BLEBloodPressure.Measurement) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                switch ble.state {
                case .received:
                    if let m = ble.measurement {
                        VStack(spacing: 6) {
                            Text("\(m.systolic) / \(m.diastolic)").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                            if let p = m.pulse { Text("Pulse \(p)").font(.title3).foregroundStyle(.secondary) }
                            if m.irregularPulse { Label("Irregular heartbeat detected by the cuff", systemImage: "waveform.path.ecg").font(.footnote).foregroundStyle(.orange) }
                        }
                        BigButton(title: "Use these numbers", systemImage: "checkmark") { onResult(m); dismiss() }
                        Button("Wait for another reading") { ble.startScan() }
                    }
                case .poweredOff:
                    EmptyState(title: "Bluetooth is off", message: "Turn on Bluetooth in Control Center, then come back.", systemImage: "antenna.radiowaves.left.and.right.slash")
                case .unauthorized:
                    EmptyState(title: "Bluetooth permission needed", message: "Allow Bluetooth for BP Log in Settings to read your cuff.", systemImage: "lock.slash")
                case .failed(let msg):
                    EmptyState(title: "Didn't work", message: msg, systemImage: "exclamationmark.triangle")
                    BigButton(title: "Try again", systemImage: "arrow.clockwise") { ble.startScan() }
                case .connecting(let name), .waiting(let name):
                    ProgressView().controlSize(.large)
                    Text(ble.state == .connecting(name) ? "Connecting to \(name)..." : "Connected to \(name). Waiting for the reading...").font(.headline).multilineTextAlignment(.center)
                default:
                    ProgressView().controlSize(.large)
                    VStack(spacing: 8) {
                        Text("Looking for your cuff").font(.headline)
                        Text("Take a reading now. Most cuffs send it over Bluetooth for a few seconds right after they finish. Keep the phone next to the cuff.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                Spacer()
                Text("Works with any cuff that uses the standard Bluetooth blood pressure profile: Omron, A&D, Beurer, Withings, iHealth and most others. No pairing app needed.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Bluetooth cuff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onDisappear { ble.stop() }
        }
    }
}
