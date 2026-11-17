import SwiftUI
import UIKit

/// Shared by the app and widget. Keep semantic sizes and Dynamic Type scaling.
func pochiPixelFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
    .custom("PixelMplus12-Bold", size: size, relativeTo: style)
}

func pochiPixelFont(_ style: Font.TextStyle) -> Font {
    let size: CGFloat
    switch style {
    case .largeTitle: size = 34
    case .title: size = 28
    case .title2: size = 22
    case .title3: size = 20
    case .headline, .body: size = 17
    case .callout: size = 16
    case .subheadline: size = 15
    case .footnote: size = 13
    case .caption: size = 12
    case .caption2: size = 11
    @unknown default: size = 17
    }
    return pochiPixelFont(size, relativeTo: style)
}

func pochiPixelUIFont(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, compatibleWith traits: UITraitCollection? = nil) -> UIFont {
    let base = UIFont(name: "PixelMplus12-Bold", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    return UIFontMetrics(forTextStyle: style).scaledFont(for: base, compatibleWith: traits)
}

enum PochiTypography {
    static func configureAppAppearance() {
        UINavigationBar.appearance().titleTextAttributes = [.font: pochiPixelUIFont(17, relativeTo: .headline)]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: pochiPixelUIFont(34, relativeTo: .largeTitle)]
        for state in [UIControl.State.normal, .highlighted, .disabled, .selected] {
            UIBarButtonItem.appearance().setTitleTextAttributes([.font: pochiPixelUIFont(17)], for: state)
            UITabBarItem.appearance().setTitleTextAttributes([.font: pochiPixelUIFont(10, relativeTo: .caption2)], for: state)
            UISegmentedControl.appearance().setTitleTextAttributes([.font: pochiPixelUIFont(13, relativeTo: .footnote)], for: state)
        }
    }
}
