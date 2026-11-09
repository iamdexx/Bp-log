import Foundation
import HealthKit
import SwiftData

/// Two-way sync with Apple Health. Writes every manual entry, imports anything we have not seen.
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isAuthorized = false
    @Published var lastError: String?

    private var systolicType: HKQuantityType { HKQuantityType(.bloodPressureSystolic) }
    private var diastolicType: HKQuantityType { HKQuantityType(.bloodPressureDiastolic) }
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    private var spo2Type: HKQuantityType { HKQuantityType(.oxygenSaturation) }
    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var bpCorrelationType: HKCorrelationType { HKCorrelationType(.bloodPressure) }

    private var allTypes: Set<HKSampleType> { [systolicType, diastolicType, heartRateType, spo2Type, weightType] }
    private var ecgType: HKElectrocardiogramType { HKObjectType.electrocardiogramType() }
    private var irregularRhythmType: HKCategoryType { HKCategoryType(.irregularHeartRhythmEvent) }

    private init() {}

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: allTypes, read: allTypes.union([bpCorrelationType, ecgType, irregularRhythmType]))
            isAuthorized = true
            return true
        } catch {
            lastError = "Apple Health permission was not granted."
            return false
        }
    }

    // MARK: Write

    func save(_ reading: Reading) async {
        guard isAvailable else { return }
        let sys = HKQuantitySample(type: systolicType, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: Double(reading.systolic)), start: reading.date, end: reading.date)
        let dia = HKQuantitySample(type: diastolicType, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: Double(reading.diastolic)), start: reading.date, end: reading.date)
        let correlation = HKCorrelation(type: bpCorrelationType, start: reading.date, end: reading.date, objects: [sys, dia])
        var toSave: [HKObject] = [correlation]
        if let pulse = reading.pulse {
            toSave.append(HKQuantitySample(type: heartRateType, quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(pulse)), start: reading.date, end: reading.date))
        }
        do {
            try await store.save(toSave)
            reading.healthKitUUID = correlation.uuid.uuidString
        } catch {
            lastError = "Could not save to Apple Health."
        }
    }

    func save(_ vital: VitalEntry) async {
        guard isAvailable else { return }
        let sample: HKQuantitySample
        switch vital.kind {
        case .heartRate:
            sample = HKQuantitySample(type: heartRateType, quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: vital.value), start: vital.date, end: vital.date)
        case .bloodOxygen:
            sample = HKQuantitySample(type: spo2Type, quantity: HKQuantity(unit: .percent(), doubleValue: vital.value / 100), start: vital.date, end: vital.date)
        case .weight:
            sample = HKQuantitySample(type: weightType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: vital.value), start: vital.date, end: vital.date)
        }
        do {
            try await store.save(sample)
            vital.healthKitUUID = sample.uuid.uuidString
        } catch {
            lastError = "Could not save to Apple Health."
        }
    }

    func delete(healthKitUUID: String, type: HKObjectType) async {
        guard let uuid = UUID(uuidString: healthKitUUID) else { return }
        let predicate = HKQuery.predicateForObject(with: uuid)
        let descriptor = HKSampleQueryDescriptor(predicates: [.sample(type: type as! HKSampleType, predicate: predicate)], sortDescriptors: [])
        if let objects = try? await descriptor.result(for: store), !objects.isEmpty {
            try? await store.delete(objects)
        }
    }

    func deleteReading(_ reading: Reading) async {
        guard let id = reading.healthKitUUID else { return }
        await delete(healthKitUUID: id, type: bpCorrelationType)
    }

    // MARK: Import

    /// Pull blood pressure correlations and vitals from Health that we did not write ourselves.
    func importNew(into context: ModelContext, profileID: UUID? = nil, since: Date? = nil) async -> Int {
        guard isAvailable else { return 0 }
        var imported = 0
        let start = since ?? Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: nil)

        let known = Set(((try? context.fetch(FetchDescriptor<Reading>())) ?? []).compactMap(\.healthKitUUID))
        let bpDescriptor = HKSampleQueryDescriptor(predicates: [.correlation(type: bpCorrelationType, predicate: datePredicate)],
                                                   sortDescriptors: [SortDescriptor(\.startDate)])
        if let correlations = try? await bpDescriptor.result(for: store) {
            for c in correlations where !known.contains(c.uuid.uuidString) {
                guard c.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier,
                      let sys = (c.objects(for: systolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: .millimeterOfMercury()),
                      let dia = (c.objects(for: diastolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: .millimeterOfMercury())
                else { continue }
                let reading = Reading(date: c.startDate, systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()), source: "health", healthKitUUID: c.uuid.uuidString, profileID: profileID)
                context.insert(reading)
                imported += 1
            }
        }

        let knownVitals = Set(((try? context.fetch(FetchDescriptor<VitalEntry>())) ?? []).compactMap(\.healthKitUUID))
        for (kind, type) in [(VitalKind.bloodOxygen, spo2Type), (.weight, weightType)] {
            let d = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: datePredicate)], sortDescriptors: [SortDescriptor(\.startDate)])
            guard let samples = try? await d.result(for: store) else { continue }
            for s in samples where !knownVitals.contains(s.uuid.uuidString) && s.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier {
                let value: Double
                switch kind {
                case .bloodOxygen: value = s.quantity.doubleValue(for: .percent()) * 100
                case .weight: value = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
                case .heartRate: continue
                }
                context.insert(VitalEntry(date: s.startDate, kind: kind, value: value, source: "health", healthKitUUID: s.uuid.uuidString, profileID: profileID))
                imported += 1
            }
        }
        try? context.save()
        return imported
    }

    // MARK: ECG and rhythm (read only; Apple Watch writes these)

    struct ECGRecord: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let classification: HKElectrocardiogram.Classification
        let averageHeartRate: Int?
        let symptomsStatus: HKElectrocardiogram.SymptomsStatus

        var title: String {
            switch classification {
            case .sinusRhythm: return "Sinus rhythm"
            case .atrialFibrillation: return "Atrial fibrillation"
            case .inconclusiveLowHeartRate: return "Inconclusive (low heart rate)"
            case .inconclusiveHighHeartRate: return "Inconclusive (high heart rate)"
            case .inconclusivePoorReading: return "Inconclusive (poor recording)"
            case .inconclusiveOther: return "Inconclusive"
            case .notSet: return "Not classified"
            case .unrecognized: return "Unrecognized"
            @unknown default: return "Unknown"
            }
        }

        var isConcern: Bool { classification == .atrialFibrillation }
    }

    func fetchECGs(limit: Int = 50) async -> [ECGRecord] {
        guard isAvailable else { return [] }
        let d = HKSampleQueryDescriptor(predicates: [.electrocardiogram()], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: limit)
        guard let samples = try? await d.result(for: store) else { return [] }
        return samples.map { e in
            ECGRecord(id: e.uuid, date: e.startDate, classification: e.classification,
                      averageHeartRate: e.averageHeartRate.map { Int($0.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded()) },
                      symptomsStatus: e.symptomsStatus)
        }
    }

    /// Dates of "irregular rhythm" notifications from Apple Watch.
    func fetchIrregularRhythmEvents(limit: Int = 50) async -> [Date] {
        guard isAvailable else { return [] }
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: irregularRhythmType)], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: limit)
        return ((try? await d.result(for: store)) ?? []).map(\.startDate)
    }
}
