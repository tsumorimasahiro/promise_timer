import Foundation
import AppKit
import ImageIO

@main struct FaceReview {
    static func main() throws {
        let directory = URL(fileURLWithPath: "Design/FaceReview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let input = CGImageSourceCreateWithURL(URL(fileURLWithPath: "promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL, nil)!
        let sheet = NSImage(size: NSSize(width: 384, height: 630))
        sheet.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 384, height: 630).fill()
        for (row, breed) in PochiBreed.allCases.enumerated() {
            let base = PochiBreedSprites.atlas(for: breed) ?? CGImageSourceCreateImageAtIndex(input, 0, nil)!
            let atlas = PochiMotionSprites.atlas(for: breed, base: base)!
            for (column, index) in [3,12].enumerated() {
                let crop = atlas.cropping(to: CGRect(x: index%4*32, y: index/4*32, width: 32, height: 32))!
                let x = column*192, y = (2-row)*210+20
                NSImage(cgImage: crop, size: NSSize(width: 32,height: 32)).draw(in: NSRect(x:x,y:y,width:192,height:192))
                ("\(breed.titleKey)・\(index == 3 ? "横顔" : "正面")" as NSString).draw(at:NSPoint(x:x+8,y:y-12),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.darkGray])
            }
        }
        sheet.unlockFocus()
        let filename = CommandLine.arguments.dropFirst().first ?? "face-consistency.png"
        try NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to:directory.appendingPathComponent(filename))
    }
}
