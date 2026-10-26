import AppKit

@main struct WorkoutIconReview {
    static func main() throws {
        let names = ["スクワット", "腕立て伏せ", "腹筋", "プランク", "サイドプランク", "バードドッグ", "デッドバグ", "ランジ", "ダンベル", "ヒップリフト", "かかと上げ"]
        let image = NSImage(size: NSSize(width: 600, height: 480))
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = false
        NSColor(calibratedRed: 1, green: 0.97, blue: 0.92, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 600, height: 480).fill()
        for (index, name) in WorkoutPixelArt.names.enumerated() {
            let left = (index % 4) * 150 + 27, top = (index / 4) * 160 + 16
            for pixel in WorkoutPixelArt.pixels(for: name) {
                let color: NSColor = pixel.tone == 2 ? NSColor(calibratedRed: 0.30, green: 0.23, blue: 0.18, alpha: 1)
                    : NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.29, alpha: pixel.tone == 3 ? 0.4 : 1)
                color.setFill()
                NSRect(x: left + pixel.x * 4, y: 480 - top - (pixel.y + 1) * 4, width: 4, height: 4).fill()
            }
            (names[index] as NSString).draw(at: NSPoint(x: (index % 4) * 150 + 12, y: 480 - top - 125),
                withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.darkGray])
        }
        image.unlockFocus()
        let directory = URL(fileURLWithPath: "Design/HomeWorkoutReview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("exercise-icons.png"))
    }
}
