import Foundation
import CoreGraphics

/// Growth follows the existing dog's silhouette. Training frames keep the same
/// horizontal torso, muzzle, tail and grounded paws; there are no human limbs.
enum PochiMuscleSprites {
    static let columns = 4
    static let rows = 13
    private static let sources = Array(0..<32) + [3, 3, 3, 10, 3, 3, 11, 3] + Array(repeating: 3, count: 10) + [3, 8]
    private typealias Pixel = [UInt8]
    private static let clear: Pixel = [0, 0, 0, 0]

    static func atlas(base: CGImage, breed: PochiBreed, stage: PochiMuscleStage) -> CGImage {
        guard let data = base.dataProvider?.data, base.width == 128, base.height >= 256 else { return base }
        let input = Array(data as Data)
        let width = columns * 32, height = rows * 32
        var output = [UInt8](repeating: 0, count: width * height * 4)
        for (index, source) in sources.enumerated() {
            var pixels = [Pixel](repeating: clear, count: 1024)
            for y in 0..<32 { for x in 0..<32 {
                let offset = (source / 4 * 32 + y) * base.bytesPerRow + (source % 4 * 32 + x) * 4
                pixels[y * 32 + x] = Array(input[offset..<offset+4])
            } }
            pixels = grown(pixels, breed: breed, stage: stage, source: source)
            if index >= 32 { pixels = training(pixels, breed: breed, pose: index) }
            for y in 0..<32 { for x in 0..<32 {
                let offset = ((index / 4 * 32 + y) * width + index % 4 * 32 + x) * 4
                output.replaceSubrange(offset..<offset+4, with: pixels[y * 32 + x])
            } }
        }
        guard let provider = CGDataProvider(data: Data(output) as CFData) else { return base }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ?? base
    }

    private static func grown(_ original: [Pixel], breed: PochiBreed, stage: PochiMuscleStage, source: Int) -> [Pixel] {
        let level = stage.rawValue
        // Leave curled and seated silhouettes intact, rather than adding lumps
        // where a shoulder or haunch would be hidden by the resting posture.
        guard level > 0, !PochiSpriteGeometry.resting.contains(source),
              !PochiSpriteGeometry.seated.contains(source) else { return original }
        let ink: Pixel = breed == .pomeranian ? [151,104,58,255] : [66,48,40,255]
        let fur: Pixel = breed == .dalmatian ? [251,244,220,255] : breed == .pomeranian ? [230,165,87,255] : [241,152,68,255]
        var protected = Set<Int>()
        if let face = PochiSpriteGeometry.face(breed, frame: source) {
            let frontal = [12,13,14,29].contains(source)
            let w = breed == .shiba ? (frontal ? 16 : 14) : 22
            let h = breed == .shiba ? (frontal ? 15 : 13) : (breed == .pomeranian ? 19 : 16)
            for y in 0..<h { for x in 0..<w {
                let p = face.point(x: x, y: y)
                if (0..<32).contains(Int(p.x)), (0..<32).contains(Int(p.y)) {
                    protected.insert(Int(p.y)*32+Int(p.x))
                }
            } }
        }
        var result = original
        func occupied(_ pixels: [Pixel], _ x: Int, _ y: Int) -> Bool {
            (0..<32).contains(x) && (0..<32).contains(y) && pixels[y*32+x][3] > 0
        }
        // At this pixel size, one extra pixel at a shoulder is already a visible
        // change. Keep the feet, belly gap and tail unchanged at every stage.
        func expand(_ region: (Int, Int) -> Bool) {
            let before = result
            var added = Set<Int>()
            for y in 15..<25 { for x in 6..<31 where region(x, y) {
                let i = y*32+x
                guard !protected.contains(i), before[i][3] == 0 else { continue }
                if occupied(before,x-1,y) || occupied(before,x+1,y) || occupied(before,x,y-1) || occupied(before,x,y+1) {
                    result[i] = ink
                    added.insert(i)
                }
            } }
            for y in 15..<25 { for x in 6..<31 {
                let i = y*32+x
                guard !protected.contains(i), before[i] == ink,
                      [i-1,i+1,i-32,i+32].contains(where: { added.contains($0) }),
                      occupied(result,x-1,y), occupied(result,x+1,y),
                      occupied(result,x,y-1), occupied(result,x,y+1) else { continue }
                result[i] = fur
            } }
        }
        let shoulderX = breed == .shiba ? 8...14 : 10...15
        let haunchX = breed == .dalmatian ? 27...29 : 25...28
        expand { (shoulderX.contains($0) && (21...22).contains($1))
            || (breed != .shiba && haunchX.contains($0) && $1 == 22) }
        if level >= 2 {
            expand { (shoulderX.contains($0) && (20...23).contains($1))
                || (breed != .shiba && haunchX.contains($0) && (21...23).contains($1)) }
        }
        if level >= 3 {
            let outerHaunch = breed == .dalmatian ? 28...30 : haunchX
            expand { outerHaunch.contains($0) && (19...23).contains($1) }
        }
        if level >= 4 {
            // Broaden the upper back, never inflate the paws or draw abs.
            expand { ((17...23).contains($0) && (15...18).contains($1))
                || (breed == .pomeranian && (28...29).contains($0) && (20...21).contains($1)) }
        }
        return result
    }

    private static func training(_ original: [Pixel], breed: PochiBreed, pose: Int) -> [Pixel] {
        if (40...45).contains(pose) || (48...49).contains(pose) { return bellyTraining(original, breed: breed, pose: pose) }
        if (46...47).contains(pose) { return birdDog(original, breed: breed, alternate: pose == 47) }
        let frontDrop: Int
        let rearDrop: Int
        switch pose {
        case PochiPose.pushupHigh.rawValue: (frontDrop, rearDrop) = (1, 0)
        case PochiPose.pushupLow.rawValue: (frontDrop, rearDrop) = (3, 0)
        case PochiPose.squatLow.rawValue: (frontDrop, rearDrop) = (0, 3)
        case PochiPose.toyLiftLow.rawValue: (frontDrop, rearDrop) = (3, 0)
        case PochiPose.plank.rawValue, PochiPose.plankExhale.rawValue: (frontDrop, rearDrop) = (2, 1)
        case PochiPose.plankBrace.rawValue: (frontDrop, rearDrop) = (3, 1)
        default: (frontDrop, rearDrop) = (0, 0)
        }
        var result = [Pixel](repeating: clear, count: 1024)
        let headEnd = breed == .shiba ? 15 : 20
        let headBottom = breed == .shiba ? 18 : breed == .dalmatian ? 21 : 23
        func drop(x: Int) -> Int {
            if x <= headEnd { return frontDrop }
            let fraction = min(1, Double(x-headEnd) / Double(27-headEnd))
            return Int((Double(frontDrop) * (1-fraction) + Double(rearDrop) * fraction).rounded())
        }
        // Squash only the leg length as the chest/haunch lowers. The paws stay
        // on the same floor and the intact head translates as a single layer.
        for x in 0..<32 {
            let shift = drop(x: x)
            var anchor = 27
            for y in 28..<32 where original[y*32+x][3] > 0 { anchor = y }
            for y in 0..<32 where original[y*32+x][3] > 0 {
                let dy: Int
                if x <= headEnd && y <= headBottom { dy = frontDrop }
                else if y <= 22 { dy = shift }
                else { dy = Int((Double(shift) * max(0, Double(anchor-y) / Double(anchor-22))).rounded()) }
                let yy = y + dy
                if yy < 32 { result[yy*32+x] = original[y*32+x] }
            }
        }
        // A light dumbbell-shaped dog toy is lifted with the mouth, never a
        // weight held by human-like hands. All four paws remain on the floor.
        if pose == PochiPose.toyLiftLow.rawValue || pose == PochiPose.toyLiftHigh.rawValue {
            let toyY = (breed == .shiba ? 18 : 20) + frontDrop
            let edge: Pixel = [67,113,112,255], fill: Pixel = [131,187,168,255]
            let map = ["XX...XX", "XFXXXFX", "XFFFFFX", "XX...XX"]
            for (dy,row) in map.enumerated() { for (x,key) in row.enumerated() where key != "." {
                let y = toyY + dy
                if y < 32 { result[y*32+x] = key == "X" ? edge : fill }
            } }
        }
        return result
    }
    /// Dedicated supine drawings: muzzle up, ears down, paws tucked over a
    /// rounded belly. No standing-head crop, inversion or resampling.
    private static func bellyTraining(_ original: [Pixel], breed: PochiBreed, pose: Int) -> [Pixel] {
        let ink: Pixel = breed == .pomeranian ? [151,104,58,255] : [66,48,40,255]
        let fur: Pixel = breed == .dalmatian ? [251,244,220,255] : breed == .pomeranian ? [230,165,87,255] : [241,152,68,255]
        let cream: Pixel = breed == .pomeranian ? [247,203,135,255] : [251,244,220,255]
        let faceInk: Pixel = [49,39,35,255]
        let spot: Pixel = [81,72,65,255]
        var result = [Pixel](repeating: clear, count: 1024)
        let curl = [48: 1, 41: 2, 49: 3, 42: 4][pose, default: 0]
        let bridge = pose == 45 ? 3 : 0
        func stamp(_ lines: [String], _ x: Int, _ y: Int) {
            for (dy,line) in lines.enumerated() { for (dx,c) in line.enumerated() where c != "." {
                let xx = x+dx, yy = y+dy
                guard (0..<32).contains(xx), (0..<32).contains(yy) else { continue }
                result[yy*32+xx] = c == "X" ? ink : c == "O" ? fur : c == "R" ? faceInk : c == "K" ? spot : cream
            } }
        }
        // A tucked haunch and rounded back remain planted throughout the curl.
        stamp(["....XXXXXX.....", "..XXWWWWWWXX...", ".XWWWWWWWWWWX..",
               "XWWWWWWWWWWWWX.", "XWWWWWWWWWWWWX.", "XOWWWWWWWWWWOX.",
               ".XOOOOOOOOOOX..", "..XXOOOOOOXX...", "....XXXXXX....."], 14,20-bridge)
        stamp([".XXX", "XOOX", ".XX."],26,24-bridge)
        // The chest rolls toward the belly; it never stretches into a neck.
        stamp(["...XXXXX...", ".XXWWWWWXX.", "XWWWWWWWWWX", "XWWWWWWWWWX",
               "XOWWWWWWWOX", ".XOOOOOOOX.", "..XXXXXXX.."],10+curl/2,22-(curl+1)/2-bridge)
        if breed == .dalmatian {
            stamp(["KK..KK", "KK...K"],20,25-bridge)
        }
        // Far paws sit behind the near paws. Their folded tips face the belly.
        let foreReach = pose == 43 ? 3 : 0
        let hindReach = pose == 44 ? 3 : 0
        stamp([".XXX.", "XWWWX", ".XWWX", "..XWX", "..XX."],18,17-hindReach-bridge)
        stamp([".XXX.", "XWWWX", "XWWX.", ".XWX.", ".XWX.", "..XX."],24,17-hindReach-bridge)
        if hindReach > 0 {
            stamp(["XWX", "XWX", "XXX"],20,18-bridge)
            stamp(["XWX", "XWX", "XXX"],25,19-bridge)
        }
        // The head is drawn for lying on the back. The muzzle points up toward
        // the paws; the near ear rests below the eye on the mat.
        let shibaHead = [
            "........RR....", ".......XWWX...", "......XWWWX...", "....XXWWWWWX..",
            "...XOOOWWWWX..", "..XOOOROWWWX..", ".XOOOOROWWWX..", ".XOOOOOOWWX...",
            "XOOOOOOOOWX...", "XOOOOOOOOWX...", ".XOOOOOOOX....", ".XOOOXOOX.....",
            "..XOX.XX......", "...X.........."
        ]
        let dalHead = [
            "........RR....", ".......XWWX...", ".....XXWWWX...", "...XXWWWWWWX..",
            "..XWWWWWWWWX..", ".XWWWRWWWWWX..", ".XWWWRWWWWWX..", "XWWWWWWWWWWX..",
            "XKKWWWWWWWX...", "XKKKWWWWWX....", ".XKKKWWXX.....", "..XKKXX.......",
            "...XX.........", ".............."
        ]
        let pomHead = [
            "........RR....", ".......XWWX...", ".....XXWWWX...", "...XXWWWWWWX..",
            "..XOOOOWWWWX..", ".XOOOROOWWWX..", "XOOOOROOWWX...", ".XOOOOOWWWWX..",
            "XOOOOOOOWWX...", ".XOOOOOOOWX...", "XOWOOOOOOX....", ".XOOXOOOX.....",
            "..XX.XXX......", ".............."
        ]
        stamp(breed == .shiba ? shibaHead : breed == .dalmatian ? dalHead : pomHead,
              3+curl/2,15-(curl+1)/2)
        // Forepaws stay close to the chest as the shoulders curl inward.
        stamp([".XXX..", "XWWWX.", ".XWWWX", "..XWWX", "...XX."],15+curl/2,19-curl/2-foreReach)
        if foreReach > 0 { stamp(["XWX", "XWX", "XXX"],18+curl/2,19-curl/2) }
        if bridge > 0 { stamp(["XWX", "XWX", "XWX", "XXX"],24,25) }
        return result
    }

    private static func birdDog(_ original: [Pixel], breed: PochiBreed, alternate: Bool) -> [Pixel] {
        var result = training(original, breed: breed, pose: PochiPose.plank.rawValue)
        let ink: Pixel = breed == .pomeranian ? [151,104,58,255] : [66,48,40,255]
        let cream: Pixel = breed == .pomeranian ? [247,203,135,255] : [251,244,220,255]
        // One forepaw reaches forward while the opposite rear paw reaches back;
        // the other pair remains underneath the body as visible support.
        let y = alternate ? 24 : 23
        // Bent reach from the shoulder; keep the other forepaw as support.
        for yy in 25...28 { for xx in 6...9 { result[yy*32+xx] = clear } }
        let front = ["......XXX", "....XXWWX", "..XXWWWX.", ".XWWWXX..", "..XXX...."]
        for (dy,row) in front.enumerated() { for (dx,c) in row.enumerated() where c != "." {
            result[(y-2+dy)*32+4+dx] = c == "X" ? ink : cream
        } }
        let rear = ["....XX", "..XXWX", "XXWWX.", "XWXX..", ".XX..."]
        for (dy,row) in rear.enumerated() { for (dx,c) in row.enumerated() where c != "." {
            result[(y-5+dy)*32+26+dx] = c == "X" ? ink : cream
        } }
        return result
    }

}
