import Foundation
import AppKit
import ImageIO

/// The game's actual face frames in each supported Shiba coat, at 6× scale.
@main struct ShibaFaceReview {
    static func main() throws {
        let source = URL(fileURLWithPath: "promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png")
        let input = CGImageSourceCreateWithURL(source as CFURL, nil)!
        let atlas = PochiMotionSprites.atlas(for: .shiba, base: CGImageSourceCreateImageAtIndex(input, 0, nil)!)!
        let sheet = NSImage(size: NSSize(width: 768, height: 630))
        sheet.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 768, height: 630).fill()
        for (row, coat) in PochiCoat.allCases.enumerated() {
            let colored = coat.applying(to: atlas, breed: .shiba)
            for (column, pose) in [12, 13, 14, 29].enumerated() {
                let frame = colored.cropping(to: CGRect(x: pose % 4 * 32, y: pose / 4 * 32, width: 32, height: 32))!
                let x = column * 192, y = (2 - row) * 210 + 20
                NSImage(cgImage: frame, size: NSSize(width: 32, height: 32))
                    .draw(in: NSRect(x: x, y: y, width: 192, height: 192))
                ("\(coat.rawValue) / \(pose)" as NSString).draw(at: NSPoint(x: x + 8, y: y - 12), withAttributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.darkGray
                ])
            }
        }
        sheet.unlockFocus()
        let directory = URL(fileURLWithPath: "Design/FaceReview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!
            .write(to: directory.appendingPathComponent("shiba-front-three-coats.png"))
    }
}
