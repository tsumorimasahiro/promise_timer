//
//  ContentView.swift
//  promise_timer
//
//  Created by 津守将弘 on 2026/03/15.
//

import SwiftUI
import AudioToolbox
import StoreKit
import AppTrackingTransparency
import WidgetKit
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

fileprivate let appGroupID = "group.com.tsumori.promise_timer"
fileprivate let appGroupDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

fileprivate struct HabitPreset: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let tintName: PresetTint

    init(
        id: String = UUID().uuidString,
        title: String,
        iconName: String,
        tintName: PresetTint
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.tintName = tintName
    }

    var tint: Color {
        tintName.color
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconName
        case tintName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        iconName = try container.decode(String.self, forKey: .iconName)
        tintName = try container.decode(PresetTint.self, forKey: .tintName)
    }
}

fileprivate struct HabitLog: Identifiable, Codable, Hashable {
    let id: String
    let presetID: String
    let title: String
    let completedAt: Date

    init(
        id: String = UUID().uuidString,
        presetID: String,
        title: String,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.title = title
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case presetID
        case title
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        presetID = try container.decode(String.self, forKey: .presetID)
        title = try container.decode(String.self, forKey: .title)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }
}

fileprivate let defaultPresets: [HabitPreset] = [
    HabitPreset(id: "stretch", title: "ストレッチ", iconName: "figure.run", tintName: .mintGreen),
    HabitPreset(id: "tidy", title: "片づけ", iconName: "checkmark.circle.fill", tintName: .sunshine),
    HabitPreset(id: "bath", title: "お風呂", iconName: "bath", tintName: .peach)
]

fileprivate let initialSelectablePresets: [HabitPreset] = [
    HabitPreset(id: "study", title: "勉強", iconName: "study", tintName: .sunshine),
    HabitPreset(id: "reading", title: "読書", iconName: "book", tintName: .lavender),
    HabitPreset(id: "exercise", title: "運動", iconName: "run", tintName: .candyBlue),
    HabitPreset(id: "clean", title: "掃除", iconName: "clean", tintName: .mintGreen),
    HabitPreset(id: "bath", title: "お風呂", iconName: "bath", tintName: .peach),
    HabitPreset(id: "breakfast", title: "朝ごはん", iconName: "eat", tintName: .sunshine)
]

fileprivate let presetIcons: [String] = [
    "study",
    "book",
    "run",
    "clean",
    "bath",
    "eat"
]

fileprivate let customIconNames: Set<String> = [
    "study",
    "book",
    "run",
    "clean",
    "bath",
    "eat"
]

fileprivate let customIconMapByID: [String: String] = [
    "study": "study",
    "reading": "book",
    "exercise": "run",
    "clean": "clean",
    "bath": "bath",
    "bath-time": "bath",
    "breakfast": "eat"
]

fileprivate let customIconMapByTitle: [String: String] = [
    "勉強": "study",
    "読書": "book",
    "運動": "run",
    "掃除": "clean",
    "お風呂": "bath",
    "お風呂入る": "bath",
    "お風呂に入る": "bath",
    "朝ごはん": "eat",
    "朝ご飯": "eat"
]

fileprivate struct PresetIconView: View {
    let name: String
    let size: CGFloat
    let tint: Color?

    var body: some View {
        if customIconNames.contains(name) {
            Image(name)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(tint ?? Color.cocoa)
        }
    }
}

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
    @AppStorage("habitLogsStore", store: appGroupDefaults) private var habitLogsStorage: String = ""
    @AppStorage("habitPresetsStore", store: appGroupDefaults) private var habitPresetsStorage: String = ""
    @AppStorage("isSubscribed") private var isSubscribed: Bool = false
    @AppStorage("reviewActionCount") private var reviewActionCount: Int = 0
    @AppStorage("reviewFirstUseTime") private var reviewFirstUseTime: Double = 0
    @AppStorage("reviewLastRequestTime") private var reviewLastRequestTime: Double = 0
    @AppStorage("didRequestATT") private var didRequestATT: Bool = false
    @AppStorage("didSelectInitialPresets") private var didSelectInitialPresets: Bool = false
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var habitPresets: [HabitPreset] = defaultPresets
    @State private var selectedPresetID: String = defaultPresets[0].id
    @State private var selectedLogDate: Date = Date()
    @State private var expandedPresetID: String?
    @State private var isFlipped = false
    @State private var isCompleting = false
    @State private var showingPresetEditor = false
    @State private var editingPreset: HabitPreset?
    @State private var draftPresetTitle = ""
    @State private var draftPresetIconName = presetIcons[0]
    @State private var draftPresetTint: PresetTint = .peach
    @State private var showingPaywall = false
    @State private var showingAddLogSheet = false
    @State private var showingInitialPresetPicker = false

    private let calendar = Calendar(identifier: .gregorian)
    private var maxPresetCount: Int { isSubscribed ? 20 : 6 }
    private let reviewThreshold = 5
    private let reviewCooldownDays = 30

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                    WeeklyDotsCard(
                        days: currentWeekDays,
                        logsByDay: logsByDay
                    )

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
                            disabled: false,
                            completedPresetIDsToday: completedPresetIDsToday
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
                        iconForLog: iconForLog(_:),
                        canAdd: canAddLog(for: selectedLogDate),
                        onAdd: { showingAddLogSheet = true },
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
            migrateDefaultsToAppGroupIfNeeded()
            loadPresets()
            if habitPresetsStorage.isEmpty {
                showingInitialPresetPicker = !didSelectInitialPresets
            } else {
                didSelectInitialPresets = true
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
                iconName: $draftPresetIconName,
                tint: $draftPresetTint,
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
                presets: initialSelectablePresets,
                onSelect: { selected in
                    habitPresets = selected
                    if let first = selected.first {
                        selectedPresetID = first.id
                    }
                    persistPresets()
                    didSelectInitialPresets = true
                    showingInitialPresetPicker = false
                },
                onSkip: {
                    habitPresets = defaultPresets
                    if let first = defaultPresets.first {
                        selectedPresetID = first.id
                    }
                    persistPresets()
                    didSelectInitialPresets = true
                    showingInitialPresetPicker = false
                }
            )
            .interactiveDismissDisabled(true)
        }
        .tint(Color.candyBlue)
        .overlay(expandedPresetOverlay)
        .onOpenURL { url in
            handleWidgetURL(url)
        }
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

    private var presetByID: [String: HabitPreset] {
        Dictionary(uniqueKeysWithValues: habitPresets.map { ($0.id, $0) })
    }

    private var expandedPreset: HabitPreset? {
        guard let expandedPresetID else { return nil }
        return habitPresets.first(where: { $0.id == expandedPresetID })
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

    private var completedPresetIDsToday: Set<String> {
        let key = ymdFormatter.string(from: Date())
        let ids = (logsByDay[key] ?? []).map(\.presetID)
        return Set(ids)
    }

    private var activeDayCount: Int {
        logsByDay.keys.count
    }

    private var currentWeekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
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
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let start = calendar.date(byAdding: .day, value: -49, to: startOfWeek) ?? today
        return (0..<56).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func selectPreset(_ preset: HabitPreset) {
        selectedPresetID = preset.id
        expandedPresetID = preset.id
        isFlipped = false
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
        draftPresetIconName = presetIcons[0]
        draftPresetTint = .peach
        showingPresetEditor = true
    }

    private func openEditPreset(_ preset: HabitPreset) {
        editingPreset = preset
        draftPresetTitle = preset.title
        draftPresetIconName = preset.iconName
        draftPresetTint = preset.tintName
        showingPresetEditor = true
    }

    private func savePreset() {
        let title = draftPresetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let preset = HabitPreset(
            id: editingPreset?.id ?? UUID().uuidString,
            title: title,
            iconName: draftPresetIconName,
            tintName: draftPresetTint
        )

        if let editingPreset,
           let index = habitPresets.firstIndex(where: { $0.id == editingPreset.id }) {
            habitPresets[index] = preset
        } else if habitPresets.count < maxPresetCount {
            habitPresets.append(preset)
        } else if !isSubscribed {
            showingPaywall = true
            showingPresetEditor = false
            return
        }

        persistPresets()
        selectedPresetID = preset.id
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
        }

        showingPresetEditor = false
    }

    private func logCompletion(for preset: HabitPreset) {
        let log = HabitLog(
            presetID: preset.id,
            title: preset.title
        )

        var items = logs
        items.append(log)
        save(logs: items)
        maybeRequestReview()

        let completedDate = calendar.startOfDay(for: log.completedAt)
        selectedLogDate = completedDate
    }

    private func addLog(for preset: HabitPreset, on date: Date) {
        let completedAt = mergeDate(date, withTimeFrom: Date())
        let log = HabitLog(
            presetID: preset.id,
            title: preset.title,
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

    private func save(logs: [HabitLog]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(logs),
              let string = String(data: data, encoding: .utf8) else { return }
        habitLogsStorage = string
        WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadPresets() {
        guard let data = habitPresetsStorage.data(using: .utf8) else {
            habitPresets = didSelectInitialPresets ? defaultPresets : []
            return
        }
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([HabitPreset].self, from: data), !items.isEmpty {
            let limited = Array(items.prefix(maxPresetCount))
            let migrated = migratePresetIcons(in: limited)
            habitPresets = migrated
            if migrated != limited {
                persistPresets()
            }
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

    private func migratePresetIcons(in presets: [HabitPreset]) -> [HabitPreset] {
        presets.map { preset in
            if customIconNames.contains(preset.iconName) {
                return preset
            }
            if let iconName = customIconMapByID[preset.id] ?? customIconMapByTitle[preset.title] {
                return HabitPreset(
                    id: preset.id,
                    title: preset.title,
                    iconName: iconName,
                    tintName: preset.tintName
                )
            }
            return preset
        }
    }

    private func migrateDefaultsToAppGroupIfNeeded() {
        let standard = UserDefaults.standard

        if habitPresetsStorage.isEmpty, let legacyPresets = standard.string(forKey: "habitPresetsStore") {
            habitPresetsStorage = legacyPresets
        }

        if habitLogsStorage.isEmpty, let legacyLogs = standard.string(forKey: "habitLogsStore") {
            habitLogsStorage = legacyLogs
        }
    }

    private func iconForLog(_ log: HabitLog) -> (name: String, tint: Color) {
        if let preset = presetByID[log.presetID] {
            return (preset.iconName, preset.tint)
        }
        if let iconName = customIconMapByID[log.presetID] ?? customIconMapByTitle[log.title] {
            return (iconName, .candyBlue)
        }
        return ("checkmark.circle.fill", .candyBlue)
    }

    private var expandedPresetOverlay: some View {
        Group {
            if let preset = expandedPreset {
                ZStack {
                    Color.cream
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeExpanded()
                        }

                    VStack(spacing: 16) {
                        Spacer()

                        FlippablePresetCard(
                            preset: preset,
                            isFlipped: isFlipped,
                            isCompleting: isCompleting,
                            onDone: {
                                playButtonTapSound()
                                completeExpandedPreset(preset)
                            },
                            onCancel: {
                                closeExpanded()
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: expandedPresetID)

                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func completeExpandedPreset(_ preset: HabitPreset) {
        guard !isCompleting else { return }
        isCompleting = true
        withAnimation(.easeInOut(duration: 0.4)) {
            isFlipped = true
        }
        logCompletion(for: preset)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            closeExpanded()
            isCompleting = false
        }
    }

    private func closeExpanded() {
        expandedPresetID = nil
        isFlipped = false
    }

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "promise-timer" else { return }
        guard url.host == "preset" else { return }
        let presetID = url.lastPathComponent
        guard habitPresets.contains(where: { $0.id == presetID }) else { return }
        selectedPresetID = presetID
        expandedPresetID = presetID
        isFlipped = false
    }

    private func deleteLog(_ log: HabitLog) {
        let updatedLogs = logs.filter { $0.id != log.id }
        save(logs: updatedLogs)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func logs(for date: Date) -> [HabitLog] {
        let key = ymdFormatter.string(from: date)
        return (logsByDay[key] ?? []).sorted { $0.completedAt > $1.completedAt }
    }

    private func playButtonTapSound() {
        AudioServicesPlaySystemSound(1104)
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
            PresetIconView(name: preset.iconName, size: 64, tint: preset.tint)
            Text(preset.title)
                .font(.title3.bold())
                .foregroundStyle(Color.cocoa)
            Text("タップで記録")
                .font(.subheadline)
                .foregroundStyle(Color.cocoa.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.sky.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct FlippablePresetCard: View {
    let preset: HabitPreset
    let isFlipped: Bool
    let isCompleting: Bool
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(preset.tint.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(preset.tint.opacity(0.35), lineWidth: 1)
                )

            VStack(spacing: 14) {
                ZStack {
                    front
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                    back
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                }
                .padding(.top, 18)

                HStack(spacing: 12) {
                    Button(action: onDone) {
                        Text("できた")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.cream)
                            .foregroundStyle(Color.cocoa)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cocoa.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .disabled(isCompleting)

                    Button(action: onCancel) {
                        Text("やめる")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.sky)
                            .foregroundStyle(Color.cocoa)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cocoa.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .disabled(isCompleting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .shadow(color: Color.cocoa.opacity(0.12), radius: 16, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.45), value: isFlipped)
    }

    private var front: some View {
        VStack(spacing: 16) {
            PresetIconView(name: preset.iconName, size: 380, tint: preset.tint)
            Text(preset.title)
                .font(.title2.bold())
                .foregroundStyle(Color.cocoa)
        }
        .frame(maxWidth: .infinity)
    }

    private var back: some View {
        VStack(spacing: 16) {
            Image("done")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 360, height: 360)
            Text("Done")
                .font(.title2.bold())
                .foregroundStyle(Color.candyBlue)
        }
        .frame(maxWidth: .infinity)
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
    let completedPresetIDsToday: Set<String>

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(presets) { preset in
                Button {
                    if !disabled { onSelect(preset) }
                } label: {
                    let isDoneToday = completedPresetIDsToday.contains(preset.id)
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        ZStack {
                            if isDoneToday {
                                Image("done")
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundStyle(Color.candyBlue)
                                            .background(Circle().fill(Color.cream))
                                    }
                            } else {
                                PresetIconView(
                                    name: preset.iconName,
                                    size: 150,
                                    tint: selectedPresetID == preset.id ? Color.white : Color.cocoa
                                )
                            }
                        }
                        Text(preset.title)
                            .font(.title3.bold())
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 152)
                    .padding(12)
                    .background(preset.tint.opacity(0.25))
                    .foregroundStyle(Color.cocoa)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(preset.tint.opacity(0.35), lineWidth: 1)
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

private struct WeeklyDotsCard: View {
    let days: [Date]
    let logsByDay: [String: [HabitLog]]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
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
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fillColor(count: count))
                        .frame(height: 28)
                        .overlay {
                            if count > 0 {
                                let isPeta2 = count >= 2
                                Image(isPeta2 ? "peta2" : "peta1")
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: isPeta2 ? 60 : 50, height: isPeta2 ? 60 : 50)
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.sky.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func fillColor(count: Int) -> Color {
        switch count {
        case 0:
            return .grassEmpty
        case 1:
            return .grassLight
        default:
            return .grassDark
        }
    }
}

private struct InitialPresetPickerSheet: View {
    let presets: [HabitPreset]
    let onSelect: ([HabitPreset]) -> Void
    let onSkip: () -> Void
    @State private var selectedIDs: Set<String> = []
    private let maxSelection = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最初にえらんでね")
                        .font(.title3.bold())
                        .foregroundStyle(Color.cocoa)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(presets) { preset in
                            Button {
                                toggleSelection(for: preset.id)
                            } label: {
                        HStack(spacing: 12) {
                            PresetIconView(name: preset.iconName, size: 72, tint: preset.tint)
                                .frame(width: 72)
                            Text(preset.title)
                                .font(.headline)
                                .foregroundStyle(Color.cocoa)
                            Spacer()
                            Image(systemName: selectedIDs.contains(preset.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedIDs.contains(preset.id) ? Color.candyBlue : Color.cocoa.opacity(0.3))
                        }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.sky.opacity(0.82))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    let selected = presets.filter { selectedIDs.contains($0.id) }
                    onSelect(selected)
                } label: {
                    Text("けってい")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.candyBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selectedIDs.isEmpty)
                .opacity(selectedIDs.isEmpty ? 0.45 : 1)

                Button("あとで") {
                    onSkip()
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                Text("最大\(maxSelection)個までえらべるよ")
                    .font(.caption)
                    .foregroundStyle(Color.cocoa.opacity(0.6))
            }
            .padding(20)
            .navigationTitle("")
        }
    }

    private func toggleSelection(for id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < maxSelection {
            selectedIDs.insert(id)
        }
    }
}

private struct PresetEditorSheet: View {
    @State private var showingDeleteConfirmation = false
    @Binding var title: String
    @Binding var iconName: String
    @Binding var tint: PresetTint
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("アイコン")
                            .font(.headline)
                        let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(presetIcons, id: \.self) { icon in
                                Button {
                                    iconName = icon
                                } label: {
                                    PresetIconView(
                                        name: icon,
                                        size: 92,
                                        tint: iconName == icon ? Color.white : Color.candyBlue
                                    )
                                    .frame(width: 96, height: 96)
                                    .background(iconName == icon ? Color.candyBlue : Color.sky.opacity(0.72))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
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
            .navigationTitle("やることをへんしゅう")
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
            Text("できたのあしあと")
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
                            .overlay {
                                if count > 0 {
                                    let isPeta2 = count >= 2
                                    Image(isPeta2 ? "peta2" : "peta1")
                                        .resizable()
                                        .renderingMode(.original)
                                        .scaledToFit()
                                        .frame(width: isPeta2 ? 60 : 50, height: isPeta2 ? 60 : 50)
                                }
                            }
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
    let iconForLog: (HabitLog) -> (name: String, tint: Color)
    let canAdd: Bool
    let onAdd: () -> Void
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
                    HStack(spacing: 12) {
                        Text(logTimeFormatter.string(from: log.completedAt))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.cocoa.opacity(0.7))
                            .frame(width: 60, alignment: .leading)

                        let iconInfo = iconForLog(log)
                        PresetIconView(name: iconInfo.name, size: 60, tint: iconInfo.tint)
                            .frame(width: 28, height: 28)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.title)
                                .font(.headline)
                        }
                        Spacer()
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
                    .padding(.vertical, 10)
                }
            }

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
                            PresetIconView(name: preset.iconName, size: 28, tint: preset.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title)
                                    .font(.headline)
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


#Preview {
    ContentView()
}
