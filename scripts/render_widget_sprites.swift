import Foundation
import CoreGraphics
import ImageIO

/// Export exact game frames; no separately drawn widget dog.
@main struct WidgetSprites {
    static func main() throws {
        let root = URL(fileURLWithPath: "promise_timer/Assets.xcassets")
        let source = CGImageSourceCreateWithURL(root.appendingPathComponent("pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL, nil)!
        let shiba = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        for breed in PochiBreed.allCases {
            let atlas = PochiMotionSprites.atlas(for: breed, base: PochiBreedSprites.atlas(for: breed) ?? shiba)!
            for coat in PochiCoat.allCases {
                let colored = coat.applying(to: atlas, breed: breed)
                for pose in [6, 7, 10, 12, 14, 16] {
                    let frame = colored.cropping(to: CGRect(x: pose % 4 * 32, y: pose / 4 * 32, width: 32, height: 32))!
                    let asset = root.appendingPathComponent("pochi-widget-\(breed.rawValue)-\(coat.rawValue)-\(pose).imageset")
                    try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
                    let out = CGImageDestinationCreateWithURL(asset.appendingPathComponent("dog.png") as CFURL, "public.png" as CFString, 1, nil)!
                    CGImageDestinationAddImage(out, frame, nil)
                    precondition(CGImageDestinationFinalize(out))
                    try Data("{\"images\":[{\"filename\":\"dog.png\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: asset.appendingPathComponent("Contents.json"))
                }
            }
        }
        print("Exported 54 canonical widget frames (3 breeds × 3 coats × 6 poses).")
    }
}
