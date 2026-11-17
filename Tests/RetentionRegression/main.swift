import Foundation
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
calendar.firstWeekday = 2
func date(_ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
}
func log(_ day: Int, _ mode: WorkoutMode, _ values: [Int]) -> HabitLog {
    HabitLog(presetID: "squats", title: "squats", completedAt: date(day),
        workouts: [WorkoutRecord(id: UUID().uuidString, plan: WorkoutPlan(mode: mode), values: values)])
}
let logs = [log(16, .repetitions, [10, 5]), log(16, .timed, [30]), log(17, .repetitions, [8]),
            log(15, .repetitions, [100]), log(18, .repetitions, [999]),
            HabitLog(presetID: "reading", title: "book", completedAt: date(17))]
let result = WorkoutWeekSummary(logs: logs, now: date(17, 23), calendar: calendar)
precondition(result.days == 2 && result.previousDays == 1)
precondition(result.repetitions == 23 && result.seconds == 30)
let empty = WorkoutWeekSummary(logs: [], now: date(17), calendar: calendar)
precondition(empty.days == 0 && empty.repetitions == 0)
let boundary = WorkoutWeekSummary(logs: logs, now: date(16, 0), calendar: calendar)
precondition(boundary.days == 0 && boundary.previousDays == 1)
precondition(PochiMuscleStage.earned(days: 2).next?.requiredDays == 3)
precondition(PochiMuscleStage.earned(days: 3).next?.requiredDays == 7)
precondition(PochiMuscleStage.earned(days: 30).next == nil)
print("Retention regression passed")

let original = HabitPreset(id: "custom", title: "My workout", iconName: "star", tintName: .lavender,
    weeklyTarget: 2, category: .hobbies, workoutPlan: WorkoutPlan(target: 22))
let light = original.withPlan(WorkoutPlan(target: 5, sets: 1))
precondition(original.workoutPlan.target == 22 && light.workoutPlan.target == 5)
precondition(light.id == original.id && light.tintName == original.tintName)
precondition(light.weeklyTarget == 2 && light.category == .hobbies)
print("Session snapshot preserves the saved menu and metadata")

let second = HabitPreset(id: "second", title: "Second", iconName: "plank", tintName: .peach)
let latest = original.withPlan(WorkoutPlan(target: 7))
let datedLog = HabitLog(presetID: second.id, title: second.title, completedAt: date(17),
    workouts: [WorkoutRecord(id: "later-day-row", plan: WorkoutPlan(target: 12), values: [12])])
let selected = WorkoutHomeSelection.previous(presets: [original, second], lastCompleted: latest, logs: [datedLog], now: date(18))
precondition(selected?.id == original.id && selected?.workoutPlan.target == 7)
let restored = try JSONDecoder().decode(HabitPreset.self, from: JSONEncoder().encode(latest))
precondition(restored == latest)
precondition(WorkoutHomeSelection.previous(presets: [second], lastCompleted: latest, logs: [datedLog], now: date(18))?.id == second.id)
precondition(WorkoutHomeSelection.previous(presets: [], lastCompleted: latest, logs: [datedLog], now: date(18)) == nil)
precondition(WorkoutPlan(target: 3).lightSession.target == 3)
precondition(WorkoutPlan(mode: .timed, target: 30).lightSession.target == 15)
precondition(original.workoutPlan.target == 22)
print("Home selection, deleted presets, snapshots and light sessions passed")
