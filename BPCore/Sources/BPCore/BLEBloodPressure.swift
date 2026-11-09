import Foundation

/// Parser for the Bluetooth SIG Blood Pressure Measurement characteristic (0x2A35),
/// used by Omron, A&D, Beurer, Withings and most cuffs that advertise service 0x1810.
public enum BLEBloodPressure {
    public static let serviceUUID = "1810"
    public static let measurementCharacteristicUUID = "2A35"
    public static let intermediateCuffPressureUUID = "2A36"

    public struct Measurement: Equatable, Sendable {
        public var systolic: Int
        public var diastolic: Int
        public var meanArterial: Int?
        public var pulse: Int?
        public var date: Date?
        public var irregularPulse: Bool
        public var userIndex: Int?

        public init(systolic: Int, diastolic: Int, meanArterial: Int? = nil, pulse: Int? = nil, date: Date? = nil, irregularPulse: Bool = false, userIndex: Int? = nil) {
            self.systolic = systolic; self.diastolic = diastolic; self.meanArterial = meanArterial
            self.pulse = pulse; self.date = date; self.irregularPulse = irregularPulse; self.userIndex = userIndex
        }
    }

    /// Returns nil for malformed packets or values outside `BPValidation` ranges.
    public static func parse(_ data: Data) -> Measurement? {
        let b = [UInt8](data)
        guard b.count >= 7 else { return nil }
        let flags = b[0]
        let kPa = flags & 0x01 != 0
        let hasTime = flags & 0x02 != 0
        let hasPulse = flags & 0x04 != 0
        let hasUser = flags & 0x08 != 0
        let hasStatus = flags & 0x10 != 0

        func mmHg(_ v: Double) -> Int { Int((kPa ? v * 7.50062 : v).rounded()) }
        guard let s = sfloat(b, 1), let d = sfloat(b, 3), let m = sfloat(b, 5) else { return nil }
        var i = 7
        var date: Date? = nil
        if hasTime {
            guard b.count >= i + 7 else { return nil }
            var c = DateComponents()
            c.year = Int(b[i]) | Int(b[i + 1]) << 8
            c.month = Int(b[i + 2]); c.day = Int(b[i + 3])
            c.hour = Int(b[i + 4]); c.minute = Int(b[i + 5]); c.second = Int(b[i + 6])
            if (c.year ?? 0) > 2000 { date = Calendar.current.date(from: c) }
            i += 7
        }
        var pulse: Int? = nil
        if hasPulse {
            guard let p = sfloat(b, i) else { return nil }
            pulse = Int(p.rounded()); i += 2
        }
        var user: Int? = nil
        if hasUser { guard b.count > i else { return nil }; user = Int(b[i]); i += 1 }
        var irregular = false
        if hasStatus {
            guard b.count >= i + 2 else { return nil }
            let status = UInt16(b[i]) | UInt16(b[i + 1]) << 8
            irregular = status & 0x04 != 0
        }
        let sys = mmHg(s), dia = mmHg(d)
        guard BPValidation.problems(systolic: sys, diastolic: dia, pulse: pulse).isEmpty else { return nil }
        return Measurement(systolic: sys, diastolic: dia, meanArterial: m.isNaN ? nil : mmHg(m), pulse: pulse, date: date, irregularPulse: irregular, userIndex: user)
    }

    /// IEEE 11073 16-bit SFLOAT: 4-bit signed exponent, 12-bit signed mantissa. NaN for the reserved values.
    static func sfloat(_ b: [UInt8], _ i: Int) -> Double? {
        guard b.count >= i + 2 else { return nil }
        let raw = UInt16(b[i]) | UInt16(b[i + 1]) << 8
        if raw == 0x07FF || raw == 0x0800 || raw == 0x07FE || raw == 0x0802 { return .nan }
        var mantissa = Int(raw & 0x0FFF)
        if mantissa >= 0x0800 { mantissa -= 0x1000 }
        var exponent = Int(raw >> 12)
        if exponent >= 0x8 { exponent -= 0x10 }
        return Double(mantissa) * pow(10, Double(exponent))
    }
}
