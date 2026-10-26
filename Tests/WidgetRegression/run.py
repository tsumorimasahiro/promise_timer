"""Exercise actual widget snapshot logic with isolated defaults; no WidgetKit UI claim."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
widget = next(root.glob('Promise*Widget'))
source = (widget/'Promise_Timer_Widget.swift').read_text()
source = source.split('struct PochiWidgetProvider:')[0]
source = source.replace('import WidgetKit', 'import Foundation\nprotocol TimelineEntry {}').replace('import SwiftUI','').replace('import AppIntents','')
source = source.replace('"group.com.tsumori.promise_timer"', '"WidgetRegression." + UUID().uuidString')
source += '''
func date(_ hour: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: hour))!
}
assert(PochiWidgetEntry.make(at: date(0)).pose == 6)
assert(PochiWidgetEntry.make(at: date(23)).pose == 6)
assert(PochiWidgetEntry.make(at: date(21)).pose == 16)
assert(PochiWidgetEntry.make(at: date(12)).pose != 6)
widgetDefaults.set("dalmatian", forKey: "pochiBreed")
assert(PochiWidgetEntry.make(at: date(12)).breed == "shiba")
widgetDefaults.set(true, forKey: "isSubscribed")
for breed in ["shiba", "dalmatian", "pomeranian"] {
    widgetDefaults.set(breed, forKey: "pochiBreed")
    for coat in ["kinako", "milk", "black"] {
        widgetDefaults.set(coat, forKey: breed == "shiba" ? "pochiCoat" : "pochiCoat." + breed)
        let entry = PochiWidgetEntry.make(at: date(12))
        assert(entry.breed == breed && entry.coat == coat)
    }
}
widgetDefaults.set("unknown", forKey: "pochiBreed")
widgetDefaults.set("unknown", forKey: "pochiCoat")
assert(PochiWidgetEntry.make(at: date(12)).coat == "kinako")
widgetDefaults.set(14, forKey: "pochiWidgetPetPose")
widgetDefaults.set(date(12).timeIntervalSince1970, forKey: "pochiWidgetLastPet")
assert(PochiWidgetEntry.make(at: date(12)).pose == 14)
assert(PochiWidgetEntry.make(at: date(13)).pose != 14)
assert(PochiWidgetEntry.make(at: date(11)).pose != 14)
assert(PochiWidgetEntry.make(at: date(12), preview: true).pose == 16)
let custom = HabitPreset(id: "strength.custom.脚 / #?%", title: "脚の日", iconName: "squat", tintName: .peach, workoutPlan: WorkoutPlan(mode: .repetitions, target: 15))
let basic = PochiWorkoutCatalog.presets
let available = [custom] + basic
let choices = PochiWorkoutWidget.choices(in: available, recentIDs: [custom.id, "missing", "pushups", custom.id], activeID: "strength.plank")
assert(choices.map(\.id) == ["strength.plank", custom.id, "pushups"])
assert(choices[1].workoutPlan.target == 15)
for id in [custom.id, "squats", "strength.plank"] {
    assert(PochiWorkoutWidgetLink(url: PochiWorkoutWidgetLink.preset(id).url) == .preset(id))
}
assert(PochiWorkoutWidgetLink(url: PochiWorkoutWidgetLink.home.url) == .home)
for invalid in ["https://preset/squats", "promise-timer://preset/", "promise-timer://preset/a/b", "promise-timer://preset/squats?extra=1", "promise-timer://other"] {
    assert(PochiWorkoutWidgetLink(url: URL(string: invalid)!) == nil)
}
PochiWorkoutWidget.remember(custom.id, in: widgetDefaults)
PochiWorkoutWidget.remember("pushups", in: widgetDefaults)
PochiWorkoutWidget.remember(custom.id, in: widgetDefaults)
assert(widgetDefaults.stringArray(forKey: PochiWorkoutWidget.recentKey) == [custom.id, "pushups"])
widgetDefaults.set("[]", forKey: "habitPresetsStore")
assert(PochiWorkoutWidget.presets(from: widgetDefaults).isEmpty)
assert(PochiWidgetEntry.make(at: date(12)).workouts.isEmpty)
widgetDefaults.set(String(data: try! JSONEncoder().encode(available), encoding: .utf8), forKey: "habitPresetsStore")
assert(PochiWidgetEntry.make(at: date(12)).workouts.first?.id == custom.id)
let activePreset = HabitPreset(id: "removed", title: "継続中", iconName: "plank", tintName: .peach, workoutPlan: WorkoutPlan(mode: .timed, target: 45))
let active = PochiTogetherSession(preset: activePreset, now: date(12))
widgetDefaults.set(String(data: try! JSONEncoder().encode(active), encoding: .utf8), forKey: "pochiTogetherSession.v1")
let activeEntry = PochiWidgetEntry.make(at: date(12))
assert(activeEntry.workouts.first?.id == "removed" && activeEntry.workouts.first?.workoutPlan.target == 45)
assert(activeEntry.activePresetID == "removed")
assert(PochiWidgetEntry.make(at: date(12), preview: true).activePresetID == nil)
print("PASS: widget quick choices, custom targets, URL round trips, invalid routes, recent ordering, empty presets and preserved active session snapshot.")
print("PASS: day/night, 9 breed-coat combinations, purchase fallback, invalid values, reaction expiry and future clocks.")
'''
out=root/'.build/WidgetRegression';out.mkdir(exist_ok=True)
(out/'main.swift').write_text(source)
dependencies = ['HabitModels.swift', 'PochiWorldModels.swift', 'PochiPromiseReaction.swift', 'PochiStrengthProgress.swift', 'PochiTogetherSession.swift', 'PochiWorkoutCatalog.swift', 'PochiWorkoutWidget.swift']
subprocess.run(['xcrun','swiftc','-module-cache-path',str(root/'.build/ModelTestCache'),*[str(root/'promise_timer'/file) for file in dependencies],str(out/'main.swift'),'-o',str(out/'run')],check=True)
subprocess.run([str(out/'run')],check=True)
for breed in ['shiba','dalmatian','pomeranian']:
 for coat in ['kinako','milk','black']:
  for pose in [6,7,10,12,14,16]:
   assert (root/f'promise_timer/Assets.xcassets/pochi-widget-{breed}-{coat}-{pose}.imageset/dog.png').exists()
print('PASS: all 54 referenced sprite assets exist.')
