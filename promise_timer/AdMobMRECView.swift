import SwiftUI
import GoogleMobileAds

/// A compact banner, kept separate from the game and tappable habit controls.
/// The existing production unit is a banner unit previously used at MREC size.
struct PochiBannerAd: View {
    var canLoad = true
    @ObservedObject private var privacy = AdPrivacyManager.shared
    @State private var loaded = false

    private var adUnitID: String {
#if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
#else
        return "ca-app-pub-4731680416753736/7227046727"
#endif
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("広告")
                .font(pochiPixelFont(10))
                .foregroundStyle(Color.cocoa.opacity(0.65))
                .opacity(loaded ? 1 : 0)
                .accessibilityHidden(!loaded)
            ZStack {
                Color.clear
                if canLoad && privacy.canRequestAds {
                    CompactBannerController(adUnitID: adUnitID, loaded: $loaded)
                        .opacity(loaded ? 1 : 0)
                        .allowsHitTesting(loaded)
                        .accessibilityHidden(!loaded)
                }
            }
                // Keep the slot stable during consent, loading and failures.
                .frame(width: 320, height: 50)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.cream)
    }
}

private struct CompactBannerController: UIViewControllerRepresentable {
    let adUnitID: String
    @Binding var loaded: Bool

    func makeUIViewController(context: Context) -> Host {
        let host = Host()
        host.adUnitID = adUnitID
        host.onLoaded = { loaded = $0 }
        return host
    }

    func updateUIViewController(_ host: Host, context: Context) {
        host.onLoaded = { loaded = $0 }
    }

    static func dismantleUIViewController(_ host: Host, coordinator: ()) {
        host.onLoaded = nil
        host.banner.delegate = nil
        host.banner.removeFromSuperview()
    }

    final class Host: UIViewController, BannerViewDelegate {
        let banner = BannerView(adSize: AdSizeBanner)
        var adUnitID = ""
        var onLoaded: ((Bool) -> Void)?
        private var requested = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            banner.translatesAutoresizingMaskIntoConstraints = false
            banner.adUnitID = adUnitID
            banner.rootViewController = self
            banner.delegate = self
            view.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                banner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                banner.widthAnchor.constraint(equalToConstant: 320),
                banner.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !requested, AdPrivacyManager.shared.canRequestAds else { return }
            requested = true
            banner.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoaded?(true)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onLoaded?(false)
        }
    }
}
