import Foundation
import CoreGraphics
import ImageIO

/// The icon is the exact sleeping Shiba frame used by the game, on opaque cream.
@main struct SleepingAppIcon {
    static func main() throws {
        let input = URL(fileURLWithPath: "promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png")
        let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
        let base = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let atlas = PochiMotionSprites.atlas(for: .shiba, base: base)!
        let sleep = atlas.cropping(to: CGRect(x: 64, y: 32, width: 32, height: 32))!
        let pixels = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        pixels.draw(sleep, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        let bytes = pixels.data!.assumingMemoryBound(to: UInt8.self)
        var left = 32, right = 0, bottom = 32, top = 0
        for y in 0..<32 { for x in 0..<32 where bytes[(y*32+x)*4+3] > 0 {
            left = min(left, x); right = max(right, x)
            bottom = min(bottom, y); top = max(top, y)
        } }
        // Scan the canonical CGImage as well, avoiding a coordinate convention change.
        let full = pixels.makeImage()!
        let crop = full.cropping(to: CGRect(x: left, y: bottom, width: right-left+1, height: top-bottom+1))!
        let review = URL(fileURLWithPath: "Design/IconPreview", isDirectory: true)
        try FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
        func write(_ image: CGImage, _ url: URL) {
            let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image, nil)
            precondition(CGImageDestinationFinalize(dest))
        }
        func icon(_ side: Int) -> CGImage {
            let canvas = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side*4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            canvas.interpolationQuality = .none
            canvas.setShouldAntialias(false)
            canvas.setFillColor(CGColor(red: 249/255, green: 244/255, blue: 226/255, alpha: 1))
            canvas.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let scale = CGFloat(side)/32
            let x = floor(CGFloat(32-crop.width)/2)*scale
            let y = floor(CGFloat(32-crop.height)/2)*scale
            canvas.draw(crop, in: CGRect(x: x, y: y, width: CGFloat(crop.width)*scale, height: CGFloat(crop.height)*scale))
            return canvas.makeImage()!
        }
        let asset = URL(fileURLWithPath: "promise_timer/Assets.xcassets/AppIcon.appiconset/pochi-pixel-icon.png")
        let backup = review.appendingPathComponent("before-sleeping-icon.png")
        if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: asset, to: backup) }
        write(icon(1024), asset)
        write(icon(256), review.appendingPathComponent("sleeping-app-icon-256.png"))
        write(icon(60), review.appendingPathComponent("sleeping-app-icon-60.png"))
        print("Saved opaque sleeping Shiba icon; exact game sprite, \(crop.width)x\(crop.height) occupied pixels.")
    }
}
