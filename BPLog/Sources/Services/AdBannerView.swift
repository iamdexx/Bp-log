import SwiftUI
import GoogleMobileAds

/// Adaptive banner anchored at the bottom of the screen. Only mounted on the free tier.
struct AdBannerView: UIViewRepresentable {
    let width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !context.coordinator.hasLoaded, width > 0 else { return }
        banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        banner.load(Request())
        context.coordinator.hasLoaded = true
    }

    /// Keep the banner at the width SwiftUI offers; otherwise the ad's intrinsic size widens the whole tab layout.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BannerView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? width, height: proposal.height ?? uiView.adSize.size.height)
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
            GeometryReader { geo in
                AdBannerView(width: geo.size.width)
            }
            .frame(height: 60)
            .clipped()
            .background(Color(.secondarySystemBackground))
        }
    }
}
