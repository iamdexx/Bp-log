import Foundation
import LocalAuthentication

/// Face ID / Touch ID / passcode gate. Locks when the app goes to the background.
@MainActor
final class AppLockService: ObservableObject {
    @Published var isLocked = false
    @Published private(set) var authenticating = false

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    func lock() { isLocked = true }

    @discardableResult
    func unlock(reason: String = "Unlock your blood pressure log") async -> Bool {
        guard !authenticating else { return false }
        authenticating = true
        defer { authenticating = false }
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok { isLocked = false }
            return ok
        } catch {
            return false
        }
    }
}
