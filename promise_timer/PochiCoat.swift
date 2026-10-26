import Foundation
import CoreGraphics

/// Stable legacy IDs are retained for Shiba owners. Other breeds store their
/// selections separately, so changing breed never overwrites another coat.
enum PochiCoat: String, CaseIterable, Identifiable {
    case kinako, milk, black
    var id: String { rawValue }

    static func storageKey(for breed: PochiBreed) -> String {
        breed == .shiba ? "pochiCoat" : "pochiCoat.\(breed.rawValue)"
    }
    static func selected(for breed: PochiBreed, defaults: UserDefaults) -> Self {
        Self(rawValue: defaults.string(forKey: storageKey(for: breed)) ?? "") ?? .kinako
    }
    func titleKey(for breed: PochiBreed) -> String {
        switch breed {
        case .shiba: return self == .kinako ? "赤柴" : self == .milk ? "白柴" : "黒柴"
        case .dalmatian: return self == .kinako ? "黒ぶち" : self == .milk ? "茶ぶち" : "レモン"
        case .pomeranian: return self == .kinako ? "オレンジ" : self == .milk ? "クリーム" : "ブラック"
        }
    }

    /// Replaces named fur/marking colors, including the Pomeranian fur contour.
    /// Alpha, facial ink, tongue and all frame geometry remain intact.
    func applying(to image: CGImage, breed: PochiBreed) -> CGImage {
        guard self != .kinako, let data = image.dataProvider?.data else { return image }
        var bytes = Array(data as Data)
        let replacements: [[UInt8]: [UInt8]]
        switch (breed, self) {
        case (.shiba, .milk):
            replacements = [[241,152,68]:[239,228,201]]
        case (.shiba, .black):
            replacements = [[241,152,68]:[111,103,94]]
        case (.dalmatian, .milk):
            replacements = [[81,72,65]:[146,94,64]]
        case (.dalmatian, .black):
            replacements = [[81,72,65]:[214,169,83]]
        case (.pomeranian, .milk):
            replacements = [[230,165,87]:[232,215,177], [247,203,135]:[246,234,208], [151,104,58]:[161,137,100]]
        case (.pomeranian, .black):
            replacements = [[230,165,87]:[111,103,94], [247,203,135]:[159,148,130], [151,104,58]:[66,48,40]]
        default: replacements = [:]
        }
        for y in 0..<image.height { for x in 0..<image.width {
            let i = y * image.bytesPerRow + x * 4
            guard bytes[i+3] == 255 else { continue }
            if let replacement = replacements[Array(bytes[i..<i+3])] {
                bytes.replaceSubrange(i..<i+3, with: replacement)
            }
        } }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return image }
        return CGImage(width:image.width, height:image.height, bitsPerComponent:8,
                       bitsPerPixel:32, bytesPerRow:image.bytesPerRow,
                       space:image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo:image.bitmapInfo, provider:provider, decode:nil,
                       shouldInterpolate:false, intent:.defaultIntent) ?? image
    }
}
