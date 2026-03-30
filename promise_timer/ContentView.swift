//
//  ContentView.swift
//  promise_timer
//
//  Created by 津守将弘 on 2026/03/15.
//

import SwiftUI
import AudioToolbox
import Combine
import StoreKit
import AppTrackingTransparency
#if canImport(UIKit)
import UIKit
#endif

fileprivate let ymdFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

fileprivate let logTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.timeZone = .current
    formatter.dateFormat = "H:mm"
    return formatter
}()

fileprivate let dayTitleFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.timeZone = .current
    formatter.dateFormat = "M月d日"
    return formatter
}()

fileprivate enum PresetTint: String, Codable, CaseIterable {
    case peach
    case sunshine
    case mintGreen
    case lavender
    case candyBlue

    var color: Color {
        switch self {
        case .peach: return .peach
        case .sunshine: return .sunshine
        case .mintGreen: return .mintGreen
        case .lavender: return .lavender
        case .candyBlue: return .candyBlue
        }
    }
}

fileprivate struct HabitPreset: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let minutes: Int?
    let iconName: String
    let tintName: PresetTint
    let isWriting: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        minutes: Int?,
        iconName: String,
        tintName: PresetTint,
        isWriting: Bool = false
    ) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.iconName = iconName
        self.tintName = tintName
        self.isWriting = isWriting
    }

    var tint: Color {
        tintName.color
    }

    var durationLabel: String {
        guard let minutes else { return "記録だけ" }
        return "\(minutes)分"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case minutes
        case iconName
        case tintName
        case isWriting
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes)
        iconName = try container.decode(String.self, forKey: .iconName)
        tintName = try container.decode(PresetTint.self, forKey: .tintName)
        isWriting = try container.decodeIfPresent(Bool.self, forKey: .isWriting) ?? false
    }
}

fileprivate struct HabitLog: Identifiable, Codable, Hashable {
    let id: String
    let presetID: String
    let title: String
    let minutes: Int?
    let actualMinutes: Int
    let completedAt: Date

    init(
        id: String = UUID().uuidString,
        presetID: String,
        title: String,
        minutes: Int?,
        actualMinutes: Int,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.title = title
        self.minutes = minutes
        self.actualMinutes = actualMinutes
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case presetID
        case title
        case minutes
        case actualMinutes
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        presetID = try container.decode(String.self, forKey: .presetID)
        title = try container.decode(String.self, forKey: .title)
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes)
        actualMinutes = try container.decodeIfPresent(Int.self, forKey: .actualMinutes) ?? minutes ?? 0
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }
}

fileprivate let defaultPresets: [HabitPreset] = [
    HabitPreset(id: "stretch", title: "ストレッチ", minutes: 1, iconName: "figure.run", tintName: .mintGreen),
    HabitPreset(id: "tidy", title: "片づけ", minutes: 1, iconName: "checkmark.circle.fill", tintName: .sunshine),
    HabitPreset(id: "bath", title: "お風呂", minutes: nil, iconName: "drop.fill", tintName: .peach)
]

fileprivate struct InitialPresetGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let presets: [HabitPreset]

    var previewText: String {
        presets.map { $0.title }.joined(separator: "、")
    }
}

fileprivate let initialPresetGroups: [InitialPresetGroup] = [
    InitialPresetGroup(
        id: "lighten",
        title: "心を軽くしたい",
        presets: [
            HabitPreset(id: "meditation", title: "瞑想", minutes: 1, iconName: "sparkles", tintName: .lavender),
            HabitPreset(id: "breathing", title: "深呼吸", minutes: 1, iconName: "wind", tintName: .mintGreen),
            HabitPreset(id: "good-things", title: "よかったこと書く", minutes: 1, iconName: "pencil.and.scribble", tintName: .sunshine, isWriting: true),
            HabitPreset(id: "gratitude", title: "感謝を書く", minutes: 1, iconName: "heart.fill", tintName: .peach, isWriting: true)
        ]
    ),
    InitialPresetGroup(
        id: "organize",
        title: "生活を整えたい",
        presets: [
            HabitPreset(id: "tidy-room", title: "片付ける", minutes: 1, iconName: "checkmark.circle.fill", tintName: .sunshine),
            HabitPreset(id: "clean", title: "掃除する", minutes: 1, iconName: "sparkles", tintName: .mintGreen),
            HabitPreset(id: "bath-time", title: "お風呂入る", minutes: nil, iconName: "drop.fill", tintName: .peach),
            HabitPreset(id: "journal", title: "日記書く", minutes: 1, iconName: "book.fill", tintName: .lavender, isWriting: true)
        ]
    ),
    InitialPresetGroup(
        id: "grow",
        title: "成長したい",
        presets: [
            HabitPreset(id: "goal", title: "今日の目標を書く", minutes: 1, iconName: "square.and.pencil", tintName: .sunshine, isWriting: true),
            HabitPreset(id: "reading", title: "読書", minutes: 1, iconName: "book.fill", tintName: .lavender),
            HabitPreset(id: "study", title: "勉強", minutes: 1, iconName: "pencil.and.scribble", tintName: .sunshine),
            HabitPreset(id: "review", title: "振り返りを書く", minutes: 1, iconName: "square.and.pencil", tintName: .candyBlue, isWriting: true)
        ]
    ),
    InitialPresetGroup(
        id: "body",
        title: "体を変えたい",
        presets: [
            HabitPreset(id: "stretching", title: "ストレッチ", minutes: 1, iconName: "figure.run", tintName: .mintGreen),
            HabitPreset(id: "exercise", title: "運動", minutes: 1, iconName: "figure.walk", tintName: .candyBlue),
            HabitPreset(id: "bath", title: "お風呂に入る", minutes: nil, iconName: "drop.fill", tintName: .peach),
            HabitPreset(id: "meal-log", title: "食事を記録する", minutes: 1, iconName: "fork.knife", tintName: .sunshine, isWriting: true)
        ]
    )
]

fileprivate let presetIcons: [String] = [
    "drop.fill",
    "pencil.and.scribble",
    "book.fill",
    "figure.run",
    "figure.walk",
    "checkmark.circle.fill",
    "cup.and.saucer.fill",
    "music.note",
    "sparkles",
    "leaf.fill",
    "moon.stars.fill",
    "wind",
    "heart.fill",
    "fork.knife",
    "square.and.pencil"
]

extension Color {
    static let candyBlue = Color(red: 0.16, green: 0.45, blue: 0.48)
    static let mintGreen = Color(red: 0.60, green: 0.78, blue: 0.67)
    static let sunshine = Color(red: 0.88, green: 0.68, blue: 0.24)
    static let peach = Color(red: 0.89, green: 0.55, blue: 0.45)
    static let lavender = Color(red: 0.66, green: 0.63, blue: 0.79)
    static let sky = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let cream = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let cocoa = Color(red: 0.29, green: 0.24, blue: 0.21)
    static let roseCloud = Color(red: 0.95, green: 0.86, blue: 0.82)
    static let mist = Color(red: 0.90, green: 0.93, blue: 0.90)
    static let grassEmpty = Color(red: 0.90, green: 0.88, blue: 0.84)
    static let grassLight = Color(red: 0.72, green: 0.84, blue: 0.72)
    static let grassDark = Color(red: 0.25, green: 0.54, blue: 0.36)
}

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @AppStorage("habitLogsStore") private var habitLogsStorage: String = ""
    @AppStorage("habitPresetsStore") private var habitPresetsStorage: String = ""
    @AppStorage("isSubscribed") private var isSubscribed: Bool = false
    @AppStorage("reviewActionCount") private var reviewActionCount: Int = 0
    @AppStorage("reviewFirstUseTime") private var reviewFirstUseTime: Double = 0
    @AppStorage("reviewLastRequestTime") private var reviewLastRequestTime: Double = 0
    @AppStorage("didRequestATT") private var didRequestATT: Bool = false
    @AppStorage("didSelectInitialPresets") private var didSelectInitialPresets: Bool = false
    @AppStorage("dailyNotesStore") private var dailyNotesStorage: String = ""

    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var habitPresets: [HabitPreset] = defaultPresets
    @State private var selectedPresetID: String = defaultPresets[0].id
    @State private var remainingSeconds: Int = 0
    @State private var timerRunning = false
    @State private var hasFinished = false
    @State private var showHanamaru = false
    @State private var selectedLogDate: Date = Date()
    @State private var celebrationDayCount: Int = 0
    @State private var celebrationStreak: Int = 0
    @State private var celebrationTitle: String = ""
    @State private var celebrationMinutesText: String = ""
    @State private var showingPresetEditor = false
    @State private var editingPreset: HabitPreset?
    @State private var draftPresetTitle = ""
    @State private var draftPresetMinutes = 0
    @State private var draftPresetTracksTime = true
    @State private var draftPresetIconName = presetIcons[0]
    @State private var draftPresetTint: PresetTint = .peach
    @State private var draftPresetIsWriting = false
    @State private var showingPaywall = false
    @State private var showingAddLogSheet = false
    @State private var showingInitialPresetPicker = false
    @State private var showingNoteSheet = false
    @State private var noteDraft = ""
    @State private var noteDate = Date()
    @State private var notePreset: HabitPreset?

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let calendar = Calendar(identifier: .gregorian)
    private var maxPresetCount: Int { isSubscribed ? 20 : 4 }
    private let reviewThreshold = 5
    private let reviewCooldownDays = 30

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                    HeroHeaderView(
                        streak: currentStreak,
                        activeDays: activeDayCount,
                        recentDays: recentDotDays,
                        completedDayKeys: Set(logsByDay.keys)
                    )

                    if let preset = selectedPreset {
                        if let minutes = preset.minutes {
                            CircularTimerView(
                                remainingSeconds: remainingSeconds,
                                totalSeconds: max(minutes * 60, 1),
                                isRunning: timerRunning,
                                accentColor: preset.tint
                            )
                            .frame(width: 216, height: 216)

                            Text("\(preset.title) を記録する")
                                .font(.headline)
                                .foregroundStyle(Color.cocoa)
                        } else {
                            InstantLogCard(preset: preset)
                        }
                    }

                    controlButtons

                    VStack(spacing: 10) {
                        HStack {
                            Text("やること")
                                .font(.headline)
                            Spacer()
                        }

                        PresetGridView(
                            presets: habitPresets,
                            selectedPresetID: selectedPresetID,
                            onSelect: selectPreset(_:),
                            onEdit: openEditPreset(_:),
                            onAdd: openAddPreset,
                            showsAddTile: habitPresets.count < maxPresetCount || !isSubscribed,
                            disabled: timerRunning
                        )

                    }

                    if !isSubscribed {
                        AdMobMRECView(adUnitID: "ca-app-pub-4731680416753736/7227046727")
                    }
                }
                .padding(14)
                .background(Color.cream.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.candyBlue.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.cocoa.opacity(0.08), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .navigationTitle("")
            .background(appBackground)
            }
            .tabItem { Label("ホーム", systemImage: "house.fill") }

            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                    HabitGrassCard(
                        days: grassDays,
                        selectedDate: selectedLogDate,
                        logsByDay: logsByDay,
                        onSelect: { selectedLogDate = $0 }
                    )

                    DayLogListCard(
                        date: selectedLogDate,
                        logs: logs(for: selectedLogDate),
                        noteText: noteText(for: selectedLogDate),
                        canAdd: canAddLog(for: selectedLogDate),
                        onAdd: { showingAddLogSheet = true },
                        onNote: { openNote(for: selectedLogDate, preset: nil) },
                        onDelete: deleteLog(_:)
                    )

                    if !isSubscribed {
                        AdMobMRECView(adUnitID: "ca-app-pub-4731680416753736/7227046727")
                    }

                }
                .padding(14)
                .background(Color.cream.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.candyBlue.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.cocoa.opacity(0.08), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .navigationTitle("")
            .background(appBackground)
            }
            .tabItem { Label("きろく", systemImage: "circle.grid.3x3.fill") }

            SettingsView(
                subscriptionManager: subscriptionManager
            )
            .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .onAppear {
            loadPresets()
            if habitPresetsStorage.isEmpty {
                showingInitialPresetPicker = !didSelectInitialPresets
            } else {
                didSelectInitialPresets = true
            }
            if let preset = selectedPreset {
                syncTimer(for: preset)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallSheet(
                subscriptionManager: subscriptionManager,
                isPresented: $showingPaywall
            )
        }
        .task {
            await subscriptionManager.start()
            isSubscribed = subscriptionManager.isSubscribed
            await requestTrackingAuthorizationIfNeeded()
        }
        .onChange(of: subscriptionManager.isSubscribed) { newValue in
            isSubscribed = newValue
        }
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorSheet(
                title: $draftPresetTitle,
                minutes: $draftPresetMinutes,
                tracksTime: $draftPresetTracksTime,
                iconName: $draftPresetIconName,
                tint: $draftPresetTint,
                isWriting: $draftPresetIsWriting,
                isEditing: editingPreset != nil,
                canDelete: editingPreset != nil,
                onSave: savePreset,
                onDelete: deletePreset,
                onCancel: {
                    showingPresetEditor = false
                }
            )
        }
        .sheet(isPresented: $showingAddLogSheet) {
            AddLogSheet(
                date: selectedLogDate,
                presets: habitPresets,
                onAdd: { preset in
                    addLog(for: preset, on: selectedLogDate)
                    showingAddLogSheet = false
                },
                onCancel: { showingAddLogSheet = false }
            )
        }
        .fullScreenCover(isPresented: $showingInitialPresetPicker) {
            InitialPresetPickerSheet(
                groups: initialPresetGroups,
                onSelect: { group in
                    habitPresets = group.presets
                    if let first = group.presets.first {
                        selectedPresetID = first.id
                    }
                    persistPresets()
                    didSelectInitialPresets = true
                    showingInitialPresetPicker = false
                }
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingNoteSheet) {
            DailyNoteSheet(
                date: noteDate,
                presetTitle: notePreset?.title,
                remainingSeconds: noteTimerRemainingSeconds,
                totalSeconds: noteTimerTotalSeconds,
                isRunning: timerRunning,
                text: $noteDraft,
                onClose: {
                    showingNoteSheet = false
                }
            )
            .onDisappear {
                saveNote(noteDraft, for: noteDate)
                notePreset = nil
            }
        }
        .onReceive(tick) { _ in
            guard timerRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                if remainingSeconds == 0 {
                    hasFinished = true
                    playEndSound()
                }
            } else {
                remainingSeconds -= 1
                hasFinished = true
            }
        }
        .fullScreenCover(isPresented: $showHanamaru) {
            CelebrationView(
                totalDays: celebrationDayCount,
                streakDays: celebrationStreak,
                title: celebrationTitle,
                minutesText: celebrationMinutesText
            ) {
                playButtonTapSound()
                closeCelebration()
            }
        }
        .tint(Color.candyBlue)
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color.cream, Color.roseCloud.opacity(0.65), Color.mist],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        guard !didRequestATT else { return }
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status == .notDetermined else {
                didRequestATT = true
                return
            }
            await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { _ in
                    didRequestATT = true
                    continuation.resume()
                }
            }
        } else {
            didRequestATT = true
        }
    }

    private var selectedPreset: HabitPreset? {
        habitPresets.first(where: { $0.id == selectedPresetID })
    }

    private var logs: [HabitLog] {
        guard let data = habitLogsStorage.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HabitLog].self, from: data)) ?? []
    }

    private var logsByDay: [String: [HabitLog]] {
        Dictionary(grouping: logs) { ymdFormatter.string(from: $0.completedAt) }
    }

    private var dailyNotes: [String: String] {
        guard let data = dailyNotesStorage.data(using: .utf8) else { return [:] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String: String].self, from: data)) ?? [:]
    }

    private var noteTimerRemainingSeconds: Int? {
        guard let preset = notePreset, preset.minutes != nil else { return nil }
        return remainingSeconds
    }

    private var noteTimerTotalSeconds: Int? {
        guard let preset = notePreset, let minutes = preset.minutes else { return nil }
        return max(minutes * 60, 1)
    }

    private var activeDayCount: Int {
        logsByDay.keys.count
    }

    private var currentStreak: Int {
        guard !logsByDay.isEmpty else { return 0 }
        var date = calendar.startOfDay(for: Date())
        var streak = 0

        while true {
            let key = ymdFormatter.string(from: date)
            if logsByDay[key] != nil {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = previous
            } else {
                break
            }
        }
        return streak
    }

    private var recentDotDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<10).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private var grassDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<56).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    @ViewBuilder
    private var controlButtons: some View {
        if let preset = selectedPreset {
            if preset.minutes == nil {
                Button {
                    playButtonTapSound()
                    if preset.isWriting {
                        openNote(for: Date(), preset: preset)
                    }
                    logCompletion(for: preset)
                } label: {
                    Text("できた")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(preset.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 4)
            } else if timerRunning {
                HStack(spacing: 12) {
                    Button {
                        playButtonTapSound()
                        logCompletion(for: preset)
                    } label: {
                        Text("できた")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(preset.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Button {
                        playButtonTapSound()
                        cancelTimer()
                    } label: {
                        Text("やめる")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.sky)
                            .foregroundStyle(Color.candyBlue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.candyBlue.opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 4)
            } else if hasFinished {
                HStack(spacing: 12) {
                    Button {
                        playButtonTapSound()
                        logCompletion(for: preset)
                    } label: {
                        Text("できた")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(preset.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Button {
                        playButtonTapSound()
                        cancelTimer()
                    } label: {
                        Text("やめる")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.sky)
                            .foregroundStyle(Color.candyBlue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.candyBlue.opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 4)
            } else {
                Button {
                    playButtonTapSound()
                    startTimer(for: preset)
                } label: {
                    Text("スタート")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .background(preset.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func selectPreset(_ preset: HabitPreset) {
        guard !timerRunning else { return }
        selectedPresetID = preset.id
        hasFinished = false
        syncTimer(for: preset)
    }

    private func openAddPreset() {
        if habitPresets.count >= maxPresetCount {
            if !isSubscribed {
                showingPaywall = true
            }
            return
        }
        editingPreset = nil
        draftPresetTitle = ""
        draftPresetMinutes = 5
        draftPresetTracksTime = true
        draftPresetIconName = presetIcons[0]
        draftPresetTint = .peach
        draftPresetIsWriting = false
        showingPresetEditor = true
    }

    private func openEditPreset(_ preset: HabitPreset) {
        editingPreset = preset
        draftPresetTitle = preset.title
        draftPresetMinutes = preset.minutes ?? 5
        draftPresetTracksTime = preset.minutes != nil
        draftPresetIconName = preset.iconName
        draftPresetTint = preset.tintName
        draftPresetIsWriting = preset.isWriting
        showingPresetEditor = true
    }

    private func savePreset() {
        let title = draftPresetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let minutes: Int? = draftPresetTracksTime ? min(max(draftPresetMinutes, 1), 15) : nil
        let preset = HabitPreset(
            id: editingPreset?.id ?? UUID().uuidString,
            title: title,
            minutes: minutes,
            iconName: draftPresetIconName,
            tintName: draftPresetTint,
            isWriting: draftPresetIsWriting
        )

        if let editingPreset,
           let index = habitPresets.firstIndex(where: { $0.id == editingPreset.id }) {
            habitPresets[index] = preset
        } else if habitPresets.count < maxPresetCount {
            habitPresets.append(preset)
        }

        persistPresets()
        selectedPresetID = preset.id
        syncTimer(for: preset)
        showingPresetEditor = false
    }

    private func deletePreset() {
        guard let editingPreset else { return }
        habitPresets.removeAll { $0.id == editingPreset.id }
        if habitPresets.isEmpty {
            habitPresetsStorage = ""
            didSelectInitialPresets = false
            selectedPresetID = ""
            showingPresetEditor = false
            showingInitialPresetPicker = true
            return
        }
        persistPresets()

        if selectedPresetID == editingPreset.id, let replacement = habitPresets.first {
            selectedPresetID = replacement.id
            syncTimer(for: replacement)
        }

        showingPresetEditor = false
    }

    private func startTimer(for preset: HabitPreset) {
        guard let minutes = preset.minutes else {
            logCompletion(for: preset)
            return
        }
        hasFinished = false
        showHanamaru = false
        remainingSeconds = minutes * 60
        timerRunning = true
        if preset.isWriting {
            openNote(for: Date(), preset: preset)
        }
    }

    private func cancelTimer() {
        timerRunning = false
        hasFinished = false
        if let preset = selectedPreset {
            syncTimer(for: preset)
        }
    }

    private func syncTimer(for preset: HabitPreset) {
        remainingSeconds = (preset.minutes ?? 0) * 60
    }

    private func logCompletion(for preset: HabitPreset) {
        timerRunning = false
        hasFinished = false
        let actualMinutes = completedMinutes(for: preset)

        let log = HabitLog(
            presetID: preset.id,
            title: preset.title,
            minutes: preset.minutes,
            actualMinutes: actualMinutes
        )

        var items = logs
        items.append(log)
        save(logs: items)
        maybeRequestReview()

        let completedDate = calendar.startOfDay(for: log.completedAt)
        selectedLogDate = completedDate
        celebrationDayCount = Dictionary(grouping: items) { ymdFormatter.string(from: $0.completedAt) }.keys.count
        celebrationStreak = calculateStreak(from: items)
        celebrationTitle = preset.title
        celebrationMinutesText = minutesText(for: log)
        showHanamaru = true
    }

    private func addLog(for preset: HabitPreset, on date: Date) {
        let completedAt = mergeDate(date, withTimeFrom: Date())
        let actualMinutes = preset.minutes ?? 0
        let log = HabitLog(
            presetID: preset.id,
            title: preset.title,
            minutes: preset.minutes,
            actualMinutes: actualMinutes,
            completedAt: completedAt
        )
        var items = logs
        items.append(log)
        save(logs: items)
        maybeRequestReview()
    }

    private func maybeRequestReview() {
        let now = Date()
        if reviewFirstUseTime == 0 {
            reviewFirstUseTime = now.timeIntervalSince1970
        }

        reviewActionCount += 1

        let firstUseDate = Date(timeIntervalSince1970: reviewFirstUseTime)
        let lastRequestDate = Date(timeIntervalSince1970: reviewLastRequestTime)
        let daysSinceFirstUse = calendar.dateComponents([.day], from: firstUseDate, to: now).day ?? 0
        let daysSinceLastRequest = reviewLastRequestTime == 0 ? reviewCooldownDays : (calendar.dateComponents([.day], from: lastRequestDate, to: now).day ?? 0)

        guard reviewActionCount >= reviewThreshold else { return }
        guard daysSinceFirstUse >= 1 else { return }
        guard daysSinceLastRequest >= reviewCooldownDays else { return }

        reviewLastRequestTime = now.timeIntervalSince1970
        reviewActionCount = 0
        requestReview()
    }

    private func canAddLog(for date: Date) -> Bool {
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return target <= today
    }

    private func mergeDate(_ date: Date, withTimeFrom timeSource: Date) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: calendar.startOfDay(for: date)) ?? date
    }

    private func calculateStreak(from logs: [HabitLog]) -> Int {
        let grouped = Dictionary(grouping: logs) { ymdFormatter.string(from: $0.completedAt) }
        guard !grouped.isEmpty else { return 0 }
        var date = calendar.startOfDay(for: Date())
        var streak = 0

        while true {
            let key = ymdFormatter.string(from: date)
            if grouped[key] != nil {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = previous
            } else {
                break
            }
        }

        return streak
    }

    private func save(logs: [HabitLog]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(logs),
              let string = String(data: data, encoding: .utf8) else { return }
        habitLogsStorage = string
    }

    private func loadPresets() {
        guard let data = habitPresetsStorage.data(using: .utf8) else {
            habitPresets = didSelectInitialPresets ? defaultPresets : []
            return
        }
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([HabitPreset].self, from: data), !items.isEmpty {
            habitPresets = Array(items.prefix(4))
        } else {
            habitPresets = didSelectInitialPresets ? defaultPresets : []
        }

        if !habitPresets.contains(where: { $0.id == selectedPresetID }), let first = habitPresets.first {
            selectedPresetID = first.id
        }
    }

    private func persistPresets() {
        guard !habitPresets.isEmpty else {
            habitPresetsStorage = ""
            return
        }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(habitPresets),
              let string = String(data: data, encoding: .utf8) else { return }
        habitPresetsStorage = string
    }

    private func noteText(for date: Date) -> String {
        let key = ymdFormatter.string(from: date)
        return dailyNotes[key] ?? ""
    }

    private func saveNote(_ text: String, for date: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = ymdFormatter.string(from: date)
        var notes = dailyNotes
        if trimmed.isEmpty {
            notes.removeValue(forKey: key)
        } else {
            notes[key] = text
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(notes),
              let string = String(data: data, encoding: .utf8) else { return }
        dailyNotesStorage = string
    }

    private func openNote(for date: Date, preset: HabitPreset?) {
        noteDate = date
        notePreset = preset
        noteDraft = noteText(for: date)
        showingNoteSheet = true
    }

    private func deleteLog(_ log: HabitLog) {
        let updatedLogs = logs.filter { $0.id != log.id }
        save(logs: updatedLogs)
    }

    private func logs(for date: Date) -> [HabitLog] {
        let key = ymdFormatter.string(from: date)
        return (logsByDay[key] ?? []).sorted { $0.completedAt > $1.completedAt }
    }

    private func closeCelebration() {
        showHanamaru = false
        if let preset = selectedPreset {
            syncTimer(for: preset)
        }
    }

    private func completedMinutes(for preset: HabitPreset) -> Int {
        guard let minutes = preset.minutes else { return 0 }
        let totalSeconds = minutes * 60
        let elapsedSeconds: Int

        if remainingSeconds >= 0 {
            elapsedSeconds = max(totalSeconds - remainingSeconds, 0)
        } else {
            elapsedSeconds = totalSeconds + abs(remainingSeconds)
        }

        guard elapsedSeconds > 0 else { return 0 }
        return Int(ceil(Double(elapsedSeconds) / 60.0))
    }

    private func minutesText(for log: HabitLog) -> String {
        if log.actualMinutes == 0 {
            return "記録だけ"
        }
        return "\(log.actualMinutes)分"
    }

    private func playButtonTapSound() {
        AudioServicesPlaySystemSound(1104)
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func playEndSound() {
        AudioServicesPlaySystemSound(1005)
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

private struct HeroHeaderView: View {
    let streak: Int
    let activeDays: Int
    let recentDays: [Date]
    let completedDayKeys: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("連続 \(streak) 日")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("できた日はドットで育つ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cocoa.opacity(0.62))
                }
                Spacer()
                Text("\(activeDays)日記録")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.sky)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ForEach(recentDays, id: \.self) { day in
                    Circle()
                        .fill(dotColor(for: day))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sky.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func dotColor(for day: Date) -> Color {
        let key = ymdFormatter.string(from: day)
        return completedDayKeys.contains(key) ? .grassDark : .grassEmpty
    }
}

private struct InstantLogCard: View {
    let preset: HabitPreset

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: preset.iconName)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(preset.tint)
            Text(preset.title)
                .font(.title3.bold())
                .foregroundStyle(Color.cocoa)
            Text("時間を決めずに、できたら記録")
                .font(.headline)
                .foregroundStyle(Color.cocoa.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.sky.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct PresetGridView: View {
    let presets: [HabitPreset]
    let selectedPresetID: String
    let onSelect: (HabitPreset) -> Void
    let onEdit: (HabitPreset) -> Void
    let onAdd: () -> Void
    let showsAddTile: Bool
    let disabled: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(presets) { preset in
                Button {
                    if !disabled { onSelect(preset) }
                } label: {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: preset.iconName)
                            .font(.system(size: 40, weight: .bold))
                        VStack(spacing: 4) {
                            Text(preset.title)
                                .font(.headline)
                            Text(preset.durationLabel)
                                .font(.subheadline.bold())
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 152)
                    .padding(12)
                    .background(selectedPresetID == preset.id ? preset.tint : Color.sky.opacity(0.82))
                    .foregroundStyle(selectedPresetID == preset.id ? Color.white : Color.cocoa)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(selectedPresetID == preset.id ? preset.tint : Color.candyBlue.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .overlay(alignment: .topTrailing) {
                    Button {
                        if !disabled { onEdit(preset) }
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(selectedPresetID == preset.id ? .white.opacity(0.95) : Color.candyBlue)
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .padding(4)
                }
            }

            if showsAddTile {
                Button(action: onAdd) {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40, weight: .bold))
                        VStack(spacing: 4) {
                            Text("ついか")
                                .font(.headline)
                            Text("やること")
                                .font(.subheadline.bold())
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 152)
                    .padding(12)
                    .background(Color.sky.opacity(0.82))
                    .foregroundStyle(Color.candyBlue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.candyBlue.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
    }
}

private struct InitialPresetPickerSheet: View {
    let groups: [InitialPresetGroup]
    let onSelect: (InitialPresetGroup) -> Void
    @State private var selectedGroupID: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("最初にえらんでね")
                    .font(.title3.bold())
                    .foregroundStyle(Color.cocoa)

                Text("やりたい方向を1つえらぶと、最初のやることがセットされるよ。")
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa.opacity(0.7))

                ForEach(groups) { group in
                    Button {
                        selectedGroupID = group.id
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.headline)
                                .foregroundStyle(selectedGroupID == group.id ? .white : Color.cocoa)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(selectedGroupID == group.id ? Color.candyBlue : Color.sky.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    guard let selectedGroupID,
                          let group = groups.first(where: { $0.id == selectedGroupID }) else { return }
                    onSelect(group)
                } label: {
                    Text("けってい")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.candyBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selectedGroupID == nil)
                .opacity(selectedGroupID == nil ? 0.45 : 1)
            }
            .padding(20)
            .navigationTitle("")
        }
    }
}

private struct PresetEditorSheet: View {
    @State private var showingDeleteConfirmation = false
    @Binding var title: String
    @Binding var minutes: Int
    @Binding var tracksTime: Bool
    @Binding var iconName: String
    @Binding var tint: PresetTint
    @Binding var isWriting: Bool
    let isEditing: Bool
    let canDelete: Bool
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("やることのなまえ")
                            .font(.headline)

                        TextField("やること", text: $title)
                            .textFieldStyle(.roundedBorder)

                        Toggle("時間をはかる", isOn: $tracksTime)
                        Toggle("ノートを使う", isOn: $isWriting)

                        if tracksTime {
                            Stepper("\(minutes)分", value: $minutes, in: 1...15)
                                .padding(12)
                                .background(Color.sky.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("アイコン")
                            .font(.headline)
                        let iconColumns = [
                            GridItem(.adaptive(minimum: 56), spacing: 12)
                        ]
                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(presetIcons, id: \.self) { icon in
                                Button {
                                    iconName = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 26, weight: .semibold))
                                        .frame(width: 56, height: 56)
                                        .background(iconName == icon ? Color.candyBlue : Color.sky.opacity(0.72))
                                        .foregroundStyle(iconName == icon ? Color.white : Color.candyBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("いろ")
                            .font(.headline)
                        let colorColumns = [
                            GridItem(.adaptive(minimum: 56), spacing: 12)
                        ]
                        LazyVGrid(columns: colorColumns, spacing: 12) {
                            ForEach(PresetTint.allCases, id: \.self) { option in
                                Button {
                                    tint = option
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 40, height: 40)
                                        .padding(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(tint == option ? Color.cocoa : Color.clear, lineWidth: 2)
                                        )
                                        .frame(width: 56, height: 56)
                                        .background(Color.sky.opacity(0.72))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        if isEditing {
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                Text("けす")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Color.peach)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(!canDelete)
                            .opacity(canDelete ? 1 : 0.45)
                        }

                        Button(action: onSave) {
                            Text("ほぞん")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.candyBlue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    }
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? "やることをへんしゅう" : "やることをついか")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる", action: onCancel)
                }
            }
            .alert("やることをけす？", isPresented: $showingDeleteConfirmation) {
                Button("キャンセル", role: .cancel) {}
                Button("けす", role: .destructive, action: onDelete)
            } message: {
                Text("このやることは元にもどせません。")
            }
        }
    }

}

private struct HabitGrassCard: View {
    let days: [Date]
    let selectedDate: Date
    let logsByDay: [String: [HabitLog]]
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("できた日")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { label in
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(Color.cocoa.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let count = logsByDay[ymdFormatter.string(from: day)]?.count ?? 0
                    Button {
                        onSelect(day)
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fillColor(count: count, selected: isSameDay(day, selectedDate)))
                            .frame(height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSameDay(day, selectedDate) ? Color.cocoa.opacity(0.35) : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(dayTitleFormatter.string(from: day))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sky.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func fillColor(count: Int, selected: Bool) -> Color {
        let base: Color
        switch count {
        case 0:
            base = .grassEmpty
        case 1:
            base = .grassLight
        default:
            base = .grassDark
        }
        return selected ? base.opacity(0.95) : base
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        ymdFormatter.string(from: lhs) == ymdFormatter.string(from: rhs)
    }
}

private struct DayLogListCard: View {
    @State private var pendingDeleteLog: HabitLog?
    let date: Date
    let logs: [HabitLog]
    let noteText: String
    let canAdd: Bool
    let onAdd: () -> Void
    let onNote: () -> Void
    let onDelete: (HabitLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(dayTitleFormatter.string(from: date)) のきろく")
                    .font(.headline)
                Spacer()
                if canAdd {
                    Button("追加") {
                        onAdd()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.candyBlue)
                }
            }

            if logs.isEmpty {
                Text("まだ記録がないよ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cocoa.opacity(0.6))
            } else {
                ForEach(logs) { log in
                    HStack {
                        Text(logTimeFormatter.string(from: log.completedAt))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.cocoa.opacity(0.7))
                            .frame(width: 52, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.title)
                                .font(.headline)
                        }
                        Spacer()
                        Text(minutesText(for: log))
                            .font(.caption.bold())
                            .foregroundStyle(Color.candyBlue)
                        Button {
                            pendingDeleteLog = log
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.peach)
                                .padding(.leading, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                onNote()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ノート")
                            .font(.headline)
                            .foregroundStyle(Color.cocoa)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.candyBlue)
                    }
                    if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("まだノートがないよ")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.cocoa.opacity(0.6))
                    } else {
                        Text(noteText)
                            .font(.subheadline)
                            .foregroundStyle(Color.cocoa.opacity(0.75))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.cream.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.45)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sky.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .alert("この記録をけす？", isPresented: Binding(
            get: { pendingDeleteLog != nil },
            set: { if !$0 { pendingDeleteLog = nil } }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("けす", role: .destructive) {
                if let log = pendingDeleteLog {
                    onDelete(log)
                    pendingDeleteLog = nil
                }
            }
        } message: {
            Text("この実績は元にもどせません。")
        }
    }

    private func minutesText(for log: HabitLog) -> String {
        if log.actualMinutes == 0 {
            return "記録だけ"
        }
        return "\(log.actualMinutes)分"
    }
}

private struct AddLogSheet: View {
    let date: Date
    let presets: [HabitPreset]
    let onAdd: (HabitPreset) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(dayTitleFormatter.string(from: date)) に追加")
                    .font(.headline)

                ForEach(presets) { preset in
                    Button {
                        onAdd(preset)
                    } label: {
                        HStack {
                            Image(systemName: preset.iconName)
                                .font(.headline)
                                .foregroundStyle(preset.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title)
                                    .font(.headline)
                                Text(preset.durationLabel)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.candyBlue)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.candyBlue)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.sky.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる", action: onCancel)
                }
            }
        }
    }
}

private struct DailyNoteSheet: View {
    let date: Date
    let presetTitle: String?
    let remainingSeconds: Int?
    let totalSeconds: Int?
    let isRunning: Bool
    @Binding var text: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(dayTitleFormatter.string(from: date))
                    .font(.headline)
                    .foregroundStyle(Color.cocoa)

                if let presetTitle {
                    Text(presetTitle)
                        .font(.title3.bold())
                        .foregroundStyle(Color.candyBlue)
                }

                if let totalSeconds {
                    let displaySeconds = isRunning ? (remainingSeconds ?? totalSeconds) : totalSeconds
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        Text(formattedTime(displaySeconds))
                            .monospacedDigit()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.cocoa)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.sky.opacity(0.8))
                    .clipShape(Capsule())
                }

                TextEditor(text: $text)
                    .frame(minHeight: 240)
                    .padding(10)
                    .background(Color.cream.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.candyBlue.opacity(0.15), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(20)
            .navigationTitle("ノート")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", action: onClose)
                }
            }
        }
    }

    private func formattedTime(_ total: Int) -> String {
        let value = max(total, 0)
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


private struct CelebrationView: View {
    let totalDays: Int
    let streakDays: Int
    let title: String
    let minutesText: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sunshine.opacity(0.88), Color.roseCloud, Color.cream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Group {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(named: "hanamaru") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .blendMode(.multiply)
                            .compositingGroup()
                    } else {
                        Text("💮")
                            .font(.system(size: 172))
                    }
                    #else
                    Text("💮")
                        .font(.system(size: 172))
                    #endif
                }
                .frame(width: 260, height: 260)

                Text("できた！")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.candyBlue)

                VStack(spacing: 8) {
                    Text("\(title) ・ \(minutesText)")
                        .font(.title3.bold())
                        .foregroundStyle(Color.candyBlue)
                    Text("\(totalDays)日目の記録")
                        .font(.title3.bold())
                    Text("連続 \(streakDays) 日")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Color.peach)
                }
                .foregroundStyle(Color.cocoa)

                Spacer()

                Button(action: onClose) {
                    Text("とじる")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.candyBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}


private struct CircularTimerView: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let isRunning: Bool
    let accentColor: Color

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(max(min(remainingSeconds, totalSeconds), 0)) / Double(totalSeconds)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.14), lineWidth: 16)

            Circle()
                .trim(from: 0, to: 1 - progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(0.2), radius: 8, x: 0, y: 4)

            VStack(spacing: 6) {
                Text(displayTimeString(from: remainingSeconds))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.cocoa)

                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(accentColor)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: progress)
    }

    private var statusText: String {
        if isRunning && remainingSeconds <= 0 {
            return "おわっても続けてる"
        }
        return isRunning ? "ちょいだけ集中" : "じゅんびOK"
    }

    private func displayTimeString(from total: Int) -> String {
        let value = abs(total)
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
