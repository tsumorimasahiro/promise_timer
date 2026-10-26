import Foundation
import AppKit
import ImageIO

@main struct CoatReview {
    static func main() throws {
        let output = URL(fileURLWithPath: "Design/CoatReview")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: "promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL, nil)!
        let shiba = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let sheet = NSImage(size: NSSize(width: 864, height: 756))
        sheet.lockFocus()
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 864, height: 756).fill()
        NSGraphicsContext.current?.imageInterpolation = .none
        for (row, breed) in PochiBreed.allCases.enumerated() {
            let atlas = PochiMotionSprites.atlas(for: breed, base: PochiBreedSprites.atlas(for: breed) ?? shiba)!
            for (column, coat) in PochiCoat.allCases.enumerated() {
                let colored = coat.applying(to: atlas, breed: breed)
                let dog = colored.cropping(to: CGRect(x: 96, y: 0, width: 32, height: 32))!
                let name = "pochi-coat-\(breed.rawValue)-\(coat.rawValue)"
                let asset = URL(fileURLWithPath: "promise_timer/Assets.xcassets/\(name).imageset")
                try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
                let png = CGImageDestinationCreateWithURL(asset.appendingPathComponent("dog.png") as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(png, dog, nil); CGImageDestinationFinalize(png)
                try Data("{\"images\":[{\"filename\":\"dog.png\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: asset.appendingPathComponent("Contents.json"))
                let x = column * 288 + 16, y = (2-row)*252+30
                NSImage(cgImage: dog, size: NSSize(width: 32, height: 32)).draw(in: NSRect(x: x, y: y, width: 256, height: 256))
                ("\(breed.titleKey) · \(coat.titleKey(for: breed))" as NSString).draw(at: NSPoint(x: x+8, y: y-8), withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: NSColor.darkGray])
                let dst = CGImageDestinationCreateWithURL(output.appendingPathComponent("\(breed.rawValue)-\(coat.rawValue)-atlas.png") as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(dst, colored, nil); CGImageDestinationFinalize(dst)
            }
        }
        sheet.unlockFocus()
        try NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("nine-coats.png"))
    }
}
