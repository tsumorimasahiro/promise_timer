import Foundation
import CoreGraphics
import ImageIO

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
let day = ISO8601DateFormatter().date(from: "2026-09-01T10:00:00Z")!
let now = day.addingTimeInterval(90 * 86400)
func record(_ index: Int, id: String? = nil, preset: String = "strength", title: String = "筋トレ") -> HabitLog {
    HabitLog(id: id ?? "strength-\(index)", presetID: preset, title: title, completedAt: day.addingTimeInterval(Double(index)*86400))
}
var progress = PochiStrengthProgress()
for index in 0..<30 {
    progress.include(logs: [record(index)], now: now, calendar: calendar)
    let expected = index+1 >= 30 ? 4 : index+1 >= 14 ? 3 : index+1 >= 7 ? 2 : index+1 >= 3 ? 1 : 0
    require(progress.dayCount == index+1 && progress.stage.rawValue == expected, "Growth threshold \(index+1)")
}
progress.include(logs: [record(29, id: "second-same-day", preset: "squats", title: "スクワット")], now: now, calendar: calendar)
require(progress.dayCount == 30, "Different exercises on the same day credit once")
progress.include(logs: [], now: now.addingTimeInterval(365*86400), calendar: calendar)
require(progress.dayCount == 30, "Rest and deletion never remove earned growth")
var shifted = calendar; shifted.timeZone = TimeZone(identifier: "America/Los_Angeles")!
progress.include(logs: (0..<30).map { record($0) }, now: now, calendar: shifted)
require(progress.dayCount == 30, "Revisiting old logs after timezone change cannot award days again")
let recovered = try JSONDecoder().decode(PochiStrengthProgress.self, from: JSONEncoder().encode(progress))
require(recovered == progress, "Growth survives persistence")
var isolated = PochiStrengthProgress()
isolated.include(logs: [record(0,preset:"walk",title:"散歩"), record(1,preset:"exercise",title:"ストレッチ"), record(2,preset:"run",title:"Running"), record(3,preset:"reading",title:"読書"),record(100)], now: now, calendar: calendar)
require(isolated.dayCount == 0, "Walking, running, reading, stretching and future records do not build strength")
for (index,title) in ["筋トレ", "スクワット", "腕立て伏せ", "ダンベル", "Strength training", "Squats", "근력 운동", "力量训练", "力量訓練"].enumerated() {
    isolated.include(logs:[record(index,preset:"custom-\(index)",title:title)], now:now, calendar:calendar)
}
require(isolated.dayCount == 9, "Custom multilingual strength histories migrate")
require(PochiMuscleStage.visible(selection: 4, earned: .toned) == .toned, "Locked appearances cannot be selected")
require(PochiMuscleStage.visible(selection: 0, earned: .champion) == .puppy, "Original appearance stays selectable")
require(PochiMuscleStage.visible(selection: -1, earned: .strong) == .strong, "Automatic appearance follows progress")
require(!PochiTogetherRoutine.moves(for: .strength).contains(.dumbbells), "Beginner actions")
require(PochiTogetherRoutine.moves(for: .strength,muscleLevel:1).contains(.dumbbells), "Dumbbell unlock")
require(PochiTogetherRoutine.moves(for: .strength,muscleLevel:2).contains(.proudPose), "Canine proud pose unlock")
require(PochiTogetherRoutine.moves(for: .strength,muscleLevel:3).contains(.proudWalk), "Proud walk unlock")
let source = CGImageSourceCreateWithURL(URL(fileURLWithPath:"promise_timer/Assets.xcassets/pochiPixelAtlas.imageset/pochi-pixel-atlas.png") as CFURL,nil)!
let shiba = CGImageSourceCreateImageAtIndex(source,0,nil)!
func rgba(_ image: CGImage, _ pose: Int, _ x: Int, _ y: Int) -> [UInt8] {
    let data = Array(image.dataProvider!.data! as Data)
    let offset = (pose/4*32+y)*image.bytesPerRow+(pose%4*32+x)*4
    return Array(data[offset..<offset+4])
}
func frame(_ image: CGImage, _ pose: Int) -> [[UInt8]] {
    let data = Array(image.dataProvider!.data! as Data)
    return (0..<1024).map { i in
        let offset = (pose/4*32+i/32)*image.bytesPerRow+(pose%4*32+i%32)*4
        return Array(data[offset..<offset+4])
    }
}
for breed in PochiBreed.allCases {
    let base = PochiBreedSprites.atlas(for: breed) ?? shiba
    let motion = PochiMotionSprites.atlas(for: breed, base: base)!
    let original = PochiMuscleSprites.atlas(base: motion, breed: breed, stage: .puppy)
    require(original.width == 128 && original.height == PochiMuscleSprites.rows * 32, "Expanded training atlas")
    let oldBytes = Array(motion.dataProvider!.data! as Data)
    let newBytes = Array(original.dataProvider!.data! as Data)
    require(Array(newBytes.prefix(oldBytes.count)) == oldBytes, "Original 32 poses remain unchanged at stage zero")
    var previous = original
    for stage in PochiMuscleStage.allCases {
        let atlas = PochiMuscleSprites.atlas(base: motion, breed: breed, stage: stage)
        if stage != .puppy {
            require(atlas.dataProvider!.data! as Data != previous.dataProvider!.data! as Data, "Every growth stage is visually distinct: \(breed) \(stage)")
        }
        for pose in 0..<32 {
            let basePixels = frame(motion, pose), grownPixels = frame(atlas, pose)
            let baseArea = basePixels.filter { $0[3] > 0 }.count
            let grownArea = grownPixels.filter { $0[3] > 0 }.count
            require(Double(grownArea) <= Double(baseArea) * 1.18, "Growth stays within the dog's proportions")
            require(Array(basePixels.suffix(7*32)) == Array(grownPixels.suffix(7*32)), "Growth never enlarges or detaches paws")
            if PochiSpriteGeometry.resting.contains(pose) || PochiSpriteGeometry.seated.contains(pose) {
                require(basePixels == grownPixels, "Resting and seated body stays natural")
            }
            if let face = PochiSpriteGeometry.face(breed,frame:pose) {
                for eye in face.eyePoints {
                    for y in 0..<2 { for x in 0..<2 {
                        require(rgba(motion,pose,Int(eye.x)+x,Int(eye.y)+y) == rgba(atlas,pose,Int(eye.x)+x,Int(eye.y)+y), "Eyes preserved for \(breed) pose \(pose)")
                    } }
                }
            }
        }
        let standing = frame(atlas, 3)
        let ground = (0..<32).last(where: { y in (0..<32).contains { standing[y*32+$0][3] > 0 } })!
        for pose in 32..<40 {
            let pixels = frame(atlas, pose)
            let occupied = (0..<1024).filter { pixels[$0][3] > 0 }
            let xs = occupied.map { $0%32 }, ys = occupied.map { $0/32 }
            require(xs.max()!-xs.min()! >= ys.max()!-ys.min()!, "Training keeps a horizontal canine silhouette")
            require(ys.max() == ground, "Paws remain on the floor throughout training")
            // Both front and rear supports are retained, even when lowering.
            require(occupied.contains { $0%32 < 18 && $0/32 >= 26 }, "Front paws stay grounded")
            require(occupied.contains { $0%32 >= 20 && $0/32 >= 26 }, "Rear paws stay grounded")
        }
        require(frame(atlas,32) != frame(atlas,33), "Push-up changes the front stance")
        require(frame(atlas,34) != standing, "Squat changes the hind-leg stance")
        require(frame(atlas,36) != frame(atlas,37), "Toy lifts with the muzzle")
        for pair in [(40,42), (43,44), (40,45), (46,47), (40,48), (48,41), (41,49), (49,42), (39,50), (39,51)] {
            require(frame(atlas,pair.0) != frame(atlas,pair.1), "Exercise phases are distinct for every breed and growth stage")
        }
        for pose in 40..<52 {
            let pixels = frame(atlas,pose)
            require(pixels.filter { $0[3] > 0 }.count > 120, "New exercise pose is fully drawn")
            let occupied = Set((0..<1024).filter { pixels[$0][3] > 0 })
            var visited: Set<Int> = [occupied.first!]
            var pending = Array(visited)
            while let pixel = pending.popLast() {
                for dy in -1...1 { for dx in -1...1 {
                    let x = pixel%32+dx, y = pixel/32+dy
                    guard (0..<32).contains(x), (0..<32).contains(y) else { continue }
                    let neighbor = y*32+x
                    if occupied.contains(neighbor), visited.insert(neighbor).inserted { pending.append(neighbor) }
                } }
            }
            require(visited == occupied, "No detached paws or head in \(breed) pose \(pose)")
            require(pixels.allSatisfy { $0[3] == 0 || $0[3] == 255 }, "Exercise pixels remain crisp")
        }
        for coat in PochiCoat.allCases {
            let colored = coat.applying(to: atlas, breed: breed)
            require(colored.width == 128 && colored.height == PochiMuscleSprites.rows * 32, "All coats preserve geometry")
        }
        previous = atlas
    }
}
print("PASS: strength-only counting, daily deduplication, 3/7/14/30-day milestones, permanent progress, timezone replay, legacy migration, appearance selection, action unlocks, all breeds/coats and preserved eyes")
