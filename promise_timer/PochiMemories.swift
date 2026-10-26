import SwiftUI
import UIKit
import Combine

struct PochiStory: Identifiable {
    let activity: PochiRoomActivity
    let stage: Int
    let title: String
    var id: String { "\(activity.rawValue)-\(stage)" }
    var days: Int { [PochiGrowthPolicy.first, PochiGrowthPolicy.playful, PochiGrowthPolicy.favorite][stage] }
    static let all: [Self] = (0..<3).flatMap { stage in
        [Self(activity: .exercise, stage: stage, title: ["ごきげんなしっぽ", "あそぼうよ", "得意なジャンプ"][stage]),
         Self(activity: .sleep, stage: stage, title: ["お気に入りのクッション", "ねむる準備", "安心して、すやすや"][stage])]
    }
}

struct PochiMemory: Codable, Identifiable {
    let id: String
    let date: Date
    let dogName: String
    var isUserPhoto: Bool? = nil
    var isWorkoutPhoto: Bool? = nil
}

/// Separate, additive storage. Existing habit/profile stores are never rewritten.
@MainActor final class PochiMemoryStore: ObservableObject {
    private struct Archive: Codable {
        var unlocked: Set<String> = []
        var memories: [PochiMemory] = []
        var dailyPhotos: [PochiMemory]? = nil
    }
    @Published private var archive = Archive()
    @Published private(set) var saveFailed = false
    private let directory: URL?
    private var writable = true
    var memories: [PochiMemory] { [] }
    var dailyPhotos: [PochiMemory] { (archive.dailyPhotos ?? []).filter { $0.isWorkoutPhoto == true } }
    func representativePhoto(on date: Date, calendar: Calendar) -> PochiMemory? {
        dailyPhotos.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    func pendingStory(among activities: [PochiRoomActivity] = [.exercise, .sleep]) -> PochiStory? {
        for activity in activities {
            if let story = PochiStory.all.first(where: { story in
                story.activity == activity && archive.unlocked.contains(story.id)
                    && !archive.memories.contains { $0.id == story.id }
            }) { return story }
        }
        return nil
    }
    init(directory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("PochiMemories", isDirectory: true)) {
        self.directory = directory
        guard let directory else { writable = false; return }
        let url = directory.appendingPathComponent("archive.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do { archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url)) }
            catch { writable = false; saveFailed = true }
        }
    }
    private func persist(_ updated: Archive) -> Bool {
        guard writable, let directory else { saveFailed = true; return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("archive.json"), options: .atomic)
            archive = updated
            saveFailed = false
            return true
        } catch { saveFailed = true; return false }
    }
    func discover(_ habits: PochiLifeHabits) {
        var updated = archive
        for story in PochiStory.all where habits.days(for: story.activity) >= story.days {
            updated.unlocked.insert(story.id)
        }
        if updated.unlocked != archive.unlocked { _ = persist(updated) }
    }
    func remember(_ story: PochiStory, image: UIImage, name: String) {
        guard !archive.memories.contains(where: { $0.id == story.id }), writable,
              let directory, let data = image.pngData() else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(story.id + ".png"), options: .atomic)
            var updated = archive
            updated.memories.append(PochiMemory(id: story.id, date: Date(), dogName: name))
            _ = persist(updated)
        } catch { saveFailed = true }
    }
    /// Only today's scene can be photographed. Never fabricate a photo for backfilled days.
    func rememberToday(image: UIImage, name: String, date: Date = Date(), replaceExisting: Bool = false, workoutPhoto: Bool = false) -> Bool {
        guard workoutPhoto else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard calendar.isDateInToday(date) else { return false }
        if !replaceExisting, dailyPhotos.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) { return true }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // A unique file keeps the previous photo intact if saving the archive fails.
        let id = "daily-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)-\(UUID().uuidString)"
        guard writable, let directory, let data = image.pngData() else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(id + ".png"), options: .atomic)
            var updated = archive
            updated.dailyPhotos = dailyPhotos.filter { !calendar.isDate($0.date, inSameDayAs: date) }
                + [PochiMemory(id: id, date: date, dogName: name, isUserPhoto: replaceExisting, isWorkoutPhoto: true)]
            return persist(updated)
        } catch { saveFailed = true; return false }
    }

    func image(for memory: PochiMemory) -> UIImage? {
        guard let directory else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(memory.id + ".png").path)
    }
}

struct PochiAlbumAchievement: Identifiable {
    let id: String
    let title: String
    let icon: PochiPixelIconKind
}

/// The same day's representative photo is used in both the calendar and album.
struct PochiDayMoment: View {
    @ObservedObject var store: PochiMemoryStore
    let date: Date
    let achievements: [PochiAlbumAchievement]
    @State private var showingShare = false
    private var photo: PochiMemory? {
        guard !achievements.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return store.representativePhoto(on: date, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この日のぽち").font(pochiPixelFont(16))
            if let photo, let image = store.image(for: photo) {
                Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(photo.dogName)
                Button { showingShare = true } label: {
                    HStack(spacing: 8) {
                        PochiPixelGlyph(kind: .share, color: .grassDark)
                        Text("写真をシェア").font(pochiPixelFont(14))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    PochiPixelGlyph(kind: .camera, color: .grassDark)
                    Text("この日の写真はまだありません").font(pochiPixelFont(13))
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(minHeight: 44)
            }
            if store.saveFailed {
                Text("思い出を保存できませんでした。").font(pochiPixelFont(13))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.cocoa)
            .sheet(isPresented: $showingShare) {
                if let photo, let image = store.image(for: photo) {
                    PochiDailyMemoryShare(photo: image, name: photo.dogName, date: date,
                        photoID: photo.id, achievements: achievements)
                }
            }
            .onChange(of: date) { _ in showingShare = false }
    }
}

private struct PochiAlbumDay: Identifiable {
    let date: Date
    let logs: [HabitLog]
    let stories: [PochiMemory]
    let photo: PochiMemory?
    var id: Date { date }
}

struct PochiMemoryAlbum: View {
    @ObservedObject var store: PochiMemoryStore
    let logs: [HabitLog]
    let achievement: (HabitLog) -> PochiAlbumAchievement
    @Environment(\.dismiss) private var dismiss
    @State private var sharingDate: Date?
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = .current
        return value
    }
    private var days: [PochiAlbumDay] {
        let records = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.completedAt) }
        let stories = Dictionary(grouping: store.memories) { calendar.startOfDay(for: $0.date) }
        return Set(records.keys).sorted(by: >).map { date in
            let moments = (stories[date] ?? []).sorted { $0.date > $1.date }
            return PochiAlbumDay(date: date,
                logs: (records[date] ?? []).sorted { $0.completedAt == $1.completedAt ? $0.id < $1.id : $0.completedAt < $1.completedAt },
                stories: moments, photo: store.representativePhoto(on: date, calendar: calendar))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    if days.isEmpty {
                        PochiPixelGlyph(kind: .book, color: .grassDark, size: 48)
                        Text("ぽちとの思い出は、ここに。").font(pochiPixelFont(17))
                        Text("今日の筋トレも、ぽちと一緒に。")
                            .font(pochiPixelFont(14)).multilineTextAlignment(.center)
                    }
                    if store.saveFailed {
                        Text("思い出を保存できませんでした。").font(pochiPixelFont(14))
                    }
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(day.date, format: .dateTime.year().month().day()).font(pochiPixelFont(15))
                            if let photo = day.photo, let image = store.image(for: photo) {
                                Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 340)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityLabel(photo.dogName)
                                Button { sharingDate = day.date } label: {
                                    HStack { PochiPixelGlyph(kind: .share); Text("写真をシェア") }.frame(minHeight: 44)
                                }
                            } else {
                                HStack {
                                    PochiPixelGlyph(kind: .camera, color: .grassDark)
                                    Text("この日の写真はまだありません").font(pochiPixelFont(13))
                                }.frame(minHeight: 60)
                            }
                            ForEach(day.stories) { memory in
                                if let story = PochiStory.all.first(where: { $0.id == memory.id }) {
                                    Text(localizedText(story.title)).font(pochiPixelFont(16))
                                }
                            }
                            Text("今日の筋トレ").font(pochiPixelFont(16))
                            if day.logs.isEmpty {
                                Text("この日の記録はありません").font(pochiPixelFont(13))
                            }
                            ForEach(day.logs) { log in
                                PochiAlbumAchievementRow(item: achievement(log))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(Color.grassDark.opacity(0.2))
                    }
                }.padding(20)
            }.background(Color.cream).foregroundStyle(Color.cocoa)
                .navigationTitle(localizedText("ぽちの思い出")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
                .sheet(isPresented: Binding(get: { sharingDate != nil }, set: { if !$0 { sharingDate = nil } })) {
                    if let date = sharingDate, let day = days.first(where: { $0.date == date }),
                       let photo = day.photo, let image = store.image(for: photo) {
                        PochiDailyMemoryShare(photo: image, name: photo.dogName, date: date,
                            photoID: photo.id, achievements: day.logs.map(achievement))
                    } else {
                        Text("この日の記録はありません").padding()
                    }
                }
        }
    }
}

private struct PochiAlbumAchievementRow: View {
    let item: PochiAlbumAchievement
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PochiPixelGlyph(kind: item.icon, color: .grassDark, size: 24).accessibilityHidden(true)
            Text(item.title).font(pochiPixelFont(14)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            PochiPixelGlyph(kind: .check, color: .grassDark, size: 16).accessibilityHidden(true)
        }
    }
}

struct PochiDailyMemoryShare: View {
    let photo: UIImage
    let name: String
    let date: Date
    let photoID: String
    let achievements: [PochiAlbumAchievement]
    @Environment(\.dismiss) private var dismiss
    @State private var includeAchievements = false
    @State private var rendered: UIImage?
    @State private var renderedKey = ""
    private var renderKey: String {
        "\(includeAchievements)-\(photoID)-\(name)-\(date.timeIntervalSince1970)-" + achievements.map { $0.id + $0.title }.joined(separator: "|")
    }
    private var card: some View {
        VStack(spacing: 12) {
            Text(name).font(pochiPixelFont(20))
            Image(uiImage: photo).resizable().interpolation(.none).scaledToFit().frame(width: 264, height: 352)
            Text(date, format: .dateTime.year().month().day()).font(pochiPixelFont(13))
            if includeAchievements {
                Text("今日の筋トレ").font(pochiPixelFont(16))
                ForEach(Array(achievements.prefix(30))) { item in PochiAlbumAchievementRow(item: item) }
                if achievements.count > 30 {
                    Text(localizedFormat("ほか%lldこ", achievements.count - 30)).font(pochiPixelFont(14))
                }
            }
            Text("ぽちログ").font(pochiPixelFont(12))
        }.padding(20).frame(width: 304).foregroundStyle(Color.cocoa).background(Color.cream)
            .environment(\.dynamicTypeSize, .medium)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Toggle("できたことも写真に入れる", isOn: $includeAchievements).font(pochiPixelFont(14))
                    if let rendered, renderedKey == renderKey {
                        Image(uiImage: rendered).resizable().interpolation(.none).scaledToFit()
                        ShareLink(item: Image(uiImage: rendered), preview: SharePreview(name, image: Image(uiImage: rendered))) {
                            HStack { PochiPixelGlyph(kind: .share); Text("写真をシェア") }.frame(minHeight: 44)
                        }
                    } else if renderedKey == renderKey {
                        Text("写真を作成できませんでした").font(pochiPixelFont(14))
                    } else {
                        ProgressView()
                    }
                }.padding(20)
            }.background(Color.cream)
                .navigationTitle(localizedText("写真をシェア")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
                .task(id: renderKey) {
                    rendered = nil
                    let renderer = ImageRenderer(content: card)
                    renderer.scale = 2
                    rendered = renderer.uiImage
                    renderedKey = renderKey
                }
        }
    }
}
