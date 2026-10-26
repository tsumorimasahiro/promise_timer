import Foundation
import CoreGraphics
import CoreText
import ImageIO

// Add a short heading around unaltered simulator captures, without redrawing the UI.
@main struct StoreScreenshots {
    static func main() throws {
        let root = URL(fileURLWithPath: "Design/AppStore/2026-10-22")
        let data = try Data(contentsOf: root.appendingPathComponent("listing.json"))
        let listing = try JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]
        let titles = listing.mapValues { $0["headlines"] as! [String] }
        for (locale, headlines) in titles {
            let folder = root.appendingPathComponent(locale)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, screen) in ["home", "promises", "memory", "profile", "habits", "history"].enumerated() {
                let input = root.appendingPathComponent("raw/\(locale)-\(screen).png")
                guard FileManager.default.fileExists(atPath: input.path),
                      let source = CGImageSourceCreateWithURL(input as CFURL, nil),
                      let screenshot = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                let canvas = CGContext(data: nil, width: 1320, height: 2868, bitsPerComponent: 8, bytesPerRow: 1320*4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
                canvas.setFillColor(CGColor(red: 0.984, green: 0.965, blue: 0.933, alpha: 1))
                canvas.fill(CGRect(x: 0, y: 0, width: 1320, height: 2868))
                let fontName = locale == "ja" ? "HiraginoSans-W6" : locale == "ko" ? "AppleSDGothicNeo-SemiBold" : locale == "zh-Hant" ? "PingFangTC-Semibold" : locale == "en-US" ? "HelveticaNeue-Medium" : "PingFangSC-Semibold"
                let font = CTFontCreateWithName(fontName as CFString, locale == "en-US" ? 78 : 72, nil)
                for (lineIndex, text) in headlines[index].split(separator: "\n").enumerated() {
                    let string = NSAttributedString(string: String(text), attributes: [
                        NSAttributedString.Key(kCTFontAttributeName as String): font,
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0.27, green: 0.32, blue: 0.25, alpha: 1)])
                    let line = CTLineCreateWithAttributedString(string)
                    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
                    canvas.textPosition = CGPoint(x: (1320-width)/2, y: CGFloat(2700-lineIndex*100))
                    CTLineDraw(line, canvas)
                }
                let rect = CGRect(x: 110, y: 74, width: 1100, height: 2390)
                let outline = CGPath(roundedRect: rect, cornerWidth: 46, cornerHeight: 46, transform: nil)
                canvas.saveGState()
                canvas.addPath(outline); canvas.clip()
                canvas.interpolationQuality = .none
                canvas.draw(screenshot, in: rect)
                canvas.restoreGState()
                canvas.setStrokeColor(CGColor(red: 0.34, green: 0.35, blue: 0.29, alpha: 0.22))
                canvas.setLineWidth(2); canvas.addPath(outline); canvas.strokePath()
                let out = folder.appendingPathComponent("0\(index+1)-\(screen).png")
                let destination = CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, canvas.makeImage()!, nil)
                precondition(CGImageDestinationFinalize(destination))
                print(out.path)
            }
        }
    }
}
