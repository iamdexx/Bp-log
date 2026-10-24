import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var health: HealthKitService
    @State private var page = 0
    @State private var showPaywall = false

    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardPage(symbol: "heart.text.square.fill", color: .red, title: "Your blood pressure, in one place",
                            text: "Log a reading in two taps. See right away if it is normal, elevated or high, using the American Heart Association ranges.").tag(0)
                OnboardPage(symbol: "doc.text.fill", color: .blue, title: "A report your doctor will like",
                            text: "One tap makes a clean PDF with your averages, morning vs evening, and every reading. Share it from your phone.").tag(1)
                OnboardPage(symbol: "lock.shield.fill", color: .green, title: "Private by design",
                            text: "No account. Your readings stay on your phone and your iCloud. Nothing is sold, nothing is shared unless you choose to.").tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if page < 2 {
                    BigButton(title: "Next") { withAnimation { page += 1 } }
                } else {
                    if health.isAvailable {
                        BigButton(title: "Connect Apple Health", systemImage: "heart.fill", tint: .pink) {
                            Task {
                                settings.healthKitSyncEnabled = await health.requestAuthorization()
                                finish()
                            }
                        }
                        Button("Not now") { finish() }.font(.subheadline)
                    } else {
                        BigButton(title: "Get started") { finish() }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showPaywall, onDismiss: { settings.hasOnboarded = true }) { PaywallView() }
    }

    private func finish() {
        showPaywall = true
    }
}

private struct OnboardPage: View {
    let symbol: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 96)).foregroundStyle(color)
            Text(title).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text(text).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
