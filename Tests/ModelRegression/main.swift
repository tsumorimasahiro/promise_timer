import Foundation

// Runs against the same Foundation models compiled into the app. No UserDefaults access.
func require(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

let decoder = JSONDecoder()
let encoder = JSONEncoder()
let legacy = Data(#"{"id":"water","title":"水を飲む","iconName":"drop.fill","tintName":"candyBlue"}"#.utf8)
let legacyPreset = try decoder.decode(HabitPreset.self, from: legacy)
require(legacyPreset.id == "water" && legacyPreset.title == "水を飲む", "Legacy identity must survive decoding")
require(legacyPreset.weeklyTarget == 7 && legacyPreset.category == .care, "Legacy defaults must remain compatible")

for (saved, expected) in [(-2, 1), (0, 1), (4, 4), (20, 7)] {
    let json = Data("{\"id\":\"custom\",\"title\":\"読書\",\"iconName\":\"book\",\"tintName\":\"peach\",\"weeklyTarget\":\(saved)}".utf8)
    require(try decoder.decode(HabitPreset.self, from: json).weeklyTarget == expected, "Out-of-range stored targets must remain usable")
}

let savedPresets = (0..<20).map {
    HabitPreset(id: "custom-\($0)", title: "読書・공부・閱讀 \($0)", iconName: "book", tintName: .lavender, weeklyTarget: 3, category: .learning)
}
let recovered = try decoder.decode([HabitPreset].self, from: encoder.encode(savedPresets))
require(recovered == savedPresets, "All saved promises and Unicode titles must survive a round trip")
let empty = try decoder.decode([HabitPreset].self, from: encoder.encode([HabitPreset]()))
require(empty.isEmpty, "Zero promises must remain a valid saved state")

encoder.dateEncodingStrategy = .iso8601
decoder.dateDecodingStrategy = .iso8601
let oldLog = Data(#"{"id":"existing-log","presetID":"deleted-preset","title":"昔の約束","completedAt":"2026-10-20T14:59:59Z"}"#.utf8)
let log = try decoder.decode(HabitLog.self, from: oldLog)
let recoveredLog = try decoder.decode(HabitLog.self, from: encoder.encode(log))
require(recoveredLog == log, "History must survive even when its promise no longer exists")
require(log.presetID == "deleted-preset", "Historical promise references must be retained")

print("PASS: legacy fields, target bounds, 20-promise Unicode round trip, empty state, ISO8601 history")

var queue = PochiReactionQueue()
queue.enqueue(id: "meal", activity: .eat)
queue.enqueue(id: "study", activity: .study)
queue.enqueue(id: "sleep", activity: .sleep)
queue.enqueue(id: "run", activity: .exercise)
queue.enqueue(id: "run", activity: .exercise)
require(queue.batches.count == 4, "Different reactions must remain distinct")
require(queue.batches[2].activity == .sleep && queue.batches[3].activity == .exercise, "Queued sleep must not become generic joy")
require(queue.next()?.recordIDs == ["meal"], "Reactions must preserve order")
queue.cancel(id: "sleep")
require(queue.batches.last?.recordIDs == ["run"], "Undo must remove only the cancelled record")
queue.cancel(id: "study")
queue.cancel(id: "run")
require(queue.next() == nil, "Cancelled batches must not replay")

for zone in ["Asia/Tokyo", "America/Los_Angeles"] {
    for firstDay in [1, 2] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = firstDay
        for (year, month, count) in [(2024, 2, 29), (2026, 3, 31), (2026, 11, 30), (2026, 12, 31), (2027, 1, 31)] {
            let date = calendar.date(from: DateComponents(year: year, month: month, day: 15))!
            let days = HabitCalendar.monthDays(containing: date, calendar: calendar)
            require([28, 35, 42].contains(days.count), "Calendar must contain whole weeks")
            require(calendar.component(.weekday, from: days.first!) == firstDay, "Grid must respect locale week start")
            require(days.filter { calendar.isDate($0, equalTo: date, toGranularity: .month) }.count == count, "Every date in the month must remain reachable")
            for (a, b) in zip(days, days.dropFirst()) {
                require(calendar.date(byAdding: .day, value: 1, to: a) == b, "Dates must be consecutive across DST")
            }
        }
    }
}
for activity in PochiRoomActivity.allCases where activity != .idle {
    for index in 0..<20 { queue.enqueue(id: "\(activity.rawValue)-\(index)", activity: activity) }
}
require(queue.batches.count == PochiRoomActivity.allCases.count - 1, "Backlog is bounded by activity kinds")
require(queue.batches.allSatisfy { $0.recordIDs.count == 20 }, "Matching reactions coalesce without losing records")
print("PASS: bounded semantic reaction queue, playback order, deduplication, undo, month navigation, leap year, DST, week starts")
