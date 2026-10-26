import Foundation

/// Derived from saved history, not a streak or a currency. No new save schema.
struct PochiLifeHabits: Equatable {
    var sharedDays = 0
    var daysByActivity: [String: Int] = [:]

    func days(for activity: PochiRoomActivity) -> Int {
        daysByActivity[activity.rawValue, default: 0]
    }

    static func derive(logs: [HabitLog], calendar: Calendar, now: Date,
                       activity: (HabitLog) -> PochiRoomActivity?) -> Self {
        var shared = Set<Date>()
        var activityDays: [String: Set<Date>] = [:]
        for log in logs where log.completedAt <= now {
            let day = calendar.startOfDay(for: log.completedAt)
            shared.insert(day)
            if let kind = activity(log) {
                activityDays[kind.rawValue, default: []].insert(day)
            }
        }
        return Self(sharedDays: shared.count, daysByActivity: activityDays.mapValues(\.count))
    }
}
