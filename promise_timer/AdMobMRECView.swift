import SwiftUI
import GoogleMobileAds

struct AdMobMRECView: View {
    let adUnitID: String

    var body: some View {
        VStack(spacing: 8) {
            Text("広告")
                .font(.caption.bold())
                .foregroundStyle(Color.candyBlue.opacity(0.7))
            AdMobMRECRepresentable(adUnitID: adUnitID)
                .frame(width: 300, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.candyBlue.opacity(0.12), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

private struct AdMobMRECRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeMediumRectangle)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = context.coordinator.rootViewController
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = context.coordinator.rootViewController
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        let rootViewController: UIViewController? = {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }
            return windows.first(where: { $0.isKeyWindow })?.rootViewController
        }()
    }
}
