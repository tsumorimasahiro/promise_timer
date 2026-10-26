import Foundation
import Combine

@MainActor final class PochiWorldRuleStore: ObservableObject {
    @Published private(set) var rules: [String: PochiWorldRule] = [:]
    private let defaults: UserDefaults
    private let key = "pochiWorldRules.v1"
    private var writable = true
    init(defaults: UserDefaults) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do { rules = try JSONDecoder().decode([String: PochiWorldRule].self, from: data) }
        catch { writable = false } // Never overwrite an unrecognized saved archive.
    }
    func synchronize(presets: [HabitPreset], now: Date, calendar: Calendar) {
        guard writable else { return }
        let next = PochiWorldRule.synchronize(rules, presets: presets, now: now, calendar: calendar)
        guard next != rules, let data = try? JSONEncoder().encode(next) else { return }
        defaults.set(data, forKey: key)
        rules = next
    }
}
