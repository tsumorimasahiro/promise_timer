import Foundation
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let choices = PochiWorkoutCatalog.presets
require(choices.count == 11 && !choices.contains { $0.id == "strength" }, "Only strength choices in onboarding and templates")
require(choices.allSatisfy(PochiWorkoutCatalog.isWorkout), "Every offered exercise builds strength")
require(PochiWorkoutCatalog.initialSelection([]) == choices, "Skipping choices has a usable strength default")
require(PochiWorkoutCatalog.initialSelection([choices[1]]) == [choices[1]], "User selection is retained")
let customSquat = HabitPreset(id: "squats", title: "ゆっくりスクワット", iconName: "squat", tintName: .mintGreen,
    weeklyTarget: 2, workoutPlan: WorkoutPlan(mode: .repetitions, target: 17))
let personalMenu = [customSquat] + choices.dropFirst()
let firstWorkout = PochiWorkoutCatalog.introductoryWorkout(in: personalMenu)
require(firstWorkout.id == customSquat.id && firstWorkout.title == customSquat.title,
    "The introduction records against the actual squat exercise")
require(firstWorkout.workoutPlan.mode == .repetitions && firstWorkout.workoutPlan.target == 5,
    "The introduction starts a short real workout")
require(personalMenu.first?.workoutPlan.target == 17 && PochiWorkoutCatalog.presets[0].workoutPlan.target == 10,
    "The short introduction never replaces custom or default saved targets")
let restoredFirstWorkout = try JSONDecoder().decode(HabitPreset.self, from: JSONEncoder().encode(firstWorkout))
require(restoredFirstWorkout == firstWorkout, "The introduction can resume with its own session snapshot")
require(PochiWorkoutCatalog.introductoryWorkout(in: []).id == "squats", "The first workout has a valid fallback")
let custom = HabitPreset(id: PochiWorkoutCatalog.customID(), title: "Aメニュー", iconName: "heart.fill", tintName: .peach)
let decoded = try JSONDecoder().decode(HabitPreset.self, from: JSONEncoder().encode(custom))
require(PochiWorkoutCatalog.isWorkout(decoded), "Custom training survives title/icon choices and persistence")
var progress = PochiStrengthProgress()
let now = Date()
progress.include(logs: [HabitLog(presetID: custom.id, title: custom.title, completedAt: now)], now: now, calendar: .current)
require(progress.dayCount == 1, "Saved custom training logs credit growth even without the preset/icon")
let water = HabitPreset(id: "water", title: "水を飲む", iconName: "drop.fill", tintName: .candyBlue)
let reading = HabitPreset(id: "reading", title: "本を10分読む", iconName: "book", tintName: .lavender)
let legacy = [water, reading]
let saved = try JSONEncoder().encode(legacy + [custom])
let restored = try JSONDecoder().decode([HabitPreset].self, from: saved)
require(restored.filter { !PochiWorkoutCatalog.isWorkout($0) } == legacy, "Legacy habits remain intact and separate")
require(restored.filter(PochiWorkoutCatalog.isWorkout) == [custom], "Training selection excludes legacy habits")
progress.include(logs: legacy.map { HabitLog(presetID: $0.id, title: $0.title, completedAt: now) }, now: now, calendar: .current)
require(progress.dayCount == 1, "Legacy records do not become strength records")
print("PASS: strength catalog, default selection, selected exercises, custom exercise persistence/growth and legacy preservation")

require(Set(choices.map(\.iconName)).count == choices.count, "All built-in icons are distinct")
require(choices.first { $0.id == "strength.crunches" }!.workoutPlan.mode == .repetitions, "Crunches use repetitions")
require(choices.filter { $0.workoutPlan.mode == .timed }.count == 4, "Four timed core exercises")
