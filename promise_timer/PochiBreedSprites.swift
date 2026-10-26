import Foundation
import CoreGraphics

/// Each breed has one modular face, coat and marking map, shared by all 32
/// poses. Coordinates are whole pixels; transparent padding stays in the frame.
enum PochiBreedSprites {
    private struct PixelFrame {
        var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
        let dal: Bool
        var fur: Character { dal ? "W" : "O" }
        func color(_ key: Character) -> [UInt8] {
            switch key {
            case "X": return dal ? [66, 48, 40, 255] : [151, 104, 58, 255]
            case "R": return [66, 48, 40, 255]
            case "K": return [81, 72, 65, 255]
            case "W": return [251, 244, 220, 255]
            case "S": return [218, 210, 190, 255]
            case "O": return [230, 165, 87, 255]
            case "L": return [247, 203, 135, 255]
            default: return [221, 145, 131, 255]
            }
        }
        mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ key: Character) {
            let rgba = color(key)
            for yy in max(0,y)..<max(0,min(32,y+h)) {
                for xx in max(0,x)..<max(0,min(32,x+w)) {
                    let i = (yy * 32 + xx) * 4
                    for c in 0..<4 { bytes[i+c] = rgba[c] }
                }
            }
        }
        mutating func stamp(_ lines: [String], x: Int, y: Int) {
            for (dy,line) in lines.enumerated() {
                for (dx,key) in line.enumerated() where key != "." {
                    rect(x+dx, y+dy, 1, 1, key)
                }
            }
        }
        mutating func head(layout: PochiFaceLayout, eyesClosed: Bool, sleepy: Bool = false,
                           ear: Int = 0, mouth: Int = 0, lick: Bool = false) {
            var layer = PixelFrame(dal:dal)
            // Puppy proportions: a rounded forehead and full hanging ears.
            // Neither the spot map nor the face changes between poses.
            let dalHead = [
                "......XXXXXXXX.......", "....XXWWWWWWWWXX.....",
                "...XWWWWWWWWWWWWX....", "..XWWWWWWWWWWWWWWX...",
                ".XWWWWWWWWWWWWWWWWX..", ".XWWWWWWWWWWWWWWWWX..",
                ".XWWWWWWWWWWWWWWWWX..", ".XWWWWWWWWWWWWWWWWX..",
                "..XWWWWWWWWWWWWWWX...", "..XWWWWWWWWWWWWWWX...",
                "..XWWWWWWWWWWWWWWX...", "...XWWWWWWWWWWWWX....",
                "...XWWWWWWWWWWWWX....", "....XWWWWWWWWWWX.....",
                ".....XXWWWWWWXX......", ".......XXXXXX........"
            ]
            // One continuous ruff from cheeks to chest. Short stair-step tufts
            // create volume at 32px; small ears sit inside the furry outline.
            let pomHead = [
                ".....XX......XX......", "....XLLX....XLLX.....",
                "...XLOOLXXXXLOOLX....", "...XOOOOOOOOOOOOLX...",
                "..XLOOOOOOOOOOOOOLX..", ".XLOOOOOOOOOOOOOOOLX.",
                "..XOOOOOOOOOOOOOOOX..", ".XLOOOOOOOOOOOOOOOLX.",
                "XLOOOOOOOOOOOOOOOOOLX", ".XLOWWWOOOOOOWWWOOLX.",
                "XLLWWWWWWWWWWWWWWLLX.", ".XWWWWWWWWWWWWWWWWX..",
                "XLLWWWWWWWWWWWWWWLLX.", ".XWWWWWWWWWWWWWWWWX..",
                "..XLWWWWWWWWWWWWLX...", ".XLLWWWWWWWWWWWWLLX..",
                "....XXWWWWWWWWXX....."
            ]
            let frontal = layout.eyes.count == 2
            // A separate silhouette, not a frontal face with one eye erased:
            // muzzle projects left, the near ear stays at the rear of the head.
            let dalProfile = [
                ".....XXXXXX..........", "...XXWWWWWWXX........",
                "..XWWWWWWWWWWX.......", ".XWWWWWWWWWWWWX......",
                ".XWWWWWWWWWWWWWX.....", ".XWWWWWWWWWWWWWX.....",
                ".XWWWWWWWWWWWWWX.....", ".XWWWWWWWWWWWWWX.....",
                "XWWWWWWWWWWWWWWX.....", "XWWWWWWWWWWWWWWX.....",
                "XWWWWWWWWWWWWWWX.....", ".XWWWWWWWWWWWWWX.....",
                "..XWWWWWWWWWWWX......", "...XXWWWWWWWXX.......",
                ".....XXXXXXX........."
            ]
            let pomProfile = [
                ".......XX...XX.......", "......XLLXXXLLX......",
                "....XXLOOOOOOOLX.....", "...XLOOOOOOOOOOLX....",
                "..XLOOOOOOOOOOOOLX...", ".XLOOOOOOOOOOOOOLX...",
                "..XOOOOOOOOOOOOOOLX..", ".XLOOOOOOOOOOOOOOLX..",
                ".XLWWWWOOOOOOOOOOLX..", "XWWWWWWWWOOOOOOOLX...",
                "XWWWWWWWWWWWWWWWLLX..", ".XWWWWWWWWWWWWWWWX...",
                "..XLWWWWWWWWWWWWLX...", ".XLLWWWWWWWWWWWLX....",
                "...XLWWWWWWWWWLX.....", "....XXWWWWWWWXX......",
                "......XXXXXXX........"
            ]
            layer.stamp(frontal ? (dal ? dalHead : pomHead) : (dal ? dalProfile : pomProfile),x:0,y:0)
            if dal {
                // The same rounded ear and forehead spot in either view.
                let earPixels = [".XXX.","XWWWX","XWKKX","XKKKX","XKKKX",".XKKX",".XKKX","..XX."]
                if frontal {
                    layer.stamp(earPixels.map { String($0.reversed()) },x:0,y:2+ear)
                    layer.stamp(earPixels,x:16,y:2-ear)
                    layer.stamp(["KK",".K"],x:12,y:2)
                } else {
                    layer.stamp(earPixels,x:11,y:2+ear)
                    layer.stamp(["KK",".K"],x:6,y:2)
                }
            }
            if !dal && ear != 0 {
                let original = layer
                for yy in 0..<2 { for xx in 0..<22 {
                    let offset = (yy*32+xx)*4
                    for c in 0..<4 { layer.bytes[offset+c] = 0 }
                } }
                for yy in 0..<2 { for xx in 0..<22 {
                    let source = (yy*32+xx)*4
                    guard original.bytes[source+3] > 0 else { continue }
                    let targetX = xx + ear
                    guard (0..<32).contains(targetX) else { continue }
                    let dest = (yy*32+targetX)*4
                    for c in 0..<4 { layer.bytes[dest+c] = original.bytes[source+c] }
                } }
            }
            if frontal {
                layer.rect(4,10,2,1,"P")
                layer.rect(15,10,2,1,"P")
            } else { layer.rect(10,10,2,1,"P") }
            for eye in layout.eyes {
                let x = Int(eye.x),y = Int(eye.y)
                if eyesClosed || sleepy { layer.rect(x,y+1,3,1,"R") }
                else {
                    // Rounded 4px eye with a single light catch; its size and
                    // placement remain identical through all side poses.
                    layer.stamp([".RR.","RWRR","RRRR",".RR."],x:x,y:y)
                }
            }
            if frontal {
                let noseX = 10
                layer.rect(noseX-1,10,3,1,"R")
                layer.rect(noseX,11,1,1,"R")
                if mouth > 0 {
                    layer.rect(noseX-1,11,3,mouth,"R")
                    layer.rect(noseX,11+mouth-1,1,1,"P")
                } else {
                    layer.rect(noseX-1,12,3,1,"R")
                    layer.rect(noseX-2,11,1,1,"R")
                    layer.rect(noseX+2,11,1,1,"R")
                }
                if lick { layer.rect(noseX,12,2,1,"P") }
            } else {
                // Keep the nose inside a short round muzzle, with a small
                // upturned smile instead of a long projecting snout/bar mouth.
                layer.rect(2,10,2,1,"R")
                if mouth > 0 {
                    layer.rect(4,12,3,mouth,"R")
                    layer.rect(5,12+mouth-1,1,1,"P")
                } else {
                    layer.rect(4,12,2,1,"R")
                    layer.rect(6,11,1,1,"R")
                }
                if lick { layer.rect(4,13,2,1,"P") }
            }
            // Eyelids, ears, muzzle and outline take exactly the same transform.
            for yy in 0..<20 { for xx in 0..<22 {
                let source = (yy*32+xx)*4
                guard layer.bytes[source+3] > 0 else { continue }
                let point = layout.point(x:xx,y:yy)
                let x = Int(point.x),y = Int(point.y)
                guard (0..<32).contains(x),(0..<32).contains(y) else { continue }
                let dest = (y*32+x)*4
                for c in 0..<4 { bytes[dest+c] = layer.bytes[source+c] }
            } }
        }
        mutating func tail(root: CGPoint, wag: Int) {
            let rows = dal ? ["...XX", "..XWX", ".XWX.", "XWX..", ".X..."] :
                ["...XXXX..", "..XLLLLX.", ".XLLWWLLX", "XLLWWWLLX",
                 ".XLLWWLLX", "XLLWWLLX.", ".XLLLLX..", "..XLLX...", "...XX...."]
            let bottom = rows.count-1
            let ox = Int(root.x)-(dal ? 1 : 4),oy = Int(root.y)-bottom
            for (dy,row) in rows.enumerated() { for (dx,key) in row.enumerated() where key != "." {
                // The base never translates. Only the upper tail bends.
                let bend = wag*(bottom-dy)/3
                rect(ox+dx+bend,oy+dy,1,1,key)
            } }
        }
        mutating func body(index: Int, seated: Bool, resting: Bool, step: Int, bow: Int) {
            let wag = index == 10 ? -1 : index == 11 ? 1 : step
            if let root = PochiSpriteGeometry.tailRoot(dal ? .dalmatian : .pomeranian,frame:index) { tail(root:root,wag:wag) }
            let y = PochiSpriteGeometry.bodyY(index)
            // Foreleg connects the broad paw to the chest (no detached feet).
            if !resting {
                rect(11,19,4,8,"X")
                rect(12,19,2,7,"W")
                if !dal {
                    stamp([".XWWWWX.","XWWWWWWX",".XWWWWX.","..XWWX.."],x:10,y:21)
                }
            }
            var shape = dal ? ["...XXXXXXXXX...", "..XWWWWWWWWWX..", ".XWWWWWWWWWWWX.", "XWWWWWWWWWWWWWX", "XWWWWWWWWWWWWWX", "XWWWWWWWWWWWWWX", ".XWWWWWWWWWWWX.", "..XWWWWWWWWWX..", "...XXXXXXXXX..."] :
                ["....XXXXXXX....", "..XXLLLLLLLXX..", ".XLOOOOOOOOOLX.",
                 "XLOOOOOOOOOOOLX", ".XOOOOOOOOOOOX.", "XLOOOOOOOOOOOLX",
                 ".XOOOWWWWWOOOX.", "XLLWWWWWWWWWLLX", ".XWWWWWWWWWWWX.",
                 "..XWWWWWWWWWX..", "....XXXXXXX...."]
            if resting && !dal {
                shape = ["....XXXXXXX....","..XXLLLLLLLXX..",".XLOOOOOOOOOLX.",
                         "XLOOOOOOOOOOOLX",".XOOOWWWWWOOOX.","..XWWWWWWWWWX..","....XXXXXXX...."]
            }
            stamp(shape,x:dal ? 15 : 13,y:y)
            if dal {
                stamp([".K.","KKK",".K."],x:23,y:y+1)
                stamp([".K.","KKK",".K."],x:17,y:y+2)
                rect(21,y+4,1,1,"K")
            }
            if resting {
                stamp([".XXXXXX.","XWWWWWWX",".XXXXXX."],x:8,y:26)
                return
            }
            if seated {
                stamp(dal ? [".XXXXXX.","XWWWWWWX","XWWWWWWX","XXXXXXXX"] : [".XXXXXX.","XLWWWLLX","XLWWWLLX","XXXXXXXX"],x:20,y:24)
            } else {
                for (px,offset) in [(17,step),(dal ? 27 : 25,-step)] {
                    rect(px+offset,24,3,3,"X")
                    rect(px+offset+1,24,1,2,fur)
                    stamp([".XXX.","XWWWX",".XXX."],x:px+offset-1,y:25)
                }
            }
            // Front paws are short and broad, rather than stick legs.
            let front = bow > 0 ? 6 : 9
            stamp([".XXXX.","XWWWWX",".XXXX."],x:front,y:25)
            if seated { rect(13,22,2,4,fur) }
        }
    }

    static func atlas(for breed: PochiBreed) -> CGImage? {
        render(breed, frameCount: 8)
    }
    static func motionAtlas(for breed: PochiBreed) -> CGImage? {
        render(breed, frameCount: 32)
    }
    private static func render(_ breed: PochiBreed, frameCount: Int) -> CGImage? {
        guard breed != .shiba else { return nil }
        let width = 128, height = frameCount / 4 * 32
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<frameCount {
            var f = PixelFrame(dal: breed == .dalmatian)
            let resting = PochiSpriteGeometry.resting.contains(index)
            let seated = PochiSpriteGeometry.seated.contains(index)
            let bow = index == 20 ? 2 : index == 21 ? 4 : 0
            let step = index < 3 ? [0,1,-1][index] : 0
            f.body(index:index,seated:seated,resting:resting,step:step,bow:bow)
            let closed = [6,8,13,17,18,19,26,30].contains(index)
            guard let face = PochiSpriteGeometry.face(breed,frame:index) else { return nil }
            f.head(layout:face,eyesClosed:closed,sleepy:index == 27,
                   ear:index == 9 ? -1 : index == 28 ? 1 : 0,mouth:index == 17 ? 1 : index == 18 ? 2 : 0,lick:index == 23)
            for y in 0..<32 { for x in 0..<32 {
                let source = (y*32+x)*4
                let target = (((index/4)*32+y)*width+(index%4)*32+x)*4
                for c in 0..<4 { rgba[target+c] = f.bytes[source+c] }
            } }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
            provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
