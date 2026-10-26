import Foundation
import AppKit
import ImageIO
import CoreGraphics

@main struct MotionReview {
    static func main() throws {
        let directory = URL(fileURLWithPath:"Design/MotionReview",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let src = CGImageSourceCreateWithURL(URL(fileURLWithPath:"promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL,nil)!
        let names = ["walk 1","walk 2","walk 3","stand","eat up","eat down","sleep","sit","blink","ear","tail up","tail down","look","look blink","tilt","crouch","lie","yawn small","yawn wide","breathe","stretch start","stretch full","lower head","lick","jump ready","landing","sit blink","drowsy","ear back","other tilt","lie blink","wake"]
        let sequence = [3,3,8,3,9,3,28,3,10,11,10,11,3,12,13,12,14,12,29,12,3,7,26,7,17,18,17,7,27,15,16,30,6,6,19,6,19,6,31,15,3,20,21,21,20,3,4,22,5,23,5,22,4,3,0,1,2,1,0,3]
        for breed in PochiBreed.allCases {
            let base = PochiBreedSprites.atlas(for:breed) ?? CGImageSourceCreateImageAtIndex(src,0,nil)!
            let atlas = PochiMotionSprites.atlas(for:breed,base:base)!
            let raw = CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(breed.rawValue)-atlas.png") as CFURL,"public.png" as CFString,1,nil)!
            CGImageDestinationAddImage(raw,atlas,nil);CGImageDestinationFinalize(raw)
            func frame(_ index: Int,_ size: Int) -> NSImage {
                let result = NSImage(size:NSSize(width:size,height:size))
                result.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .none
                NSColor(calibratedRed:0.97,green:0.95,blue:0.88,alpha:1).setFill()
                NSRect(x:0,y:0,width:size,height:size).fill()
                let crop = atlas.cropping(to:CGRect(x:index%4*32,y:index/4*32,width:32,height:32))!
                NSImage(cgImage:crop,size:NSSize(width:32,height:32)).draw(in:NSRect(x:0,y:0,width:size,height:size))
                result.unlockFocus()
                return result
            }
            let sheet = NSImage(size:NSSize(width:512,height:1184))
            sheet.lockFocus()
            NSColor(calibratedRed:0.97,green:0.95,blue:0.88,alpha:1).setFill()
            NSRect(x:0,y:0,width:512,height:1184).fill()
            NSGraphicsContext.current?.imageInterpolation = .none
            for index in 0..<32 {
                let x = index%4*128,y = (7-index/4)*148
                frame(index,128).draw(in:NSRect(x:x,y:y+20,width:128,height:128))
                ("\(index) \(names[index])" as NSString).draw(at:NSPoint(x:x+6,y:y+4),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:10,weight:.medium),.foregroundColor:NSColor.darkGray])
            }
            sheet.unlockFocus()
            try NSBitmapImageRep(data:sheet.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent("\(breed.rawValue)-frames.png"))
            let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(breed.rawValue)-motion.gif") as CFURL,"com.compuserve.gif" as CFString,sequence.count,nil)!
            CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for index in sequence {
                let rep = NSBitmapImageRep(data:frame(index,256).tiffRepresentation!)!
                CGImageDestinationAddImage(gif,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:index == 6 ? 0.8 : 0.22]] as CFDictionary)
            }
            CGImageDestinationFinalize(gif)
        }
    }
}
