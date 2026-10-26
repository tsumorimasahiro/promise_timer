import Foundation

/// A one-time transition of the active stores. Keep an internal recovery copy;
/// the product no longer exposes or records non-training habits.
enum PochiWorkoutMigration {
    static let versionKey = "pochiWorkoutOnly.v1"
    static let backupKey = "pochiWorkoutOnly.previousStores.v1"
    static let presetKey = "habitPresetsStore"
    static let logKey = "habitLogsStore"
    static let sessionKey = "pochiTogetherSession.v1"

    @discardableResult
    static func apply(to defaults: UserDefaults) -> Bool {
        if defaults.bool(forKey: versionKey) { return true }
        let raw = [presetKey, logKey, sessionKey].reduce(into: [String: String]()) {
            $0[$1] = defaults.string(forKey: $1) ?? ""
        }
        do {
            let decoder = JSONDecoder()
            let presets = try raw[presetKey]!.isEmpty ? [] : decoder.decode([HabitPreset].self, from: Data(raw[presetKey]!.utf8))
            let session = try raw[sessionKey]!.isEmpty ? nil : decoder.decode(PochiTogetherSession.self, from: Data(raw[sessionKey]!.utf8))
            decoder.dateDecodingStrategy = .iso8601
            let logs = try raw[logKey]!.isEmpty ? [] : decoder.decode([HabitLog].self, from: Data(raw[logKey]!.utf8))
            let training = presets.filter { PochiWorkoutCatalog.isWorkout($0) }
            let retained = logs.filter { log in
                if let preset = presets.first(where: { $0.id == log.presetID }) {
                    return PochiWorkoutCatalog.isWorkout(preset)
                }
                return PochiWorkoutCatalog.isWorkout(HabitPreset(id: log.presetID,
                    title: log.title, iconName: "", tintName: .peach))
            }
            let encoder = JSONEncoder()
            let newPresets = try String(decoding: encoder.encode(
                !presets.isEmpty && training.isEmpty ? PochiWorkoutCatalog.starterPresets : training), as: UTF8.self)
            encoder.dateEncodingStrategy = .iso8601
            let newLogs = try String(decoding: encoder.encode(retained), as: UTF8.self)
            // Prepare everything before writing; unknown/corrupt formats stay untouched.
            if defaults.dictionary(forKey: backupKey) == nil { defaults.set(raw, forKey: backupKey) }
            if !raw[presetKey]!.isEmpty { defaults.set(newPresets, forKey: presetKey) }
            if !raw[logKey]!.isEmpty { defaults.set(newLogs, forKey: logKey) }
            if let session, !PochiWorkoutCatalog.isWorkout(session.preset) {
                defaults.set("", forKey: sessionKey)
            }
            defaults.set(true, forKey: versionKey)
            return true
        } catch { return false }
    }
}
