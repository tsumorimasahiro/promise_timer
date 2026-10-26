import Foundation
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let suite = "PochiWorkoutMigrationTest." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let water = HabitPreset(id: "water", title: "水を飲む", iconName: "drop.fill", tintName: .peach)
let reading = HabitPreset(id: "reading", title: "本を10分読む", iconName: "book", tintName: .peach)
let training = PochiWorkoutCatalog.presets[2]
let custom = HabitPreset(id: "strength.custom.example", title: "Aメニュー", iconName: "dumbbell.fill", tintName: .peach)
let now = Date(timeIntervalSince1970: 1_792_800_000)
let trainingLog = HabitLog(presetID: training.id, title: training.title, completedAt: now,
    durationSeconds: 85, timedSessionIDs: ["session-1", "session-2"])
let deletedExerciseLog = HabitLog(presetID: custom.id, title: custom.title, completedAt: now)
func seed(_ presets: [HabitPreset], _ logs: [HabitLog], _ session: PochiTogetherSession?) throws {
    defaults.removePersistentDomain(forName: suite)
    let encoder = JSONEncoder()
    defaults.set(String(decoding: try encoder.encode(presets), as: UTF8.self), forKey: PochiWorkoutMigration.presetKey)
    if let session { defaults.set(String(decoding: try encoder.encode(session), as: UTF8.self), forKey: PochiWorkoutMigration.sessionKey) }
    encoder.dateEncodingStrategy = .iso8601
    defaults.set(String(decoding: try encoder.encode(logs), as: UTF8.self), forKey: PochiWorkoutMigration.logKey)
    defaults.set(14, forKey: "pochiStrengthDays")
}
func presets() throws -> [HabitPreset] {
    try JSONDecoder().decode([HabitPreset].self, from: Data(defaults.string(forKey: PochiWorkoutMigration.presetKey)!.utf8))
}
func logs() throws -> [HabitLog] {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([HabitLog].self, from: Data(defaults.string(forKey: PochiWorkoutMigration.logKey)!.utf8))
}
try seed([water, reading, training], [HabitLog(presetID: reading.id, title: reading.title), trainingLog, deletedExerciseLog], PochiTogetherSession(preset: reading, now: now))
require(PochiWorkoutMigration.apply(to: defaults), "Mixed migration succeeds")
let firstPresets = try presets(); let firstLogs = try logs()
require(firstPresets == [training], "Only training exercises remain")
require(firstLogs == [trainingLog, deletedExerciseLog], "Keep durations, IDs, and deleted-exercise history exactly")
require(defaults.string(forKey: PochiWorkoutMigration.sessionKey) == "", "Stop legacy reading timer")
require(defaults.integer(forKey: "pochiStrengthDays") == 14, "Earned body progression is untouched")
let backup = defaults.dictionary(forKey: PochiWorkoutMigration.backupKey) as! [String: String]
require(backup[PochiWorkoutMigration.presetKey]!.contains("reading"), "Internal recovery copy exists")
require(PochiWorkoutMigration.apply(to: defaults), "Idempotent second launch")
require(defaults.dictionary(forKey: PochiWorkoutMigration.backupKey) as! [String: String] == backup, "Never replace recovery copy")
var session = PochiTogetherSession(preset: training, now: now)
session.pause(at: now.addingTimeInterval(30))
try seed([training], [trainingLog], session)
let originalSession = defaults.string(forKey: PochiWorkoutMigration.sessionKey)
require(PochiWorkoutMigration.apply(to: defaults), "Workout-only upgrade succeeds")
require(defaults.string(forKey: PochiWorkoutMigration.sessionKey) == originalSession, "Paused workout survives exactly")
try seed([reading], [], nil)
require(PochiWorkoutMigration.apply(to: defaults), "Legacy-only upgrade succeeds")
let fallback = try presets()
require(fallback == PochiWorkoutCatalog.starterPresets, "Legacy-only users get a usable training default")
try seed([], [], nil)
require(PochiWorkoutMigration.apply(to: defaults), "Empty upgrade succeeds")
let empty = try presets(); require(empty.isEmpty, "Intentional empty list remains empty")
try seed([reading], [], nil)
defaults.set("unrecognized archive", forKey: PochiWorkoutMigration.logKey)
let before = defaults.string(forKey: PochiWorkoutMigration.presetKey)
require(!PochiWorkoutMigration.apply(to: defaults), "Unreadable data blocks writes")
require(defaults.string(forKey: PochiWorkoutMigration.presetKey) == before, "No partial rewrite")
require(!defaults.bool(forKey: PochiWorkoutMigration.versionKey), "Failed migration remains retryable")
defaults.removePersistentDomain(forName: suite)
require(PochiWorkoutMigration.apply(to: defaults), "Fresh install supported")
require(defaults.string(forKey: PochiWorkoutMigration.presetKey) == nil, "Fresh install still reaches onboarding")
print("PASS: training-only upgrade, history/timer retention, recovery copy, repeat launch, legacy-only/default/empty/fresh installs, corrupt archive")
