import Foundation
import AppKit
import ImageIO
import CoreGraphics

// Asset composition only. This does not run SwiftUI or SpriteKit.
@main struct RenderWorldPreview {
    static func main() throws {
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Asia/Tokyo")!
        calendar.firstWeekday = 2
        func date(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from:DateComponents(year:2026,month:10,day:day,hour:hour))!
        }
        let presets = [
            HabitPreset(id:"reading",title:"読書",iconName:"book",tintName:.peach,weeklyTarget:7),
            HabitPreset(id:"clean",title:"掃除",iconName:"clean",tintName:.peach,weeklyTarget:7),
            HabitPreset(id:"study",title:"勉強",iconName:"study",tintName:.peach,weeklyTarget:7),
            HabitPreset(id:"exercise",title:"運動",iconName:"run",tintName:.peach,weeklyTarget:7)]
        let rules = PochiWorldRule.synchronize([:],presets:presets,now:date(18),calendar:calendar)
        let allLogs = presets.map { HabitLog(presetID:$0.id,title:$0.title,completedAt:date(22)) }
        let scenes: [(String,[HabitLog],Date)] = [
            ("3 days without records",[],date(22)),
            ("Reading recorded",[allLogs[0]],date(22)),
            ("Reading + cleaning",[allLogs[0],allLogs[1]],date(22)),
            ("02:00 / sleeping",allLogs,date(23,2))]
        let source = CGImageSourceCreateWithURL(URL(fileURLWithPath:"promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL,nil)!
        let base = CGImageSourceCreateImageAtIndex(source,0,nil)!
        let atlas = PochiMotionSprites.atlas(for:.shiba,base:base)!
        let image = NSImage(size:NSSize(width:1024,height:368))
        image.lockFocus()
        NSColor(calibratedRed:0.97,green:0.95,blue:0.88,alpha:1).setFill()
        NSRect(x:0,y:0,width:1024,height:368).fill()
        let context = NSGraphicsContext.current!.cgContext
        context.interpolationQuality = .none
        for (i,scene) in scenes.enumerated() {
            let state = PochiWorldState.evaluate(presets:presets,logs:scene.1,rules:rules,now:scene.2,calendar:calendar)
            let night = state.phase == .deepNight
            context.saveGState()
            context.translateBy(x:CGFloat(i*256+128),y:176)
            context.setFillColor(CGColor(red:night ? 0.50 : 0.88,green:night ? 0.56 : 0.86,blue:night ? 0.62 : 0.77,alpha:1))
            context.fill(CGRect(x:-120,y:-160,width:240,height:320))
            context.setFillColor(CGColor(red:night ? 0.42 : 0.70,green:night ? 0.51 : 0.77,blue:night ? 0.53 : 0.64,alpha:1))
            context.fill(CGRect(x:-120,y:-160,width:240,height:212))
            context.setFillColor(CGColor(red:0.50,green:0.59,blue:0.44,alpha:1))
            context.fill(CGRect(x:-120,y:50.5,width:240,height:3))
            func prop(_ kind: PochiWorldProp,_ x: CGFloat,_ y: CGFloat,_ tidy: Bool = true) {
                context.draw(PochiWorldArtwork.image(kind,tidy:tidy)!,in:CGRect(x:x-32,y:y-24,width:64,height:48))
            }
            prop(.shelf,-76,76,state.clutter[.reading,default:0] == 0)
            prop(.desk,76,76,state.clutter[.studying,default:0] == 0)
            prop(.ball,80,-112)
            let positions: [(CGFloat,CGFloat)] = [(-80,-92),(78,-84),(-48,-122)]
            for object in state.clutterObjects {
                let kind: PochiWorldProp = object.theme == .reading ? .book : object.theme == .studying ? .paper : .litter
                prop(kind,positions[object.slot].0,positions[object.slot].1)
            }
            let index = night ? 6 : 3
            let dog = atlas.cropping(to:CGRect(x:index%4*32,y:index/4*32,width:32,height:32))!
            context.draw(dog,in:CGRect(x:-64,y:-76,width:128,height:128))
            context.restoreGState()
            (scene.0 as NSString).draw(at:NSPoint(x:i*256+12,y:344),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.darkGray])
        }
        image.unlockFocus()
        try NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Design/WorldPreview/habit-world.png"))
    }
}
