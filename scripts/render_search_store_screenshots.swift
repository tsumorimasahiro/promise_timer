import Foundation
import CoreGraphics
import CoreText
import ImageIO

// Marketing composition only: real screen regions and existing app artwork.
// All rectangles below use top-left coordinates. No UI is repainted.
@main struct SearchStoreScreenshots {
    static let root = "Design/AppStore/2026-11-18"
    static let W = 1320, H = 2868
    static func color(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat) -> CGColor { CGColor(red:r,green:g,blue:b,alpha:1) }
    // Approved sky study: background #E8F3F7, ink #34454C, accent #A94E24.
    static let background = color(232/255,243/255,247/255)
    static let ink = color(52/255,69/255,76/255)
    static let accent = color(169/255,78/255,36/255)
    static func read(_ p: String) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:p) as CFURL,nil)!,0,nil)! }
    static func write(_ im: CGImage,_ p: String) { let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:p) as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d)) }
    static func canvas(_ w:Int=W,_ h:Int=H)->CGContext { let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!;c.setFillColor(background);c.fill(CGRect(x:0,y:0,width:w,height:h));return c }
    static func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat)->CGRect {CGRect(x:x,y:CGFloat(H)-y-h,width:w,height:h)}
    static func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ c:CGContext,_ col:CGColor=ink) {
        let font=CTFontCreateWithName("HiraginoSans-W8" as CFString,size,nil)
        let line=CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):col]))
        precondition(CTLineGetTypographicBounds(line,nil,nil,nil)<=CGFloat(W)-x-60,"Text overflow: \(s)")
        c.textPosition=CGPoint(x:x,y:CGFloat(H)-y-size);CTLineDraw(line,c)
    }
    static func image(_ im:CGImage,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ c:CGContext,rounded:Bool=true,pixel:Bool=false) {
        let h=w*CGFloat(im.height)/CGFloat(im.width), r=rect(x,y,w,h)
        c.saveGState();if rounded { c.addPath(CGPath(roundedRect:r,cornerWidth:32,cornerHeight:32,transform:nil));c.clip() }
        c.interpolationQuality=pixel ? .none : .high;c.draw(im,in:r);c.restoreGState()
    }
    static func crop(_ p:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat)->CGImage {let im=read(p);return im.cropping(to:CGRect(x:x*CGFloat(im.width),y:y*CGFloat(im.height),width:w*CGFloat(im.width),height:h*CGFloat(im.height)))!}
    static func header(_ a:String,_ b:String,_ sub:String)->CGContext {let c=canvas();text("ぽちと筋トレ",80,78,36,c);text(a,80,215,144,c);text(b,80,395,144,c,accent);text(sub,80,640,42,c);return c}
    static func footer(_ s:String,_ c:CGContext) {text(s,80,2675,40,c)}
    static func main() {
        let old="Design/AppStore/2026-11-11/raw/"
        var outputs:[String]=[]
        func save(_ c:CGContext,_ name:String){let p=root+"/ja/"+name+".png";write(c.makeImage()!,p);outputs.append(p)}
        let a=header("わんこと一緒に","おうちで筋トレ","あなたが動くとき、ぽちも一緒に。")
        image(crop(old+"ja-hero-pushup-low-candidate.png",0.25,0.17,0.5,0.145),80,850,1160,a,pixel:true)
        text("腕立て伏せも、一緒に。",80,1650,48,a)
        image(crop(old+"ja-hero.png",0.045,0.335,0.91,0.2),80,1770,1160,a)
        footer("ドット絵のわんこと、今日のひと運動。",a);save(a,"01-companion")

        let b=header("まずは","スクワット5回","名前やメニューは、あとからで大丈夫。")
        text("アプリを開いて、そのままスタート。",80,870,48,b)
        image(crop("Design/GrowthReview/01-onboarding-ja.png",0.045,0.846,0.91,0.061),80,1010,1160,b)
        text("5回から、ぽちと一緒に。",80,1390,48,b)
        image(crop("Design/GrowthReview/02-first-workout-ja.png",0.045,0.335,0.91,0.2),80,1530,1160,b)
        footer("終わったら、ボタンひとつで記録。",b);save(b,"02-five-reps")

        let c=header("できた！を残す","筋トレカレンダー","少しずつ続けた日が、ひと目でわかる。")
        image(crop("Design/AppStore/2026-11-17/raw/ja-calendar.png",0.03,0.12,0.94,0.54),80,860,1160,c)
        text("ぽちの写真も、思い出に。",80,2430,40,c)
        image(crop(old+"ja-share.png",0.105,0.435,0.79,0.167),870,2380,370,c)
        footer("サンプルの筋トレ記録を表示しています。",c);save(c,"03-calendar")

        let d=header("名前も毛色も","あなたの相棒に","赤柴・白柴・黒柴から、好きな毛色を。")
        for (i,coat) in ["kinako","milk","black"].enumerated(){image(read("promise_timer/Assets.xcassets/pochi-coat-shiba-\(coat).imageset/dog.png"),CGFloat(85+i*400),920,350,d,rounded:false,pixel:true)}
        text("赤柴",190,1320,44,d);text("白柴",590,1320,44,d);text("黒柴",990,1320,44,d)
        image(crop(old+"ja-profile.png",0.03,0.685,0.94,0.25),80,1570,1160,d)
        footer("名前と柴犬の毛色は、無料で変更できます。",d);save(d,"04-your-pochi")

        let e=header("回数も時間も","自分のペースで","種目と回数・時間を、自分に合わせて。")
        text("回数で取り組む",80,850,48,e)
        image(crop("Design/GrowthReview/02-first-workout-ja.png",0.045,0.335,0.91,0.2),80,960,1160,e)
        text("タイマーで取り組む",80,1740,48,e)
        image(crop(old+"ja-timer.png",0.045,0.335,0.91,0.2),80,1850,1160,e)
        footer("スクワットも、プランクも。",e);save(e,"05-your-pace")
        for (name,w) in [("contact-ja",330),("search-preview",120)] {let h=Int(Double(w)*Double(H)/Double(W));let sheet=canvas(w*5,h);for(i,p) in outputs.enumerated(){sheet.draw(read(p),in:CGRect(x:i*w,y:0,width:w,height:h))};write(sheet.makeImage()!,root+"/\(name).png")}
        print("Rendered \(outputs.count) Japanese screenshots, 1320 × 2868")
    }
}
