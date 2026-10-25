import Foundation
import CoreBluetooth
import BPCore

/// Finds cuffs advertising the standard Blood Pressure service and listens for measurements.
/// Works with any monitor that follows the Bluetooth SIG profile (Omron, A&D, Beurer, Withings, iHealth...).
@MainActor
final class BluetoothCuffService: NSObject, ObservableObject {
    enum State: Equatable { case idle, poweredOff, unauthorized, scanning, connecting(String), waiting(String), received, failed(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var devices: [CBPeripheral] = []
    @Published var measurement: BLEBloodPressure.Measurement?

    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private let service = CBUUID(string: BLEBloodPressure.serviceUUID)
    private let measurementChar = CBUUID(string: BLEBloodPressure.measurementCharacteristicUUID)

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        measurement = nil
        devices = []
        guard central.state == .poweredOn else { return }
        state = .scanning
        central.scanForPeripherals(withServices: [service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stop() {
        central.stopScan()
        if let connected { central.cancelPeripheralConnection(connected) }
        connected = nil
        if state != .received { state = .idle }
    }

    func connect(_ p: CBPeripheral) {
        central.stopScan()
        connected = p
        p.delegate = self
        state = .connecting(p.name ?? "Cuff")
        central.connect(p)
    }
}

extension BluetoothCuffService: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ c: CBCentralManager) {
        Task { @MainActor in
            switch c.state {
            case .poweredOn: if self.state == .idle || self.state == .poweredOff { self.startScan() }
            case .poweredOff: self.state = .poweredOff
            case .unauthorized: self.state = .unauthorized
            default: break
            }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        Task { @MainActor in
            if !self.devices.contains(where: { $0.identifier == p.identifier }) { self.devices.append(p) }
            // Most cuffs only advertise for a few seconds right after a reading; connect to the first one automatically.
            if self.devices.count == 1 { self.connect(p) }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([CBUUID(string: BLEBloodPressure.serviceUUID)])
    }

    nonisolated func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        Task { @MainActor in self.state = .failed("Couldn't connect to \(p.name ?? "the cuff"). Take a reading and try again.") }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        Task { @MainActor in if self.state != .received { self.state = .idle } }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] where s.uuid == CBUUID(string: BLEBloodPressure.serviceUUID) {
            p.discoverCharacteristics([CBUUID(string: BLEBloodPressure.measurementCharacteristicUUID)], for: s)
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] where ch.uuid == CBUUID(string: BLEBloodPressure.measurementCharacteristicUUID) {
            p.setNotifyValue(true, for: ch)
            Task { @MainActor in self.state = .waiting(p.name ?? "Cuff") }
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let data = ch.value, let m = BLEBloodPressure.parse(data) else { return }
        Task { @MainActor in
            self.measurement = m
            self.state = .received
        }
    }
}
