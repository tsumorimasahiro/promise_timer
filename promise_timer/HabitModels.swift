import Foundation

// Stored raw values and coding keys are shared with existing app and widget data.
enum PresetTint: String, Codable, CaseIterable {
    case peach, sunshine, mintGreen, lavender, candyBlue
}

enum HabitCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case care, home, learning, connection, hobbies
    var id: String { rawValue }
}

enum WorkoutMode: String, Codable, CaseIterable {
    case repetitions, timed
}

struct WorkoutPlan: Codable, Hashable {
    var mode: WorkoutMode = .repetitions
    var target: Int = 10
    // Retained for compatibility with previously saved plans; new workouts count actual sets.
    var sets: Int = 3
    var validated: Self {
        Self(mode: mode, target: min(max(target, 1), mode == .timed ? 3600 : 999), sets: min(max(sets, 1), 20))
    }
    static func defaultPlan(for id: String) -> Self {
        ["strength.plank", "strength.sidePlank", "strength.birdDog", "strength.deadBug"].contains(id)
            ? Self(mode: .timed, target: 30, sets: 3) : Self()
    }
}

struct WorkoutRecord: Codable, Hashable, Identifiable {
    let id: String
    let plan: WorkoutPlan
    let values: [Int]
}

struct HabitPreset: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let tintName: PresetTint
    let weeklyTarget: Int
    let category: HabitCategory
    let workoutPlan: WorkoutPlan

    init(
        id: String = UUID().uuidString,
        title: String,
        iconName: String,
        tintName: PresetTint,
        weeklyTarget: Int = 3,
        category: HabitCategory = .care,
        workoutPlan: WorkoutPlan? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.tintName = tintName
        self.weeklyTarget = min(max(weeklyTarget, 1), 7)
        self.category = category
        self.workoutPlan = (workoutPlan ?? .defaultPlan(for: id)).validated
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconName
        case tintName
        case weeklyTarget
        case category, workoutPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        iconName = try container.decode(String.self, forKey: .iconName)
        tintName = try container.decode(PresetTint.self, forKey: .tintName)
        weeklyTarget = min(max(try container.decodeIfPresent(Int.self, forKey: .weeklyTarget) ?? 7, 1), 7)
        category = try container.decodeIfPresent(HabitCategory.self, forKey: .category) ?? .care
        workoutPlan = (try container.decodeIfPresent(WorkoutPlan.self, forKey: .workoutPlan) ?? .defaultPlan(for: id)).validated
    }
}

struct HabitLog: Identifiable, Codable, Hashable {
    let id: String
    let presetID: String
    let title: String
    let completedAt: Date
    let durationSeconds: TimeInterval?
    let timedSessionIDs: [String]
    let workouts: [WorkoutRecord]

    init(
        id: String = UUID().uuidString,
        presetID: String,
        title: String,
        completedAt: Date = Date(),
        durationSeconds: TimeInterval? = nil,
        timedSessionIDs: [String] = [],
        workouts: [WorkoutRecord] = []
    ) {
        self.id = id
        self.presetID = presetID
        self.title = title
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.timedSessionIDs = timedSessionIDs
        self.workouts = workouts
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case presetID
        case title
        case completedAt
        case durationSeconds, timedSessionIDs, workouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        presetID = try container.decode(String.self, forKey: .presetID)
        title = try container.decode(String.self, forKey: .title)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
        timedSessionIDs = try container.decodeIfPresent([String].self, forKey: .timedSessionIDs) ?? []
        workouts = try container.decodeIfPresent([WorkoutRecord].self, forKey: .workouts) ?? []
    }
}


// Transient reactions are independent of persistence and never change achievements.
enum PochiRoomActivity: String, Equatable, CaseIterable {
    case idle, eat, drink, sleep, exercise, strength, study, clean, selfCare, joy
    case stretch, stroll, rest, breathe, read, wash, listen, pose

    /// Detailed reactions share the existing long-term learning categories.
    var learningActivity: Self {
        switch self {
        case .stretch, .stroll, .strength: return .exercise
        case .read: return .study
        case .rest, .breathe, .wash: return .selfCare
        case .listen, .pose: return .joy
        default: return self
        }
    }
}

struct PochiReactionBatch: Equatable {
    var recordIDs: [String]
    var activity: PochiRoomActivity
}

struct PochiReactionQueue {
    private(set) var batches: [PochiReactionBatch] = []

    mutating func enqueue(id: String, activity: PochiRoomActivity) {
        guard activity != .idle else { return }
        guard !batches.contains(where: { $0.recordIDs.contains(id) }) else { return }
        // Coalesce only matching reactions. A sleep record must never turn into
        // a generic celebration just because several habits were checked together.
        if let index = batches.firstIndex(where: { $0.activity == activity }) {
            batches[index].recordIDs.append(id)
        } else { batches.append(PochiReactionBatch(recordIDs: [id], activity: activity)) }
    }

    mutating func next() -> PochiReactionBatch? {
        batches.isEmpty ? nil : batches.removeFirst()
    }

    mutating func cancel(id: String) {
        for index in batches.indices { batches[index].recordIDs.removeAll { $0 == id } }
        batches.removeAll { $0.recordIDs.isEmpty }
    }
}

enum HabitCalendar {
    static func monthDays(containing date: Date, calendar: Calendar) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let start = calendar.dateInterval(of: .weekOfYear, for: month.start)?.start,
              let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end),
              let end = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.end else { return [] }
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// Additive profile preference; existing users default to their original Shiba.
enum PochiBreed: String, CaseIterable, Identifiable {
    case shiba, dalmatian, pomeranian
    var id: String { rawValue }
    var requiresPremium: Bool { self != .shiba }
    var titleKey: String {
        switch self {
        case .shiba: return "柴犬"
        case .dalmatian: return "ダルメシアン"
        case .pomeranian: return "ポメラニアン"
        }
    }
}
