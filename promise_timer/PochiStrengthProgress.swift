import Foundation

enum PochiMuscleStage: Int, Codable, CaseIterable, Identifiable {
    case puppy, toned, strong, muscular, champion
    var id: Int { rawValue }
    var requiredDays: Int { [0, 3, 7, 14, 30][rawValue] }
    var titleKey: String { ["いつものぽち", "ちょいマッチョ", "たくましいぽち", "ムキムキぽち", "マッスルぽち"][rawValue] }
    static func earned(days: Int) -> Self {
        allCases.last { days >= $0.requiredDays } ?? .puppy
    }
    var next: Self? { Self(rawValue: rawValue + 1) }
    static func visible(selection: Int, earned: Self) -> Self {
        selection < 0 ? earned : Self(rawValue: min(selection, earned.rawValue)) ?? .puppy
    }
}

/// Earned days remain earned after a break, deleting a habit, or deleting history.
/// Remember each source log's first local date so a timezone change cannot credit
/// the same achievement on another day. Several exercises on one day count once.
struct PochiStrengthProgress: Codable, Equatable {
    private(set) var daysByLogID: [String: String] = [:]
    var dayCount: Int { Set(daysByLogID.values).count }
    var stage: PochiMuscleStage { .earned(days: dayCount) }

    mutating func include(logs: [HabitLog], now: Date, calendar: Calendar) {
        for log in logs where log.completedAt <= now && daysByLogID[log.id] == nil {
            let snapshot = HabitPreset(id: log.presetID, title: log.title, iconName: "sparkles", tintName: .peach)
            guard PochiPromiseReaction.activity(for: snapshot) == .strength else { continue }
            let date = calendar.dateComponents([.era, .year, .month, .day], from: log.completedAt)
            daysByLogID[log.id] = "\(date.era ?? 1)-\(date.year ?? 0)-\(date.month ?? 0)-\(date.day ?? 0)"
        }
    }
}
