import Foundation

@main struct MemoryRegression {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pochi-memory-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let first = UIImage(data: Data("first photo".utf8))
        let chosen = UIImage(data: Data("chosen photo".utf8))
        let store = PochiMemoryStore(directory: root)
        precondition(store.rememberToday(image: first, name: "Pochi", date: now, workoutPhoto: true))
        precondition(!store.rememberToday(image: first, name: "Idle", date: now))
        let initial = store.dailyPhotos[0]
        precondition(store.rememberToday(image: chosen, name: "Pochi", date: now, workoutPhoto: true))
        precondition(store.dailyPhotos.count == 1 && store.dailyPhotos[0].id == initial.id)
        let story = PochiStory.all[0]
        store.remember(story, image: first, name: "Pochi")
        precondition(store.representativePhoto(on: now, calendar: calendar)?.id == initial.id)
        precondition(store.rememberToday(image: chosen, name: "New name", date: now, replaceExisting: true, workoutPhoto: true))
        let manual = store.dailyPhotos[0]
        precondition(manual.isUserPhoto == true && manual.id != initial.id)
        precondition(store.representativePhoto(on: now, calendar: calendar)?.id == manual.id)
        precondition(store.rememberToday(image: first, name: "Pochi", date: now, workoutPhoto: true))
        precondition(store.dailyPhotos[0].id == manual.id)
        precondition(store.image(for: initial)?.data == first.data) // old file survives replacement
        let reloaded = PochiMemoryStore(directory: root)
        precondition(reloaded.representativePhoto(on: now, calendar: calendar)?.id == manual.id)
        precondition(reloaded.image(for: manual)?.data == chosen.data)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        precondition(!store.rememberToday(image: first, name: "Pochi", date: yesterday, replaceExisting: true, workoutPhoto: true))
        precondition(store.representativePhoto(on: yesterday, calendar: calendar) == nil)

        // Simulate metadata write failure after the new image was written.
        let archiveURL = root.appendingPathComponent("archive.json")
        let backupURL = root.appendingPathComponent("archive.backup")
        try FileManager.default.moveItem(at: archiveURL, to: backupURL)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        precondition(!store.rememberToday(image: first, name: "Failed save", replaceExisting: true, workoutPhoto: true))
        precondition(store.saveFailed && store.dailyPhotos[0].id == manual.id)
        precondition(store.image(for: manual)?.data == chosen.data)
        try FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.moveItem(at: backupURL, to: archiveURL)
        precondition(PochiMemoryStore(directory: root).dailyPhotos[0].id == manual.id)

        store.discover(PochiLifeHabits(sharedDays: 7, daysByActivity: ["study": 7, "exercise": 7, "sleep": 7]))
        precondition(store.pendingStory(among: [.exercise, .study])?.activity == .exercise)
        precondition(store.pendingStory(among: [.sleep, .study])?.activity == .sleep)
        precondition(store.pendingStory(among: []) == nil)
        precondition(store.pendingStory(among: [.study]) == nil)
        precondition(!PochiStory.all.contains { $0.activity == .study })

        let legacy = root.appendingPathComponent("legacy")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        let old: [String: Any] = ["unlocked": [], "memories": [["id":"exercise-0", "date":now.timeIntervalSinceReferenceDate, "dogName":"Pochi"], ["id":"study-0", "date":now.timeIntervalSinceReferenceDate, "dogName":"Pochi"]]]
        try JSONSerialization.data(withJSONObject: old).write(to: legacy.appendingPathComponent("archive.json"))
        let oldStore = PochiMemoryStore(directory: legacy)
        precondition(!oldStore.saveFailed && oldStore.memories.isEmpty && oldStore.dailyPhotos.isEmpty)
        precondition(oldStore.representativePhoto(on: now, calendar: calendar) == nil)
        precondition(oldStore.rememberToday(image: first, name: "Pochi", workoutPhoto: true))
        precondition(PochiMemoryStore(directory: legacy).memories.isEmpty)

        let corrupt = root.appendingPathComponent("corrupt")
        try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
        let corruptURL = corrupt.appendingPathComponent("archive.json")
        let bad = Data("invalid archive".utf8)
        try bad.write(to: corruptURL)
        let blocked = PochiMemoryStore(directory: corrupt)
        precondition(blocked.saveFailed)
        precondition(!blocked.rememberToday(image: first, name: "Pochi", replaceExisting: true, workoutPhoto: true))
        let retained = try Data(contentsOf: corruptURL)
        precondition(retained == bad)
        print("PASS: daily deduplication, workout-only photo gate and legacy hiding, chosen-photo protection, reload, original-file retention, date boundary, legacy archives, failed-write retention, corrupt-archive protection")
    }
}
