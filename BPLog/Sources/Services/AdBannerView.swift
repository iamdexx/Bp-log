import SwiftUI
import GoogleMobileAds

/// Adaptive banner anchored at the bottom of the screen. Only mounted on the free tier.
struct AdBannerView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !context.coordinator.hasLoaded else { return }
        let width = UIScreen.main.bounds.width
        banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        banner.load(Request())
        context.coordinator.hasLoaded = true
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var hasLoaded = false
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            hasLoaded = false
        }
    }
}

struct AdSlot: View {
    @EnvironmentObject private var store: StoreService

    var body: some View {
        if !store.isPro {
            AdBannerView()
                .frame(height: 60)
                .background(Color(.secondarySystemBackground))
        }
    }
}
