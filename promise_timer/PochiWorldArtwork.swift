import Foundation
import CoreGraphics

enum PochiWorldProp: CaseIterable {
    case shelf, desk, ball, book, paper, litter
}

/// Tiny original pixel props. Scene placement uses integer 4× enlargement,
/// matching the dog's pixel density; never filtered or rotated.
enum PochiWorldArtwork {
    static func image(_ prop: PochiWorldProp, tidy: Bool = true) -> CGImage? {
        let width = 16, height = 12
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: [UInt8]) {
            for yy in max(0,y)..<min(height,y+h) { for xx in max(0,x)..<min(width,x+w) {
                let offset = (yy*width+xx)*4
                for c in 0..<4 { rgba[offset+c] = color[c] }
            } }
        }
        let wood: [UInt8] = [147,119,87,255]
        let edge: [UInt8] = [105,88,68,255]
        let paper: [UInt8] = [244,232,200,255]
        let green: [UInt8] = [112,143,107,255]
        let orange: [UInt8] = [215,155,93,255]
        switch prop {
        case .shelf:
            rect(1,0,14,1,edge); rect(1,1,1,11,wood); rect(14,1,1,11,wood)
            rect(1,10,14,2,edge); rect(2,5,12,1,wood)
            rect(3,2,2,3,green); rect(6,1,2,4,orange)
            if tidy { rect(9,2,3,3,paper); rect(4,7,2,3,paper); rect(7,6,2,4,green); rect(10,7,2,3,orange) }
        case .desk:
            rect(0,5,16,2,edge); rect(1,7,2,5,wood); rect(13,7,2,5,wood)
            rect(4,1,7,4,paper); rect(5,2,4,1,green)
            if tidy { rect(11,4,3,1,green) } else { rect(10,1,4,1,orange); rect(11,2,3,1,orange) }
        case .ball:
            rect(6,4,4,1,edge); rect(5,5,6,1,edge); rect(4,6,8,4,edge)
            rect(5,10,6,1,edge); rect(6,11,4,1,edge)
            rect(6,5,4,1,orange); rect(5,6,6,4,orange); rect(6,10,4,1,orange)
            rect(7,5,1,6,paper); rect(5,7,6,1,paper)
        case .book:
            rect(3,7,10,4,edge); rect(4,7,8,3,green); rect(5,8,6,1,paper)
            rect(7,7,1,3,edge)
        case .paper:
            rect(4,5,7,6,edge); rect(5,5,6,5,paper)
            rect(6,6,4,1,wood); rect(6,8,3,1,wood)
        case .litter:
            rect(5,8,3,1,paper); rect(4,9,5,2,paper); rect(5,11,3,1,wood)
            rect(6,9,1,1,wood); rect(10,10,1,1,wood)
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
            provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
