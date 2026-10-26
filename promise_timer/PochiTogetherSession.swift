import Foundation

/// Save timestamps instead of counting timer ticks, so locking or relaunching the app
/// does not lose time. The preset snapshot survives edits or deletion during a session.
struct PochiTogetherSession: Codable, Equatable, Identifiable {
    let id: String
    let preset: HabitPreset
    let startedAt: Date
    private(set) var completedValues: [Int] = []
    private(set) var setBaseline: TimeInterval = 0
    private(set) var awaitingNextSet = false
    private(set) var runningSince: Date?
    private(set) var accumulatedSeconds: TimeInterval

    init(preset: HabitPreset, now: Date = Date()) {
        id = UUID().uuidString
        self.preset = preset
        startedAt = now
        runningSince = now
        accumulatedSeconds = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, preset, startedAt, runningSince, accumulatedSeconds, completedValues, setBaseline, awaitingNextSet
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        preset = try c.decode(HabitPreset.self, forKey: .preset)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        runningSince = try c.decodeIfPresent(Date.self, forKey: .runningSince)
        accumulatedSeconds = try c.decode(TimeInterval.self, forKey: .accumulatedSeconds)
        completedValues = try c.decodeIfPresent([Int].self, forKey: .completedValues) ?? []
        setBaseline = try c.decodeIfPresent(TimeInterval.self, forKey: .setBaseline) ?? 0
        awaitingNextSet = try c.decodeIfPresent(Bool.self, forKey: .awaitingNextSet) ?? false
    }
    // The old planned set count remains decodable, but does not end a workout.
    // Users choose whether to continue after each set; only actual sets are saved.
    var hasReachedSetLimit: Bool { completedValues.count >= 20 }
    func setElapsed(at now: Date) -> TimeInterval { max(0, elapsed(at: now) - setBaseline) }
    func remaining(at now: Date) -> Int { max(0, preset.workoutPlan.target - Int(setElapsed(at: now))) }
    mutating func completeSet(at now: Date) {
        guard !awaitingNextSet, !hasReachedSetLimit else { return }
        pause(at: now)
        if preset.workoutPlan.mode == .timed {
            let seconds = min(preset.workoutPlan.target, Int(setElapsed(at: now)))
            guard seconds > 0 else { return }
            // Background time past the deadline is never counted as extra exercise.
            accumulatedSeconds = setBaseline + Double(seconds)
            completedValues.append(seconds)
        } else { completedValues.append(preset.workoutPlan.target) }
        awaitingNextSet = true
    }
    mutating func startNextSet(at now: Date) {
        guard awaitingNextSet, !hasReachedSetLimit else { return }
        awaitingNextSet = false
        setBaseline = accumulatedSeconds
        runningSince = now
    }
    func suggestedValues(at now: Date) -> [Int] {
        if preset.workoutPlan.mode == .repetitions {
            return completedValues + (!awaitingNextSet && !hasReachedSetLimit ? [preset.workoutPlan.target] : [])
        }
        let partial = min(preset.workoutPlan.target, Int(setElapsed(at: now)))
        return completedValues + (!awaitingNextSet && !hasReachedSetLimit && partial > 0 ? [partial] : [])
    }

    var isPaused: Bool { runningSince == nil }

    func elapsed(at now: Date) -> TimeInterval {
        let total = accumulatedSeconds + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        return preset.workoutPlan.mode == .timed && !awaitingNextSet
            ? min(total, setBaseline + Double(preset.workoutPlan.target)) : total
    }

    mutating func pause(at now: Date) {
        accumulatedSeconds = elapsed(at: now)
        runningSince = nil
    }

    mutating func resume(at now: Date) {
        guard isPaused, !awaitingNextSet, !hasReachedSetLimit else { return }
        runningSince = now
    }

    /// One achievement per habit per completion day. Repeated sessions add time,
    /// and replay after an interrupted save cannot count the same session twice.
    func recording(in logs: [HabitLog], at now: Date, calendar: Calendar, values: [Int]? = nil, recordsDuration: Bool = true) -> [HabitLog] {
        guard !logs.contains(where: { $0.timedSessionIDs.contains(id) }) else { return logs }
        let record = values.map { WorkoutRecord(id: id, plan: preset.workoutPlan, values: $0) }
        let duration = recordsDuration ? elapsed(at: now) : nil
        var result = logs
        if let index = result.firstIndex(where: {
            $0.presetID == preset.id && calendar.isDate($0.completedAt, inSameDayAs: now)
        }) {
            let old = result[index]
            result[index] = HabitLog(id: old.id, presetID: old.presetID, title: old.title,
                completedAt: old.completedAt,
                durationSeconds: old.durationSeconds.map { $0 + (duration ?? 0) } ?? duration,
                timedSessionIDs: old.timedSessionIDs + [id],
                workouts: old.workouts + (record.map { [$0] } ?? []))
        } else {
            result.append(HabitLog(id: id, presetID: preset.id, title: preset.title,
                completedAt: now, durationSeconds: duration, timedSessionIDs: [id],
                workouts: record.map { [$0] } ?? []))
        }
        return result
    }
}

enum PochiElapsedTime {
    static func string(_ seconds: TimeInterval) -> String {
        let value = Int(min(max(seconds.isFinite ? seconds : 0, 0), 315_360_000))
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
