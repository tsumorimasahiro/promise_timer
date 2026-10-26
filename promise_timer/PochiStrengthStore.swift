import Foundation
import Combine

@MainActor final class PochiStrengthStore: ObservableObject {
    @Published private(set) var progress = PochiStrengthProgress()
    private let defaults: UserDefaults
    private var writable = true
    static let archiveKey = "pochiStrengthProgress.v1"
    static let daysKey = "pochiStrengthDays"
    static let appearanceKey = "pochiMuscleAppearance"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.archiveKey) {
            do { progress = try JSONDecoder().decode(PochiStrengthProgress.self, from: data) }
            catch { writable = false }
        }
        if writable { defaults.set(progress.dayCount, forKey: Self.daysKey) }
    }

    func synchronize(logs: [HabitLog], now: Date, calendar: Calendar) {
        guard writable else { return }
        var updated = progress
        updated.include(logs: logs, now: now, calendar: calendar)
        guard updated != progress, let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: Self.archiveKey)
        defaults.set(updated.dayCount, forKey: Self.daysKey)
        progress = updated
    }
}
