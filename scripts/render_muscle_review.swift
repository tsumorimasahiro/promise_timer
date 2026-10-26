import Foundation
import AppKit
import ImageIO

@main struct MuscleReview {
    static func main() throws {
        let directory = URL(fileURLWithPath: "Design/MuscleReview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: "promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL, nil)!
        let shiba = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let canvas = NSImage(size: NSSize(width: 1440, height: 660))
        canvas.lockFocus()
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1440, height: 660).fill()
        NSGraphicsContext.current?.imageInterpolation = .none
        for (row, breed) in PochiBreed.allCases.enumerated() {
            let base = PochiBreedSprites.atlas(for: breed) ?? shiba
            let motion = PochiMotionSprites.atlas(for: breed, base: base)!
            for stage in PochiMuscleStage.allCases {
                let atlas = PochiMuscleSprites.atlas(base: motion, breed: breed, stage: stage)
                let x = stage.rawValue * 288, y = (2-row) * 220
                for (col,pose) in [3,33].enumerated() {
                    let crop = atlas.cropping(to: CGRect(x: pose%4*32, y: pose/4*32, width: 32, height: 32))!
                    NSImage(cgImage: crop, size: NSSize(width: 32, height: 32)).draw(in: NSRect(x: x+col*144, y: y+30, width: 144, height: 144))
                }
                ("\(breed.rawValue) / \(stage.requiredDays) days" as NSString).draw(at: NSPoint(x: x+12, y: y+12), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.darkGray])
                let dest = CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(breed.rawValue)-stage-\(stage.rawValue).png") as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(dest, atlas, nil); CGImageDestinationFinalize(dest)
            }
        }
        canvas.unlockFocus()
        try NSBitmapImageRep(data: canvas.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("growth-stages.png"))

        let actions = NSImage(size: NSSize(width: 1280, height: 660))
        actions.lockFocus()
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1280, height: 660).fill()
        NSGraphicsContext.current?.imageInterpolation = .none
        let labels = ["Push-up / high", "Push-up / low", "Squat / low", "Tail wag / up", "Toy / down", "Toy / lifted", "Tail wag / down", "Plank"]
        for (row, breed) in PochiBreed.allCases.enumerated() {
            let base = PochiBreedSprites.atlas(for: breed) ?? shiba
            let motion = PochiMotionSprites.atlas(for: breed, base: base)!
            let atlas = PochiMuscleSprites.atlas(base: motion, breed: breed, stage: .champion)
            for col in 0..<8 {
                let pose = col+32, x = col*160, y = (2-row)*220
                let crop = atlas.cropping(to: CGRect(x: pose%4*32, y: pose/4*32, width: 32, height: 32))!
                NSImage(cgImage: crop, size: NSSize(width: 32, height: 32)).draw(in: NSRect(x: x+16, y: y+45, width: 128, height: 128))
                (labels[col] as NSString).draw(at: NSPoint(x: x+8, y: y+24), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.darkGray])
                (breed.rawValue as NSString).draw(at: NSPoint(x: x+8, y: y+8), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.darkGray])
            }
        }
        actions.unlockFocus()
        try NSBitmapImageRep(data: actions.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("canine-exercises.png"))
    }
}
