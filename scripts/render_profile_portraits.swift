import Foundation
import AppKit
import ImageIO

/// A source-rendered review image, not an app screenshot.
@main struct ProfilePortraitReview {
    static func main() throws {
        let output = URL(fileURLWithPath: "Design/ProfileReview")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let sheet = NSImage(size: NSSize(width: 512, height: 280))
        sheet.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 512, height: 280).fill()
        for (column, breed) in [PochiBreed.pomeranian, .dalmatian].enumerated() {
            let atlas = PochiBreedSprites.motionAtlas(for: breed)!
            let dog = atlas.cropping(to: CGRect(x: 96, y: 0, width: 32, height: 32))!
            NSImage(cgImage: dog, size: NSSize(width: 32, height: 32)).draw(in: NSRect(x: column*256, y: 24, width: 256, height: 256))
            (breed.titleKey as NSString).draw(at: NSPoint(x: column*256+32, y: 6), withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: NSColor.darkGray])
        }
        sheet.unlockFocus()
        try NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("cute-profiles.png"))
    }
}
