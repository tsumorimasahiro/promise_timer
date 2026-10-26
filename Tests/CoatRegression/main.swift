import Foundation
import CoreGraphics
import ImageIO

func check(_ ok: Bool, _ message: String) { if !ok { fatalError(message) } }
let source = CGImageSourceCreateWithURL(URL(fileURLWithPath:"promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL,nil)!
let baseShiba = CGImageSourceCreateImageAtIndex(source,0,nil)!
var variants = 0
for breed in PochiBreed.allCases {
    let atlas = PochiMotionSprites.atlas(for:breed,base:PochiBreedSprites.atlas(for:breed) ?? baseShiba)!
    let original = Array(atlas.dataProvider!.data! as Data)
    var results = Set<Data>()
    for coat in PochiCoat.allCases {
        let colored = coat.applying(to:atlas,breed:breed)
        check(colored.width == 128 && colored.height == 256,"The complete 32-frame contract must survive coat selection")
        let bytes = Array(colored.dataProvider!.data! as Data)
        check(bytes.count == original.count,"Coats cannot change raster size")
        for y in 0..<colored.height { for x in 0..<colored.width {
            let i = y*colored.bytesPerRow+x*4
            check(bytes[i+3] == original[i+3],"Every pose must keep its original silhouette; no detached eyes/tails")
            let old = Array(original[i..<i+4])
            if old == [66,48,40,255] || old == [221,145,131,255] || old == [251,244,220,255] {
                check(Array(bytes[i..<i+4]) == old,"Eyes, mouth, outline, glints and cream markings must not be tinted")
            }
        } }
        results.insert(Data(bytes)); variants += 1
    }
    check(results.count == 3,"Each breed needs three genuinely different pixel palettes")
}
let suite = "PochiCoatRegression.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName:suite)!
defer { defaults.removePersistentDomain(forName:suite) }
check(PochiCoat.storageKey(for:.shiba) == "pochiCoat","Legacy coat storage key must remain intact")
for breed in PochiBreed.allCases { check(PochiCoat.selected(for:breed,defaults:defaults) == .kinako,"Missing settings must have a valid default") }
defaults.set("milk",forKey:"pochiCoat")
defaults.set("mintGreen",forKey:"pochiCollarTint")
defaults.set("moon.fill",forKey:"pochiCharm")
defaults.set("black",forKey:PochiCoat.storageKey(for:.dalmatian))
defaults.set("milk",forKey:PochiCoat.storageKey(for:.pomeranian))
check(PochiCoat.selected(for:.shiba,defaults:defaults) == .milk,"Existing white Shiba owners must keep white fur")
check(PochiCoat.selected(for:.dalmatian,defaults:defaults) == .black,"Dalmatian remembers its own color")
check(PochiCoat.selected(for:.pomeranian,defaults:defaults) == .milk,"Pomeranian remembers its own color")
let reopened = UserDefaults(suiteName:suite)!
check(PochiCoat.selected(for:.dalmatian,defaults:reopened) == .black,"Coat preference must survive reopening storage")
defaults.set("unknown",forKey:PochiCoat.storageKey(for:.dalmatian))
check(PochiCoat.selected(for:.dalmatian,defaults:defaults) == .kinako,"Unknown palette must safely fall back")
check(defaults.string(forKey:"pochiCollarTint") == "mintGreen" && defaults.string(forKey:"pochiCharm") == "moon.fill","Legacy accessory data must be retained without rendering it")
print("PASS: \(variants) coats / 288 frames; palettes distinct, silhouette and face preserved, legacy settings, per-breed persistence, unknown-value fallback")
