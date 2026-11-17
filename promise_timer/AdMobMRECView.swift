import SwiftUI
import GoogleMobileAds

/// Home-only native placement. The SDK owns impressions and clicks.
struct PochiNativeAd: View {
    @ObservedObject private var privacy = AdPrivacyManager.shared
    @State private var height: CGFloat = 0
    @State private var ready = false
    private var unitID: String {
#if DEBUG
        return "ca-app-pub-3940256099942544/3986624511"
#else
        return "ca-app-pub-4731680416753736/9271082757"
#endif
    }
    var body: some View {
        if privacy.canRequestAds {
            NativeAdController(unitID: unitID, height: $height, ready: $ready)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .transaction { $0.animation = nil }
                .opacity(ready ? 1 : 0)
                .allowsHitTesting(ready)
                .accessibilityHidden(!ready)
        }
    }
}

/// Explicit asset frames make the SDK's containment requirement independent of
/// label compression and stack-view constraint conflicts at large text sizes.
final class PochiNativeAdCard: NativeAdView {
    private let badge = UILabel()
    let headline = UILabel()
    let bodyLabel = UILabel()
    let advertiser = UILabel()
    let icon = UIImageView()
    let media = MediaView()
    let action = UIButton(type: .system)
    var assetViews: [UIView] { [headline, bodyLabel, advertiser, icon, media, action] }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        badge.text = NSLocalizedString("広告", comment: "Ad attribution")
        badge.textColor = .secondaryLabel
        headline.numberOfLines = 2
        bodyLabel.numberOfLines = 2
        advertiser.numberOfLines = 2
        advertiser.textColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        media.contentMode = .scaleAspectFit
        action.setTitleColor(.label, for: .normal)
        action.backgroundColor = .tertiarySystemFill
        action.layer.cornerRadius = 8
        action.titleLabel?.numberOfLines = 2
        action.titleLabel?.textAlignment = .center
        action.isUserInteractionEnabled = false
        for asset in [badge] + assetViews { addSubview(asset) }
        headlineView = headline; bodyView = bodyLabel; advertiserView = advertiser
        iconView = icon; mediaView = media; callToActionView = action
        updateFonts()
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func updateFonts(compatibleWith traits: UITraitCollection? = nil) {
        let traits = traits ?? traitCollection
        badge.font = pochiPixelUIFont(12, relativeTo: .caption1, compatibleWith: traits)
        headline.font = pochiPixelUIFont(16, relativeTo: .headline, compatibleWith: traits)
        bodyLabel.font = pochiPixelUIFont(13, relativeTo: .footnote, compatibleWith: traits)
        advertiser.font = pochiPixelUIFont(12, relativeTo: .caption1, compatibleWith: traits)
        action.titleLabel?.font = pochiPixelUIFont(15, relativeTo: .subheadline, compatibleWith: traits)
    }

    func populate(headline: String?, body: String?, advertiser: String?, icon: UIImage?, action: String?) {
        self.headline.text = headline
        bodyLabel.text = body; bodyLabel.isHidden = body?.isEmpty != false
        self.advertiser.text = advertiser; self.advertiser.isHidden = advertiser?.isEmpty != false
        self.icon.image = icon; self.icon.isHidden = icon == nil
        self.action.setTitle(action, for: .normal); self.action.isHidden = action?.isEmpty != false
        self.action.titleLabel?.text = action
    }

    /// Measures and positions assets without registering an ad or reporting impressions.
    @discardableResult
    func arrange(width: CGFloat) -> CGFloat {
        guard width >= 160 else { return 0 }
        let inset: CGFloat = 12
        let contentWidth = width - inset * 2
        func labelHeight(_ label: UILabel, _ width: CGFloat) -> CGFloat {
            ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        }
        var y = inset
        // Keep the upper-right corner available for the SDK's AdChoices overlay.
        let badgeHeight = max(20, labelHeight(badge, contentWidth - 44))
        badge.frame = CGRect(x: inset, y: y, width: contentWidth - 44, height: badgeHeight)
        y += badgeHeight + 8
        let iconWidth: CGFloat = icon.isHidden ? 0 : 44
        let titleX = inset + (iconWidth > 0 ? iconWidth + 10 : 0)
        let titleWidth = width - inset - titleX
        let headlineHeight = labelHeight(headline, titleWidth)
        headline.frame = CGRect(x: titleX, y: y, width: titleWidth, height: headlineHeight)
        let advertiserHeight = advertiser.isHidden ? 0 : labelHeight(advertiser, titleWidth)
        advertiser.frame = advertiser.isHidden ? .zero : CGRect(x: titleX, y: y + headlineHeight + 2, width: titleWidth, height: advertiserHeight)
        icon.frame = icon.isHidden ? .zero : CGRect(x: inset, y: y, width: 44, height: 44)
        y += max(iconWidth, headlineHeight + (advertiser.isHidden ? 0 : advertiserHeight + 2)) + 8
        let mediaHeight = max(120, min(220, contentWidth * 9 / 16))
        media.frame = CGRect(x: inset, y: y, width: contentWidth, height: mediaHeight)
        y += mediaHeight
        if bodyLabel.isHidden {
            bodyLabel.frame = .zero
        } else {
            y += 8
            let height = labelHeight(bodyLabel, contentWidth)
            bodyLabel.frame = CGRect(x: inset, y: y, width: contentWidth, height: height)
            y += height
        }
        if action.isHidden {
            action.frame = .zero
        } else {
            y += 8
            let titleHeight = action.titleLabel.map { labelHeight($0, contentWidth - 24) } ?? 0
            let height = max(44, titleHeight + 24)
            action.frame = CGRect(x: inset, y: y, width: contentWidth, height: height)
            y += height
        }
        return ceil(y + inset)
    }

    var assetsFit: Bool {
        bounds.width >= 160 && bounds.height > 0 && assetViews.filter { !$0.isHidden }.allSatisfy {
            !$0.frame.isEmpty && bounds.contains($0.frame)
        }
    }
}

private struct NativeAdController: UIViewControllerRepresentable {
    let unitID: String
    @Binding var height: CGFloat
    @Binding var ready: Bool
    func makeUIViewController(context: Context) -> Host {
        let host = Host()
        host.unitID = unitID
        host.onHeight = { height = $0 }
        host.onReady = { ready = $0 }
        return host
    }
    func updateUIViewController(_ host: Host, context: Context) {
        host.onHeight = { height = $0 }
        host.onReady = { ready = $0 }
    }
    static func dismantleUIViewController(_ host: Host, coordinator: ()) {
        host.onHeight = nil; host.onReady = nil
        host.loader?.delegate = nil
        host.card.nativeAd = nil
        host.ad = nil
    }
    final class Host: UIViewController, NativeAdLoaderDelegate {
        var unitID = ""
        var onHeight: ((CGFloat) -> Void)?
        var onReady: ((Bool) -> Void)?
        var loader: AdLoader?
        var ad: NativeAd?
        let card = PochiNativeAdCard(frame: .zero)
        private var reportedHeight: CGFloat = 0
        private var registered = false
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            card.isHidden = true
            view.addSubview(card)
            card.updateFonts(compatibleWith: traitCollection)
            loadOnce()
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            layoutAd()
        }
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                card.updateFonts(compatibleWith: traitCollection)
                view.setNeedsLayout()
            }
        }
        private func layoutAd() {
            guard let ad, onHeight != nil, AdPrivacyManager.shared.canRequestAds else { return }
            let needed = card.arrange(width: view.bounds.width)
            guard needed > 0 else { return }
            // Keep the registered NativeAdView itself large enough even while
            // SwiftUI is applying a new outer height after rotation/text changes.
            card.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: needed)
            if abs(reportedHeight - needed) > 0.5 {
                reportedHeight = needed
                DispatchQueue.main.async { [weak self] in self?.onHeight?(needed) }
            }
            // Wait for SwiftUI to apply the measured height before SDK registration.
            // Never reveal a registered ad while rotation/Dynamic Type is resizing it.
            guard view.bounds.height >= needed, card.assetsFit else {
                card.isHidden = true
                return
            }
            card.layoutIfNeeded()
            card.isHidden = false
            if !registered {
                card.nativeAd = ad
                registered = true
                DispatchQueue.main.async { [weak self] in self?.onReady?(true) }
            }
#if DEBUG
            PochiNativeAdDiagnostics.writeRegistration(card: card, requiredHeight: needed)
#endif
        }
        private func loadOnce() {
            guard loader == nil, AdPrivacyManager.shared.canRequestAds else { return }
            let video = VideoOptions(); video.shouldStartMuted = true
            loader = AdLoader(adUnitID: unitID, rootViewController: self, adTypes: [.native], options: [video])
            loader?.delegate = self
            loader?.load(Request())
        }
        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            guard AdPrivacyManager.shared.canRequestAds, onHeight != nil else { return }
            ad = nativeAd; nativeAd.rootViewController = self
            card.populate(headline: nativeAd.headline, body: nativeAd.body, advertiser: nativeAd.advertiser,
                          icon: nativeAd.icon?.image, action: nativeAd.callToAction)
            card.media.mediaContent = nativeAd.mediaContent
            view.setNeedsLayout()
            layoutAd()
        }
        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            onReady?(false); onHeight?(0)
        }
    }
}

#if DEBUG
/// Debug-only regression entry points use the actual asset layout without live clicks.
enum PochiNativeAdDiagnostics {
    static func write(_ report: [String: Any], name: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
    static func writeRegistration(card: PochiNativeAdCard, requiredHeight: CGFloat) {
        write(["registered": true, "assetsFit": card.assetsFit,
               "width": card.bounds.width, "height": card.bounds.height, "requiredHeight": requiredHeight,
               "headlinePointSize": card.headline.font.pointSize,
               "contentSizeCategory": card.traitCollection.preferredContentSizeCategory.rawValue],
              name: "pochi-native-ad-check.json")
    }
    static func runLayoutChecks() -> String {
        let categories: [UIContentSizeCategory] = [.extraSmall, .large, .extraExtraExtraLarge, .accessibilityExtraExtraExtraLarge]
        let widths: [CGFloat] = [280, 320, 375, 768]
        var failures: [String] = []
        var cases = 0
        var normalHeight: CGFloat = 0
        var largestHeight: CGFloat = 0
        let card = PochiNativeAdCard(frame: .zero)
        for category in categories {
            card.updateFonts(compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
            for width in widths {
                for full in [false, true] {
                    card.populate(headline: full ? String(repeating: "日本語の長い広告タイトル Long headline ", count: 8) : "広告",
                                  body: full ? String(repeating: "長い広告文を表示します。Long advertising text. ", count: 12) : nil,
                                  advertiser: full ? String(repeating: "広告主 Advertiser ", count: 5) : nil,
                                  icon: full ? UIImage(systemName: "square.fill") : nil,
                                  action: full ? "詳しい情報を確認する Learn more about this advertisement" : nil)
                    let needed = card.arrange(width: width)
                    // This models the old registration timing: content exists while the host is collapsed.
                    card.frame = CGRect(x: 0, y: 0, width: width, height: 0)
                    if card.assetsFit { failures.append("Collapsed view incorrectly accepted") }
                    card.frame.size.height = needed
                    card.layoutIfNeeded()
                    if !card.assetsFit || !needed.isFinite { failures.append("Asset overflow: \(category.rawValue), \(width), \(full)") }
                    let ordered: [UIView] = [card.headline, card.media, card.bodyLabel, card.action].filter { !$0.isHidden }
                    for pair in zip(ordered, ordered.dropFirst()) where pair.0.frame.maxY > pair.1.frame.minY {
                        failures.append("Overlapping vertical assets")
                    }
                    if full && width == 320 && category == .large { normalHeight = needed }
                    if full && width == 320 && category == .accessibilityExtraExtraExtraLarge { largestHeight = needed }
                    cases += 1
                }
            }
        }
        if largestHeight <= normalHeight { failures.append("Dynamic Type did not increase the required height") }
        write(["cases": cases, "failures": failures, "normalHeight": normalHeight, "largestHeight": largestHeight],
              name: "pochi-native-layout-regression.json")
        return failures.isEmpty ? "Native layout: \(cases) passed" : failures.joined(separator: "\n")
    }
}

struct PochiNativeLayoutReview: View {
    @State private var result = "Checking native layout"
    var body: some View {
        Text(result).font(pochiPixelFont(16)).padding()
            .task { result = PochiNativeAdDiagnostics.runLayoutChecks() }
    }
}
#endif
