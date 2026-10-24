import Foundation
import StoreKit

/// StoreKit 2. Free tier shows a banner ad; either subscription removes it.
@MainActor
final class StoreService: ObservableObject {
    static let monthlyID = "com.eticahub.bplog.monthly"
    static let yearlyID = "com.eticahub.bplog.yearly"
    static let productIDs = [monthlyID, yearlyID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var activeProductID: String?
    @Published var lastError: String?
    @Published private(set) var isLoading = false

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    deinit { updates?.cancel() }

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            lastError = "Could not load plans. Check your connection and try again."
        }
        await updateEntitlements()
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                await updateEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase did not go through. You were not charged."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Could not restore. Make sure you are signed in to the App Store."
        }
        await updateEntitlements()
    }

    func updateEntitlements() async {
        var active: String?
        for await result in Transaction.currentEntitlements {
            guard let tx = try? checkVerified(result) else { continue }
            if Self.productIDs.contains(tx.productID), tx.revocationDate == nil {
                active = tx.productID
            }
        }
        activeProductID = active
        isPro = active != nil
    }

    /// Yearly saving vs 12 months of monthly, as a whole percent. Nil until both prices are known.
    var yearlySavingPercent: Int? {
        guard let m = monthly, let y = yearly else { return nil }
        let full = m.price * 12
        guard full > 0 else { return nil }
        let saving = (full - y.price) / full * 100
        return Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
    }

    func perMonthText(for yearly: Product) -> String {
        let perMonth = yearly.price / 12
        return perMonth.formatted(yearly.priceFormatStyle) + "/mo"
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let tx = try? checkVerified(result) {
                await tx.finish()
                await updateEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.unverified
        case .verified(let safe): return safe
        }
    }

    enum StoreError: Error { case unverified }
}
