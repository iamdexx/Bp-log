import SwiftUI

struct LockView: View {
    @EnvironmentObject private var lock: AppLockService

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.heart.fill").font(.system(size: 64)).foregroundStyle(.tint)
                Text("BP Log is locked").font(.title2.weight(.semibold))
                BigButton(title: "Unlock with \(AppLockService.biometryName)", systemImage: "faceid") {
                    Task { await lock.unlock() }
                }
                .padding(.horizontal, 32)
            }
        }
        .task { await lock.unlock() }
    }
}
