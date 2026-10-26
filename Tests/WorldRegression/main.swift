import Foundation

func check(_ value: Bool, _ message: String) { if !value { fatalError(message) } }
var cal = Calendar(identifier:.gregorian)
cal.timeZone = TimeZone(identifier:"Asia/Tokyo")!
cal.firstWeekday = 2
func date(_ day: String, hour: Int = 12) -> Date {
    let bits = day.split(separator:"-").map { Int($0)! }
    return cal.date(from:DateComponents(year:bits[0],month:bits[1],day:bits[2],hour:hour))!
}
func preset(_ id: String, _ title: String = "読書", icon: String = "book", target: Int = 7, category: HabitCategory = .learning) -> HabitPreset {
    HabitPreset(id:id,title:title,iconName:icon,tintName:.peach,weeklyTarget:target,category:category)
}
func log(_ preset: HabitPreset, _ day: String, hour: Int = 12, id: String = UUID().uuidString) -> HabitLog {
    HabitLog(id:id,presetID:preset.id,title:preset.title,completedAt:date(day,hour:hour))
}
let reading = preset("reading")
let cleaning = preset("clean","掃除",icon:"clean",category:.home)
let started = date("2026-09-30")
func rules(_ presets: [HabitPreset]) -> [String:PochiWorldRule] {
    PochiWorldRule.synchronize([:],presets:presets,now:started,calendar:cal)
}
func state(_ presets: [HabitPreset], _ logs: [HabitLog] = [], at day: String = "2026-10-04", hour: Int = 12, saved: [String:PochiWorldRule]? = nil) -> PochiWorldState {
    PochiWorldState.evaluate(presets:presets,logs:logs,rules:saved ?? rules(presets),now:date(day,hour:hour),calendar:cal)
}
check(state([reading]).clutter[.reading] == 3,"Three closed daily opportunities leave at most three books")
check(state([reading],at:"2026-10-01",hour:23).clutter[.reading] == 0,"Today must never be overdue")
check(state([reading],at:"2026-10-02",hour:0).clutter[.reading] == 1,"Deadline closes at local midnight")
let achieved = log(reading,"2026-10-04")
check(state([reading],[achieved]).clutter[.reading] == 0,"A new reading completion clears every scattered book")
check(state([reading],[]).clutter[.reading] == 3,"Undo re-derives the previous world rather than keeping a side effect")
let combined = state([reading,cleaning])
check(combined.visibleClutter.count == 3 && combined.visibleClutter.contains(.reading) && combined.visibleClutter.contains(.cleaning),"Combined clutter is bounded and fairly shared")
let onlyReadingDone = state([reading,cleaning],[achieved])
check(onlyReadingDone.clutter[.reading] == 0 && onlyReadingDone.clutter[.cleaning] == 3,"A theme clears independently")
let removed = state([], [achieved], saved:rules([reading]))
check(removed.activeThemes.isEmpty && removed.visibleClutter.isEmpty,"Deleted promises leave no props or clutter")
let updatedRules = PochiWorldRule.synchronize(rules([reading,cleaning]),presets:[reading],now:date("2026-10-04"),calendar:cal)
check(updatedRules[cleaning.id] == nil,"Rule metadata is removed without touching logs")
let weekly = preset("reading",target:3)
let weeklyStart = date("2026-09-27")
let weeklyRules = PochiWorldRule.synchronize([:],presets:[weekly],now:weeklyStart,calendar:cal)
check(state([weekly],at:"2026-10-04",saved:weeklyRules).clutter[.reading] == 0,"A flexible week is not overdue on Sunday")
let partial = [log(weekly,"2026-09-30")]
check(state([weekly],partial,at:"2026-10-05",saved:weeklyRules).clutter[.reading] == 2,"Closed weekly target counts the true shortfall even after a midweek completion")
let completeWeek = [log(weekly,"2026-09-28"),log(weekly,"2026-09-30"),log(weekly,"2026-10-02")]
check(state([weekly],completeWeek,at:"2026-10-05",saved:weeklyRules).clutter[.reading] == 0,"A met weekly target produces no clutter")
check(state([weekly],partial+[log(weekly,"2026-10-05")],at:"2026-10-05",saved:weeklyRules).clutter[.reading] == 0,"A new completion tidies the previous weekly shortfall")
let justRegistered = PochiWorldRule.synchronize([:],presets:[reading],now:date("2026-10-04"),calendar:cal)
check(state([reading],at:"2026-10-04",saved:justRegistered).clutter[.reading] == 0,"Feature adoption never penalizes old absence")
let edit = PochiWorldRule.synchronize(rules([reading]),presets:[weekly],now:date("2026-10-04"),calendar:cal)
check(edit[reading.id]?.startedAt == date("2026-10-04"),"Changing frequency starts a fresh observation period")
var weekdayRules = rules([reading]); weekdayRules[reading.id]?.weekdays = [2,4]
check(state([reading],at:"2026-10-05",saved:weekdayRules).clutter[.reading] == 0,"Off weekdays have no missed deadline")
check(state([reading],at:"2026-10-06",saved:weekdayRules).clutter[.reading] == 1,"A scheduled Monday is due only on Tuesday")
check(state([reading],at:"2036-10-04").clutter[.reading] == 3,"A decade of absence is bounded")
let duplicate = log(reading,"2026-10-04",hour:10)
check(state([reading],[achieved,duplicate]).totalCompletions == 1,"Duplicate same-day logs cannot multiply growth")
check(state([reading],[log(reading,"2026-10-05")]).totalCompletions == 0,"Future records cannot grow or tidy today's world")
var travel = cal; travel.timeZone = TimeZone(identifier:"America/Los_Angeles")!
let before = PochiWorldState.evaluate(presets:[reading],logs:[],rules:rules([reading]),now:date("2026-10-04",hour:1),calendar:cal)
let after = PochiWorldState.evaluate(presets:[reading],logs:[],rules:rules([reading]),now:date("2026-10-04",hour:1),calendar:travel)
check(before.clutter == after.clutter,"Timezone travel must not fabricate overdue days")
for (hour,expected) in [(2,PochiLifePhase.deepNight),(7,.morning),(12,.daytime),(20,.evening),(23,.deepNight)] {
    check(state([reading],hour:hour).phase == expected,"Local clock sets the dog's life rhythm")
}
let saved = try JSONEncoder().encode(rules([reading]))
check(try JSONDecoder().decode([String:PochiWorldRule].self,from:saved) == rules([reading]),"Rule metadata survives relaunch")
for (title,expected) in [("本を読む",PochiPromiseTheme.reading),("Read a book",.reading),("책 읽기",.reading),("閱讀十分鐘",.reading),("清洁房间",.cleaning),("청소",.cleaning),("workout",.exercise),("早睡",.sleeping),("공부",.studying)] {
    check(PochiPromiseTheme.infer(preset(UUID().uuidString,title,icon:"sparkles",category:.hobbies)) == expected,"Local classification: \(title)")
}
let general = preset("custom","Bread baking",icon:"sparkles",category:.hobbies)
check(PochiPromiseTheme.infer(general) == .general,"Reading classifier must not match bread")
check(state([general]).visibleClutter.isEmpty,"Unclassified promises do not create unrelated clutter")
print("PASS: daily/weekly deadlines, weekday schedule, undo, deletion, edits, bounded clutter, new-user baseline, long absence, timezone, clock phases, duplicate/future logs, persistence, local multilingual classification")

check(combined.clutterObjects.filter { $0.theme == .cleaning } == onlyReadingDone.clutterObjects.filter { $0.theme == .cleaning },"Reading success must not reveal or move unrelated litter")
let travelRules = PochiWorldRule.synchronize(rules([reading]),presets:[reading],now:date("2026-10-04"),calendar:travel)
check(travelRules[reading.id]?.timeZoneID == travel.timeZone.identifier && travelRules[reading.id]?.startedAt == date("2026-10-04"),"Timezone changes start a forgiving local observation period")
let nowState = PochiWorldState.evaluate(presets:[reading],logs:[],rules:travelRules,now:date("2026-10-04"),calendar:travel)
check(nowState.clutter[.reading] == 0,"Travelling never turns the current partial day into a missed promise")
let unknown = preset("new","友達に電話する",icon:"sparkles",category:.connection)
check(PochiPromiseTheme.infer(unknown) == .general,"Unclassified connection habits should not grow a desk")
print("PASS: stable clutter slots after success, forgiving local timezone changes, general custom promise")

let renamedReading = preset("reading","掃除",icon:"clean",category:.home)
check(PochiPromiseTheme.infer(renamedReading) == .cleaning,"Explicit edited title must override an old built-in ID")
let renamedRules = PochiWorldRule.synchronize(rules([reading]),presets:[renamedReading],now:date("2026-10-04"),calendar:cal)
check(renamedRules[reading.id]?.theme == .cleaning && renamedRules[reading.id]?.startedAt == date("2026-10-04"),"A theme edit never reinterprets prior missed opportunities")
check(PochiPromiseTheme.infer(preset("custom-cn","读书十分钟",icon:"sparkles",category:.hobbies)) == .reading,"Custom Chinese reading title maps locally")
print("PASS: theme edits, preserved IDs, Chinese reading classification")

let tokyoCalendar = cal
cal.timeZone = TimeZone(identifier:"America/Los_Angeles")!
for (startDay,nowDay) in [("2026-03-06","2026-03-09"),("2026-10-30","2026-11-02")] {
    let startedAt = date(startDay)
    let localRules = PochiWorldRule.synchronize([:],presets:[reading],now:startedAt,calendar:cal)
    let localState = PochiWorldState.evaluate(presets:[reading],logs:[],rules:localRules,now:date(nowDay,hour:0),calendar:cal)
    check(localState.clutter[.reading] == 2,"DST days must count as calendar days, not 24-hour durations")
}
cal = tokyoCalendar
check(state([reading],at:"2026-09-01").clutter[.reading] == 0,"Clock rollback before observation start must not create overdue dates")
check(state([weekly],at:"2026-10-05",hour:0,saved:weeklyRules).clutter[.reading] == 3,"Weekly deadline closes exactly at next week's local midnight")
print("PASS: spring/fall DST, clock rollback, exact weekly midnight boundary")
