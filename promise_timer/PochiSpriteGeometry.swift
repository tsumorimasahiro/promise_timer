import Foundation
import CoreGraphics

/// Every feature is painted into one local head layer and transformed once.
/// Blink, gaze and tilt must never use independent screen-space coordinates.
struct PochiFaceLayout {
    let origin: CGPoint
    let eyes: [CGPoint]
    let tilt: Int
    let pivot: Int
    let slope: Double
    var eyeWidth: Int = 2

    func point(x: Int, y: Int) -> CGPoint {
        // Tiny faces cannot be sheared pixel by pixel: a small eye becomes a
        // diagonal fragment. Move each eye's columns as one block, while
        // limiting the outline to a gentle one-pixel lean. Using the same
        // offset for a whole column also prevents pixels overwriting the eye.
        var sampleX = x
        if eyes.count == 2 {
            if let eye = eyes.first(where: {
                (Int($0.x)...Int($0.x)+eyeWidth-1).contains(x)
            }) { sampleX = Int(eye.x) }
        }
        let offset = max(-1, min(1, Int((Double(sampleX-pivot) / slope * Double(tilt)).rounded())))
        return CGPoint(x:origin.x+CGFloat(x), y:origin.y+CGFloat(y+offset))
    }
    var eyePoints: [CGPoint] { eyes.map { point(x:Int($0.x),y:Int($0.y)) } }
}

enum PochiSpriteGeometry {
    static let resting: Set<Int> = [6,16,19,30]
    static let seated: Set<Int> = [7,17,18,26,27]
    static func headDrop(_ index: Int) -> Int {
        [4:2,5:4,22:3,23:4,15:2,24:2,25:2,27:1,20:2,21:4,31:2][index,default:0]
    }
    static func face(_ breed: PochiBreed, frame index: Int) -> PochiFaceLayout? {
        if breed == .shiba && resting.contains(index) { return nil }
        let frontal = [12,13,14,29].contains(index)
        let tilt = index == 14 ? 1 : index == 29 ? -1 : 0
        let bow = [20,21].contains(index)
        if breed == .shiba {
            return PochiFaceLayout(origin:CGPoint(x:bow ? 1 : 2,y:6+headDrop(index)),
                eyes:frontal ? [CGPoint(x:4,y:7),CGPoint(x:10,y:7)] : [CGPoint(x:4,y:7)],
                tilt:tilt,pivot:frontal ? 7 : 6,slope:frontal ? 5 : 4)
        }
        return PochiFaceLayout(origin:CGPoint(x:bow ? 0 : 1,y:resting.contains(index) ? (breed == .pomeranian ? 12 : 14) : 7+headDrop(index)),
            eyes:frontal ? [CGPoint(x:5,y:6),CGPoint(x:12,y:6)] : [CGPoint(x:6,y:6)],tilt:tilt,pivot:10,slope:7,eyeWidth:4)
    }
    static func bodyY(_ index: Int) -> Int {
        (resting.contains(index) ? 21 : seated.contains(index) ? 17 : 16) - (index == 19 ? 1 : 0)
    }
    static func tailRoot(_ breed: PochiBreed, frame index: Int) -> CGPoint? {
        if breed == .shiba {
            if resting.contains(index) { return nil } // Curled-up source has no separate tail layer.
            let crouched = [15,24,25,31].contains(index)
            return CGPoint(x:24,y:seated.contains(index) ? 21 : crouched ? 19 : 18)
        }
        return CGPoint(x:breed == .dalmatian ? 27 : 25,y:bodyY(index)+3)
    }
}
