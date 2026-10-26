import Foundation
import CoreGraphics
import ImageIO

func check(_ value: Bool,_ message: String) { if !value { fatalError(message) } }
func key(_ p: CGPoint) -> Int { Int(p.y)*32+Int(p.x) }
let url = URL(fileURLWithPath:"promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png")
let source = CGImageSourceCreateWithURL(url as CFURL,nil)!
let shiba = CGImageSourceCreateImageAtIndex(source,0,nil)!
var reviewed = 0
for breed in PochiBreed.allCases {
    let base = PochiBreedSprites.atlas(for:breed) ?? shiba
    let atlas = PochiMotionSprites.atlas(for:breed,base:base)!
    check(atlas.width == 128 && atlas.height == 256,"All breeds must keep the 32-frame atlas contract")
    let rgba = Array(atlas.dataProvider!.data! as Data)
    for index in [10,11] {
        check(PochiSpriteGeometry.tailRoot(breed,frame:index) == PochiSpriteGeometry.tailRoot(breed,frame:3),"Tail wag must keep the standing attachment fixed")
    }
    for (awake,blink) in [(3,8),(12,13),(7,26)] {
        let a = PochiSpriteGeometry.face(breed,frame:awake)!
        let b = PochiSpriteGeometry.face(breed,frame:blink)!
        check(a.origin == b.origin && a.eyePoints == b.eyePoints,"Blinking must never move the face or eyes")
    }
    // Turning toward the viewer must not swap to a different eye design.
    func eyePixels(frame: Int, eye: CGPoint) -> [[UInt8]] {
        let face = PochiSpriteGeometry.face(breed, frame: frame)!
        let span = breed == .shiba ? 2 : 4
        return (0..<span).flatMap { y in (0..<span).map { x in
            let point = face.point(x: Int(eye.x) + x, y: Int(eye.y) + y)
            let offset = (frame / 4 * 32 + Int(point.y)) * atlas.bytesPerRow
                + (frame % 4 * 32 + Int(point.x)) * 4
            let pixel = Array(rgba[offset..<offset+4])
            // Ignore surrounding coat/muzzle pixels at the rounded corners.
            // The ink silhouette and catchlight themselves must match exactly.
            return pixel == [66,48,40,255] || (breed != .shiba && x == 1 && y == 1) ? pixel : []
        } }
    }
    let profile = PochiSpriteGeometry.face(breed, frame: 3)!
    let profileEye = eyePixels(frame: 3, eye: profile.eyes[0])
    for pose in [12,14,29] {
        for eye in PochiSpriteGeometry.face(breed, frame: pose)!.eyes {
            check(eyePixels(frame: pose, eye: eye) == profileEye,
                  "\(breed): looking and tilting must use the same eye pixels as the profile")
        }
    }
    for index in 0..<32 {
        let prefix = "\(breed.rawValue) frame \(index)"
        func color(_ p: CGPoint) -> [UInt8] {
            let x = Int(p.x),y = Int(p.y)
            check((0..<32).contains(x) && (0..<32).contains(y),"\(prefix): landmark must be inside its frame")
            let i=(index/4*32+y)*atlas.bytesPerRow+(index%4*32+x)*4
            return Array(rgba[i..<i+4])
        }
        func isInk(_ p: CGPoint) -> Bool { color(p) == [66,48,40,255] }
        var cells = Set<Int>()
        for y in 0..<32 { for x in 0..<32 {
            let pixel = color(CGPoint(x:x,y:y))
            check(pixel[3] == 0 || pixel[3] == 255,"\(prefix): pixel edges must not have partial alpha")
            if pixel[3] > 0 { cells.insert(y*32+x) }
        } }
        check(cells.count > 150,"\(prefix): body must not disappear")
        var components = 0
        while let first = cells.first {
            components += 1
            var stack = [first]; cells.remove(first)
            while let p = stack.popLast() {
                let x=p%32,y=p/32
                for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                    let xx=x+dx,yy=y+dy
                    if (0..<32).contains(xx),(0..<32).contains(yy),cells.remove(yy*32+xx) != nil { stack.append(yy*32+xx) }
                } }
            }
        }
        check(components == 1,"\(prefix): detached tail, paw or stray pixel (\(components) islands)")
        if let root = PochiSpriteGeometry.tailRoot(breed,frame:index) {
            check(color(root)[3] == 255,"\(prefix): tail attachment must be part of the body")
        }
        if let face = PochiSpriteGeometry.face(breed,frame:index) {
            check(face.eyes.count == ([12,13,14,29].contains(index) ? 2 : 1),"\(prefix): ordinary poses must face sideways; only looking/tilting faces the user")
            let closed = [6,8,13,17,18,19,26,27,30].contains(index)
            var expectedInk = Set<Int>()
            let roundProfile = breed != .shiba
            for eye in face.eyes {
                if face.eyes.count == 2 {
                    // A tilted eye must retain its full footprint, not just hit a
                    // correspondingly distorted anchor in the same transform.
                    let anchor = face.point(x: Int(eye.x), y: Int(eye.y))
                    for dy in 0..<face.eyeWidth { for dx in 0..<face.eyeWidth {
                        let point = face.point(x: Int(eye.x)+dx, y: Int(eye.y)+dy)
                        check(point == CGPoint(x: anchor.x+CGFloat(dx), y: anchor.y+CGFloat(dy)),
                            "\(prefix): tilt must preserve the square eye footprint")
                    } }
                }
                let pixels: [(Int,Int)]
                if roundProfile {
                    pixels = closed ? [(0,1),(1,1),(2,1)] : [(1,0),(2,0),(0,1),(2,1),(3,1),(0,2),(1,2),(2,2),(3,2),(1,3),(2,3)]
                } else if closed { pixels = [(0,1),(1,1)] }
                else {
                    pixels = [(0,0),(1,0),(0,1),(1,1)]
                }
                for (dx,dy) in pixels {
                    let point=face.point(x:Int(eye.x)+dx,y:Int(eye.y)+dy)
                    expectedInk.insert(key(point))
                    check(isInk(point),"\(prefix): eye/eyelid left its face anchor")
                }
            }
            var actualInk = Set<Int>()
            let xs = breed == .shiba ? (face.eyes.count == 2 ? 3...12 : 3...10) : face.eyes.count == 1 ? 3...9 : 5...15
            let eyeRows = breed == .shiba && face.eyes.count == 2 ? 6...8 : 6...9
            for y in eyeRows { for x in xs {
                let point = face.point(x:x,y:y)
                if isInk(point) { actualInk.insert(key(point)) }
            } }
            check(actualInk == expectedInk,"\(prefix): extra/widened eye or leftover blink pixels")
            if face.eyes.count == 2 {
                let expected = breed == .shiba ? 6 : 7
                check(Int(face.eyes[1].x-face.eyes[0].x) == expected,"\(prefix): gaze must not change eye spacing")
            }
            let nose = breed == .shiba ? CGPoint(x:face.eyes.count == 2 ? 7 : 0,y:9) : CGPoint(x:face.eyes.count == 1 ? 2 : 10,y:10)
            check(isInk(face.point(x:Int(nose.x),y:Int(nose.y))),"\(prefix): nose must follow the head transform")
        }
        reviewed += 1
    }
}
print("PASS: \(reviewed) frames; connected tails/paws, stable eyes/blinks/gaze, shared head transforms, nose anchors, opaque pixel edges, atlas dimensions")
