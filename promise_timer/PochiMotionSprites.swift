import Foundation
import CoreGraphics

enum PochiPose: Int {
    case stand = 3, eatUp = 4, eatDown = 5, sleep = 6, sit = 7
    case blink = 8, ear = 9, tailUp = 10, tailDown = 11
    case look = 12, lookBlink = 13, tilt = 14, crouch = 15
    case lie = 16, yawnSmall = 17, yawnWide = 18, breathe = 19
    case stretchStart = 20, stretchFull = 21, mealLower = 22, lick = 23
    case jumpReady = 24, landing = 25, sitBlink = 26, drowsy = 27
    case earBack = 28, tiltOther = 29, lieBlink = 30, wake = 31
    case pushupHigh = 32, pushupLow = 33, squatLow = 34, proudChest = 35
    case toyLiftLow = 36, toyLiftHigh = 37, proudTail = 38, plank = 39
    case bellyRest = 40, crunchHalf = 41, crunchUp = 42, deadBugLeft = 43
    case deadBugRight = 44, bridgeUp = 45, birdDogLeft = 46, birdDogRight = 47
    case crunchStart = 48, crunchRise = 49
    case plankBrace = 50, plankExhale = 51
}

/// Keeps the original Shiba silhouette. Face, torso and tail are independent
/// layers, attached at explicit anchors rather than cut out of a flattened dog.
enum PochiMotionSprites {
    static let columns = 4
    static let rows = 8
    private typealias Pixel = [UInt8]
    private static let clear: Pixel = [0,0,0,0]
    private static let ink: Pixel = [66,48,40,255]
    private static let fur: Pixel = [241,152,68,255]
    private static let cream: Pixel = [251,244,220,255]
    private static let tongue: Pixel = [221,145,131,255]

    private struct Frame {
        var pixels = [Pixel](repeating:clear,count:1024)
        subscript(_ x: Int,_ y: Int) -> Pixel {
            get { (0..<32).contains(x) && (0..<32).contains(y) ? pixels[y*32+x] : clear }
            set { if (0..<32).contains(x) && (0..<32).contains(y) { pixels[y*32+x] = newValue } }
        }
        mutating func rect(_ x: Int,_ y: Int,_ w: Int,_ h: Int,_ color: Pixel) {
            for yy in y..<(y+h) { for xx in x..<(x+w) { self[xx,yy] = color } }
        }
        mutating func stamp(_ lines: [String],x: Int,y: Int) {
            for (dy,line) in lines.enumerated() { for (dx,key) in line.enumerated() where key != "." {
                self[x+dx,y+dy] = key == "X" ? ink : key == "W" ? cream : fur
            } }
        }
        mutating func paint(_ other: Frame,dx: Int = 0,dy: Int = 0) {
            for y in 0..<32 { for x in 0..<32 where other[x,y][3] > 0 { self[x+dx,y+dy] = other[x,y] } }
        }
        mutating func shiftRegion(x: Int,y: Int,w: Int,h: Int,dx: Int) {
            guard dx != 0 else { return }
            let original = self
            rect(x,y,w,h,clear)
            for yy in y..<(y+h) { for xx in x..<(x+w) where original[xx,yy][3] > 0 { self[xx+dx,yy] = original[xx,yy] } }
        }
    }

    static func atlas(for breed: PochiBreed, base: CGImage) -> CGImage? {
        if breed != .shiba { return PochiBreedSprites.motionAtlas(for:breed) }
        guard base.width >= 128,base.height >= 64,
              let context = CGContext(data:nil,width:base.width,height:base.height,bitsPerComponent:8,bytesPerRow:base.width*4,
                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(base,in:CGRect(x:0,y:0,width:base.width,height:base.height))
        guard let bytes = context.data?.assumingMemoryBound(to:UInt8.self) else { return nil }
        func source(_ index: Int) -> Frame {
            var f = Frame()
            for y in 0..<32 { for x in 0..<32 {
                let offset = ((index/4*32+y)*base.width+index%4*32+31-x)*4
                let r = Int(bytes[offset]),g = Int(bytes[offset+1]),b = Int(bytes[offset+2])
                guard bytes[offset+3] >= 200 else { continue }
                // Remove partial-alpha edge noise and the baked-in red collar;
                // accessories are no longer drawn; keep only the natural coat.
                f[x,y] = r < 130 && g < 110 ? ink : r > 200 && g > 175 && b > 120 ? cream : fur
            } }
            return f
        }
        let stand = source(3),sleep = source(6)
        var profileHead = Frame()
        for y in 0..<13 { for x in 0..<14 { profileHead[x,y] = stand[x+2,y+6] } }
        // Clear the old eye in local head space before drawing any expression.
        profileHead.rect(4,7,2,2,fur)
        var torso = Frame()
        for y in 18..<32 { for x in 0..<32 { torso[x,y] = stand[x,y] } }
        for (row,left) in [14,13,12].enumerated() {
            torso.rect(left,15+row,25-left,1,fur)
            torso[25,15+row] = ink
        }
        torso.rect(14,15,11,1,ink)
        var frames: [Frame] = []
        for index in 0..<32 {
            if PochiSpriteGeometry.resting.contains(index) {
                var resting = sleep
                if index == 19 {
                    // Breathe by expanding the back edge one pixel; never slide
                    // a rectangle containing the face or the tail away from it.
                    for y in 16...18 {
                        if let edge = (0..<31).last(where:{ resting[$0,y][3] > 0 }) {
                            resting[edge,y] = fur; resting[edge+1,y] = ink
                        }
                    }
                }
                frames.append(resting)
                continue
            }
            var body = torso
            if PochiSpriteGeometry.seated.contains(index) {
                body.rect(14,15,18,15,clear)
                body.stamp(["..XX.........",".XOOX........","XOOOOX.......","XOOOOOOX.....","XOOOOOOOOX...","XOOOOOOOOOX..","XOOOOOOOOOOX.","XOOOOOOOOOOX.","XOOOOOOOOOOX.","XOOOOOOOOOOX.","XWWWWWWWWWX..","XXXXXXXXXXXX."],x:14,y:16)
            }
            if index < 3 {
                let step = [0,1,-1][index]
                body.shiftRegion(x:6,y:24,w:10,h:5,dx:step)
                body.shiftRegion(x:19,y:24,w:10,h:5,dx:-step)
            }
            let crouched = [15,24,25,31].contains(index)
            if [20,21].contains(index) {
                body.rect(5,23,10,7,clear)
                body.rect(11,22,3,5,fur)
                body.stamp([".......XX.",".....XXWWX","..XXXWWWWX",".XWWWWWWXX","..XXXXXX.."],x:3,y:23)
            }
            var f = Frame()
            if let root = PochiSpriteGeometry.tailRoot(.shiba,frame:index) {
                let tail = ["..XXXX..",".XWWWWX.","XWWWWWWX","XWOOOWWX",".XXOOWWX","...XOWWX","...XWWX.","....XX.."]
                let wag = index == 10 ? -1 : index == 11 ? 1 : 0
                let oy = Int(root.y)-7,ox = Int(root.x)-4
                for (y,row) in tail.enumerated() { for (x,key) in row.enumerated() where key != "." {
                    let bend = wag * (7-y) / 4
                    f[ox+x+bend,oy+y] = key == "X" ? ink : key == "W" ? cream : fur
                } }
            }
            f.paint(body,dy:crouched ? 1 : 0)
            guard let face = PochiSpriteGeometry.face(.shiba,frame:index) else { return nil }
            let frontal = [12,13,14,29].contains(index)
            var head = profileHead
            if frontal {
                head = Frame()
                // Same 14px head width, triangular ears, plain 2px eyes and
                // cream muzzle as the profile. Turning adds the far eye only;
                // it does not introduce blush or a different facial style.
                head.stamp([
                    "...X......X...",
                    ".XOOX....XOOX.",
                    ".XOWOXXXXOWOX.",
                    ".XOOOOOOOOOOX.",
                    "XOOOOOOOOOOOOX",
                    "XOOOOOOOOOOOOX",
                    "XOOOOOOOOOOOOX",
                    "XOOOOOOOOOOOOX",
                    "XWWOOOOOOOOWWX",
                    ".XWWWWWWWWWWX.",
                    ".XWWWWWWWWWWX.",
                    "..XWWWWWWWWX..",
                    "...XWWWWWWX...",
                    "....XXXXXX...."
                ],x:1,y:0)
                head.rect(7,9,2,1,ink)
                head[6,10] = ink
                head[9,10] = ink
                head.rect(7,11,2,1,ink)
            }
            if index == 9 || index == 28 {
                // Bend the ear tips while their lower outline stays attached.
                head.shiftRegion(x:0,y:0,w:14,h:2,dx:index == 9 ? -1 : 1)
            }
            let closed = [8,13,17,18,26,27].contains(index)
            for eye in face.eyes {
                let x = Int(eye.x),y = Int(eye.y)
                head.rect(x,y,2,2,fur)
                head.rect(x,y+(closed ? 1 : 0),2,closed ? 1 : 2,ink)
            }
            if [17,18].contains(index) {
                head.rect(2,10,3,index == 18 ? 2 : 1,ink)
                head.rect(3,index == 18 ? 11 : 10,1,1,tongue)
            }
            if index == 23 { head.rect(0,11,2,1,tongue) }
            for y in 0..<16 { for x in 0..<16 where head[x,y][3] > 0 {
                let point = face.point(x:x,y:y)
                f[Int(point.x),Int(point.y)] = head[x,y]
            } }
            frames.append(f)
        }
        let width = 128,height = 256
        var rgba = [UInt8](repeating:0,count:width*height*4)
        for (index,frame) in frames.enumerated() { for y in 0..<32 { for x in 0..<32 {
            let offset = (((index/4)*32+y)*width+(index%4)*32+x)*4
            for c in 0..<4 { rgba[offset+c] = frame[x,y][c] }
        } } }
        guard let provider = CGDataProvider(data:Data(rgba) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
            provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
