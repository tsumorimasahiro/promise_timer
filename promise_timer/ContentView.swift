//
//  ContentView.swift
//  promise_timer
//
//  Created by 津守将弘 on 2026/03/15.
//

import SwiftUI
import Combine
import AudioToolbox
import StoreKit
import AppTrackingTransparency
import WidgetKit
import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

fileprivate let ymdFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

func localizedText(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

fileprivate func displayPochiName(_ storedName: String) -> String {
    let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed.isEmpty || trimmed == "ぽち") ? localizedText("ぽち") : trimmed
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .autoupdatingCurrent, arguments: arguments)
}

fileprivate var localeAwareGregorianCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = .autoupdatingCurrent
    calendar.timeZone = .autoupdatingCurrent
    return calendar
}

fileprivate func localizedWeekdaySymbols() -> [String] {
    let calendar = localeAwareGregorianCalendar
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = .autoupdatingCurrent
    let symbols = formatter.shortStandaloneWeekdaySymbols ?? []
    guard !symbols.isEmpty else { return [] }
    let startIndex = (calendar.firstWeekday - 1) % symbols.count
    return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
}

fileprivate let logTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "H:mm"
    return formatter
}()

fileprivate let dayTitleFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMdd", options: 0, locale: formatter.locale)
    return formatter
}()

extension PresetTint {
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

private let builtInPresetTitleKeys: [String: String] = [
    "strength.crunches": "腹筋", "strength.plank": "プランク", "strength.sidePlank": "サイドプランク",
    "strength.birdDog": "バードドッグ", "strength.deadBug": "デッドバグ", "strength.lunges": "ランジ",
    "strength.gluteBridge": "ヒップリフト", "strength.calfRaises": "かかと上げ",
    "strength": "筋トレ", "squats": "スクワット", "pushups": "腕立て伏せ", "dumbbells": "ダンベル",

]

func localizedPresetTitle(id: String, storedTitle: String) -> String {
    guard let key = builtInPresetTitleKeys[id] else { return storedTitle }
    let locales = ["ja", "en", "ko", "zh-Hans", "zh-Hant"]
    let isUnmodifiedBuiltInTitle = locales.contains { locale in
        guard let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return false }
        return bundle.localizedString(forKey: key, value: nil, table: nil) == storedTitle
    }
    return isUnmodifiedBuiltInTitle ? localizedText(key) : storedTitle
}

private enum PochiCharm: String, CaseIterable {
    case heart = "heart.fill"
    case star = "star.fill"
    case moon = "moon.fill"

    var title: String {
        switch self {
        case .heart: return localizedText("ハート")
        case .star: return localizedText("おほしさま")
        case .moon: return localizedText("おつきさま")
        }
    }
}

private extension PochiCoat {
    var title: String { localizedText(titleKey(for: .shiba)) }
}

private struct PochiCoatPicker: View {
    let breed: PochiBreed
    let selection: PochiCoat
    let onSelect: (PochiCoat) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("毛色").font(pochiPixelFont(14))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { options }
                VStack(spacing: 8) { options }
            }
        }.foregroundStyle(Color.cocoa)
    }
    private var options: some View {
        ForEach(PochiCoat.allCases) { coat in
            Button { onSelect(coat) } label: {
                HStack(spacing: 6) {
                    Text(localizedText(coat.titleKey(for: breed)))
                        .fixedSize(horizontal: true, vertical: false)
                    if selection == coat { PochiPixelGlyph(kind: .check, color: .grassDark, size: 12) }
                }
                .font(pochiPixelFont(13))
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .background(selection == coat ? Color.mist : Color.cream, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selection == coat ? Color.grassDark : Color.cocoa.opacity(0.3), lineWidth: selection == coat ? 2 : 1))
            }.buttonStyle(.plain)
                .accessibilityAddTraits(selection == coat ? .isSelected : [])
        }
    }
}

fileprivate let appGroupID = "group.com.tsumori.promise_timer"
fileprivate let appGroupDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

extension HabitPreset {
    var tint: Color { tintName.color }
}

fileprivate let defaultPresets = PochiWorkoutCatalog.starterPresets
fileprivate let initialSelectablePresets = PochiWorkoutCatalog.presets

fileprivate let presetIcons = PochiWorkoutCatalog.presets.map(\.iconName)

fileprivate func presetIconAccessibilityName(_ name: String) -> String {
    localizedText(["dumbbell.fill": "筋トレ", "figure.strengthtraining.traditional": "スクワット",
        "figure.strengthtraining.functional": "腕立て伏せ"][name] ?? "筋トレ")
}

private func presetIconShortName(_ name: String) -> String { presetIconAccessibilityName(name) }

private func pochiIconKind(iconName: String) -> PochiPixelIconKind {
    switch iconName.lowercased() {
    case "dumbbell.fill", "dumbbell", "figure.strengthtraining.traditional", "figure.strengthtraining.functional": return .dumbbell
    case "drop.fill", "drop", "water": return .water
    case "figure.walk", "walk", "outside": return .shoe
    case "run", "figure.run", "stretch", "exercise": return .stretch
    case "toothbrush": return .toothbrush
    case "dishes": return .dishes
    case "bath", "bathtub": return .bath
    case "eat", "fork.knife", "breakfast", "food": return .meal
    case "book", "book.fill", "book.closed.fill", "reading": return .book
    case "study", "pencil", "journal", "focus": return .pencil
    case "textformat": return .language
    case "bed.double.fill": return .bed
    case "moon.fill", "moon", "sleep", "rest": return .moon
    case "trash": return .trash
    case "clean", "broom", "house.fill": return .broom
    case "leaf.fill", "leaf", "plants": return .leaf
    case "music.note", "music": return .music
    case "camera.fill", "camera": return .camera
    case "tshirt.fill", "shirt", "laundry": return .shirt
    case "heart.fill", "heart", "thanks": return .heart
    case "pawprint.fill": return .paw
    case "star.fill": return .sparkle
    case "envelope.fill", "message": return .envelope
    case "wind": return .breath
    case "checklist": return .clipboard
    case "target": return .target
    default: return .sparkle
    }
}

fileprivate struct PresetIconView: View {
    let name: String
    let size: CGFloat
    let tint: Color?

    var body: some View {
        WorkoutIcon(name: name, size: size, color: tint ?? Color.grassDark)
            .frame(width: size, height: size)
    }
}

extension Color {
    static let candyBlue = Color("PochiCandyBlue")
    static let mintGreen = Color("PochiMintGreen")
    static let sunshine = Color("PochiSunshine")
    static let peach = Color("PochiPeach")
    static let lavender = Color("PochiLavender")
    static let sky = Color("PochiSky")
    static let cream = Color("PochiCream")
    static let cocoa = Color("PochiCocoa")
    static let roseCloud = Color("PochiRoseCloud")
    static let mist = Color("PochiMist")
    static let grassEmpty = Color("PochiGrassEmpty")
    static let grassLight = Color("PochiGrassLight")
    static let grassDark = Color("PochiGrassDark")
}

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @AppStorage("pochiTogetherSession.v1", store: appGroupDefaults) private var togetherSessionStorage = ""
    @AppStorage("habitLogsStore", store: appGroupDefaults) private var habitLogsStorage: String = ""
    @AppStorage("habitPresetsStore", store: appGroupDefaults) private var habitPresetsStorage: String = ""
    @AppStorage("pochiName", store: appGroupDefaults) private var pochiName = "ぽち"
    @AppStorage("pochiCollarTint", store: appGroupDefaults) private var pochiCollarTint = PresetTint.peach.rawValue
    @AppStorage("pochiCharm", store: appGroupDefaults) private var pochiCharm = PochiCharm.heart.rawValue
    @AppStorage("isSubscribed") private var isSubscribed: Bool = false
    @AppStorage("reviewActionCount") private var reviewActionCount: Int = 0
    @AppStorage("didRequestATT") private var didRequestATT: Bool = false
    @AppStorage("didSelectInitialPresets") private var didSelectInitialPresets: Bool = false
    @StateObject private var subscriptionManager = SubscriptionManager()
    @AppStorage("workoutPromptPolicy.v1") private var promptPolicyStorage = ""
    @State private var pendingPostWorkoutPrompt = false
    @State private var showingPremiumPrompt = false
    @State private var bannerEligible = false
    @State private var habitPresets: [HabitPreset] = defaultPresets
    @State private var selectedTab = 0
    @State private var selectedPresetID: String = defaultPresets[0].id
    @State private var selectedLogDate: Date = Date()
    @State private var currentDate = Date()
    @State private var displayedMonth = Date()
    @State private var undoableLog: HabitLog?
    @StateObject private var memoryStore = PochiMemoryStore()
    @StateObject private var strengthStore = PochiStrengthStore(defaults: appGroupDefaults)
    @State private var showingMemories = false
    @State private var homeScene: PochiPixelRoomScene?
    @State private var expandedPresetID: String?
    @State private var isFlipped = false
    @State private var isCompleting = false
    @State private var showingPresetEditor = false
    @State private var editingPreset: HabitPreset?
    @State private var draftPresetTitle = ""
    @State private var draftPresetIconName = "dumbbell.fill"
    @State private var draftPresetTint: PresetTint = .peach
    @State private var draftPlan = WorkoutPlan()
    @State private var pendingWorkoutPhoto: (UIImage, Date)?
    @State private var draftCategory: HabitCategory = .care
    @State private var draftTemplateID: String?
    @State private var showingAddLogSheet = false
    @State private var showingInitialPresetPicker = false
    @State private var showingPochiProfileEditor = false

    init() {
        if let font = UIFont(name: "PixelMplus12-Bold", size: 10) {
            UITabBarItem.appearance().setTitleTextAttributes([.font: font], for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes([.font: font], for: .selected)
        }
    }

    private var pochiCollarColor: Color {
        PresetTint(rawValue: pochiCollarTint)?.color ?? PresetTint.peach.color
    }

    private var calendar: Calendar { localeAwareGregorianCalendar }

    var body: some View {
        VStack(spacing: 0) {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PochiTodayCard(
                    pochiName: displayPochiName(pochiName),
                    collarColor: pochiCollarColor,
                    bondCharm: pochiCharm,
                    chosenPresets: habitPresets,
                    completedPresetIDsToday: completedPresetIDsToday,
                    learnedHabits: learnedHabits,
                    worldState: worldState,
                    togetherSession: togetherSession,
                    onStartTogether: startTogether,
                    onPauseTogether: toggleTogetherPause,
                    onUpdateSession: persistTogether,
                    onFinishTogether: finishTogether,
                    onRecorded: presentPostWorkoutPrompt,
                    onDiscardTogether: { togetherSessionStorage = ""; pendingWorkoutPhoto = nil },
                    onCustomize: { showingPochiProfileEditor = true },
                    onAdd: openAddPreset,
                    onEdit: openEditPreset,
                    onSceneReady: { scene in
                        homeScene = scene
                        scene.memoryStore = memoryStore
                        scene.memoryDogName = displayPochiName(pochiName)
                        memoryStore.discover(learnedHabits)
                        scene.onWorkoutPhoto = { image, date in pendingWorkoutPhoto = (image, date) }
                    }
                )
                .background(Color.cream)
                .toolbar(.hidden, for: .navigationBar)
                .onChange(of: pochiName) { homeScene?.memoryDogName = displayPochiName($0) }
            }
            .tabItem { Label("ホーム", image: "pochi-tab-home") }.tag(0)

            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        Button { showingMemories = true } label: {
                            HStack {
                                PochiPixelGlyph(kind: .book, color: .grassDark)
                                Text("ぽちの思い出").font(pochiPixelFont(16))
                                Spacer()
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        monthNavigation
                        HabitGrassCard(
                            days: grassDays,
                            selectedDate: selectedLogDate,
                            displayedMonth: displayedMonth,
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

                        if !logs(for: selectedLogDate).isEmpty {
                            PochiDayMoment(store: memoryStore, date: selectedLogDate,
                                achievements: logs(for: selectedLogDate).map(albumAchievement))
                        }

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(Color.cream)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("きろく")
                            .font(pochiPixelFont(16))
                            .foregroundStyle(Color.cocoa)
                    }
                }
                .toolbarBackground(Color.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $showingMemories) {
                PochiMemoryAlbum(store: memoryStore, logs: logs, achievement: albumAchievement)
            }
            .tabItem { Label("きろく", image: "pochi-tab-record") }.tag(1)

            SettingsView(
                subscriptionManager: subscriptionManager,
                onEditPochi: { showingPochiProfileEditor = true }
            )
            .tabItem { Label("設定", image: "pochi-tab-settings") }.tag(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        bannerAd
        }
        .background(Color.cream)
        .onAppear {
            migrateDefaultsToAppGroupIfNeeded()
            PochiWorkoutMigration.apply(to: appGroupDefaults)
            if !appGroupDefaults.bool(forKey: "pochiWorkoutBasics.v2"),
               !habitPresetsStorage.isEmpty,
               let data = habitPresetsStorage.data(using: .utf8),
               let saved = try? JSONDecoder().decode([HabitPreset].self, from: data),
               let updated = try? JSONEncoder().encode(PochiWorkoutCatalog.installingBasics(in: saved)) {
                habitPresetsStorage = String(decoding: updated, as: UTF8.self)
                appGroupDefaults.set(true, forKey: "pochiWorkoutBasics.v2")
            }
            loadPresets()
            strengthStore.synchronize(logs: logs, now: Date(), calendar: calendar)
            if habitPresetsStorage.isEmpty {
                showingInitialPresetPicker = !didSelectInitialPresets
            } else {
                didSelectInitialPresets = true
            }
        }
        .onChange(of: habitLogsStorage) { _ in
            strengthStore.synchronize(logs: logs, now: Date(), calendar: calendar)
        }
        .onChange(of: strengthStore.progress) { _ in WidgetCenter.shared.reloadAllTimelines() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            refreshCurrentDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshCurrentDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshCurrentDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshCurrentDate()
        }
        .task(id: didSelectInitialPresets) {
            await subscriptionManager.start()
            isSubscribed = subscriptionManager.isSubscribed
            appGroupDefaults.set(isSubscribed, forKey: "isSubscribed")
            guard didSelectInitialPresets, !isSubscribed else { return }
            await AdPrivacyManager.shared.prepare()
            // Let first-time users choose an exercise and meet Pochi before
            // showing the optional ad-tracking prompt on a later launch.
            if didSelectInitialPresets && reviewActionCount > 0 {
                await requestTrackingAuthorizationIfNeeded()
            }
            bannerEligible = AdPrivacyManager.shared.canRequestAds
        }
        .onChange(of: subscriptionManager.isSubscribed) { newValue in
            isSubscribed = newValue
            appGroupDefaults.set(newValue, forKey: "isSubscribed")
            WidgetCenter.shared.reloadAllTimelines()
        }
        .sheet(isPresented: $showingPremiumPrompt) {
            PaywallSheet(subscriptionManager: subscriptionManager, isPresented: $showingPremiumPrompt)
        }
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorSheet(
                title: $draftPresetTitle,
                iconName: $draftPresetIconName,
                plan: $draftPlan,
                existingIDs: Set(habitPresets.map(\.id)),
                onTemplate: applyTemplate,
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
                presets: habitPresets.filter { preset in
                    !logs(for: selectedLogDate).contains { $0.presetID == preset.id }
                },
                onAdd: { preset, values in
                    guard addLog(for: preset, on: selectedLogDate, values: values) else { return false }
                    showingAddLogSheet = false
                    return true
                },
                onCancel: { showingAddLogSheet = false }
            )
        }
        .sheet(isPresented: $showingPochiProfileEditor) {
            PochiProfileEditor(subscriptionManager: subscriptionManager)
        }
        .fullScreenCover(isPresented: $showingInitialPresetPicker) {
            InitialPresetPickerSheet(
                presets: initialSelectablePresets,
                onSelect: { selected in
                    appGroupDefaults.set(true, forKey: "pochiWorkoutBasics.v2")
                    habitPresets = selected
                    selectedPresetID = selected.first?.id ?? ""
                    persistPresets()
                    didSelectInitialPresets = true
                    showingInitialPresetPicker = false
                }
            )
            .interactiveDismissDisabled(true)
        }
        .tint(Color.grassDark)
        .toolbarBackground(Color.cream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let log = undoableLog {
                HStack(spacing: 12) {
                    Text("記録したよ").font(pochiPixelFont(13))
                    Spacer()
                    Button("取り消す") {
                        deleteLog(log)
                        undoableLog = nil
                    }
                    .font(pochiPixelFont(13))
                    .frame(minWidth: 64, minHeight: 44)
                }
                .foregroundStyle(Color.cocoa)
                .padding(.horizontal, 16)
                .background(Color.mist)
            }
        }
        .task(id: undoableLog?.id) {
            guard let id = undoableLog?.id else { return }
            do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
            if undoableLog?.id == id { undoableLog = nil }
        }
        .onOpenURL { url in
            handleWidgetURL(url)
        }
    }

    private func refreshCurrentDate() {
        let now = Date()
        // Follow today only when the user was viewing today, preserving history browsing.
        if calendar.isDate(selectedLogDate, inSameDayAs: currentDate) {
            if calendar.isDate(displayedMonth, equalTo: currentDate, toGranularity: .month) {
                displayedMonth = now
            }
            selectedLogDate = now
        }
        currentDate = now
    }

    private func albumAchievement(_ log: HabitLog) -> PochiAlbumAchievement {
        let icon = presetByID[log.presetID].map { pochiIconKind(for: $0) }
            ?? pochiIconKind(iconName: iconForLog(log).name)
        return PochiAlbumAchievement(id: log.id,
            title: localizedPresetTitle(id: log.presetID, storedTitle: log.title), icon: icon)
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [Color.cream, Color.roseCloud.opacity(0.65), Color.mist],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var bannerAd: some View {
        if !isStoreScreenshotSession && !isSubscribed && didSelectInitialPresets && !showingInitialPresetPicker {
            PochiBannerAd(canLoad: bannerEligible)
        }
    }

    private var isStoreScreenshotSession: Bool {
        #if DEBUG
        // Omit the SDK's test-ad creative from store captures. Release behavior is unchanged.
        ProcessInfo.processInfo.arguments.contains("-pochi-store-screenshots")
        #else
        false
        #endif
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
        return ((try? decoder.decode([HabitLog].self, from: data)) ?? []).filter { log in
            PochiWorkoutCatalog.isWorkout(presetByID[log.presetID] ?? HabitPreset(
                id: log.presetID, title: log.title, iconName: "", tintName: .peach))
        }
    }

    private var logsByDay: [String: [HabitLog]] {
        Dictionary(grouping: logs) { ymdFormatter.string(from: $0.completedAt) }
    }

    private var completedPresetIDsToday: Set<String> {
        let key = ymdFormatter.string(from: currentDate)
        let ids = (logsByDay[key] ?? []).map(\.presetID)
        return Set(ids)
    }

    private var todayDoneCount: Int {
        habitPresets.filter { completedPresetIDsToday.contains($0.id) }.count
    }

    private var completionsThisWeek: [String: Int] {
        guard let weekStart = currentWeekDays.first,
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [:] }
        let logsByPreset = Dictionary(grouping: logs.filter {
            $0.completedAt >= weekStart && $0.completedAt < weekEnd
        }, by: \.presetID)
        return logsByPreset.mapValues { items in
            Set(items.map { ymdFormatter.string(from: $0.completedAt) }).count
        }
    }

    private var weekDoneCount: Int {
        habitPresets.reduce(0) { $0 + min(completionsThisWeek[$1.id, default: 0], $1.weeklyTarget) }
    }

    private var weekTargetCount: Int {
        habitPresets.reduce(0) { $0 + $1.weeklyTarget }
    }

    private var currentWeekDays: [Date] {
        let today = calendar.startOfDay(for: currentDate)
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var grassDays: [Date] {
        HabitCalendar.monthDays(containing: displayedMonth, calendar: calendar)
    }

    private var worldState: PochiWorldState {
        PochiWorldState(activeThemes: [.exercise], growth: [.exercise: learnedHabits.days(for: .exercise)],
            totalCompletions: logs.count, phase: .at(currentDate, calendar: calendar))
    }

    private var learnedHabits: PochiLifeHabits {
        PochiLifeHabits.derive(logs: logs, calendar: calendar, now: currentDate) { log in
            // Built-in histories still count after removing a template from today's list.
            let preset = presetByID[log.presetID]
                ?? initialSelectablePresets.first { $0.id == log.presetID }
                ?? defaultPresets.first { $0.id == log.presetID }
            return preset.map { activityForPromise($0).learningActivity }
        }
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

    @discardableResult
    private func save(logs: [HabitLog]) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(logs),
              let string = String(data: data, encoding: .utf8) else { return false }
        habitLogsStorage = string
        strengthStore.synchronize(logs: logs, now: Date(), calendar: calendar)
        WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    private func loadPresets() {
        guard let data = habitPresetsStorage.data(using: .utf8) else {
            habitPresets = didSelectInitialPresets ? defaultPresets : []
            return
        }
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([HabitPreset].self, from: data) {
            // Only training belongs in the active product. Preserve an intentionally empty list.
            let migrated = items.filter { PochiWorkoutCatalog.isWorkout($0) }
            habitPresets = migrated
        } else {
            habitPresets = didSelectInitialPresets ? defaultPresets : []
        }

        if !habitPresets.contains(where: { $0.id == selectedPresetID }), let first = habitPresets.first {
            selectedPresetID = first.id
        }
    }

    private func persistPresets() {
        // An encoded empty array represents an existing user with no exercises.
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(habitPresets),
              let string = String(data: data, encoding: .utf8) else { return }
        habitPresetsStorage = string
        WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
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
        return ("dumbbell.fill", .peach)
    }

    private var togetherSession: PochiTogetherSession? {
        guard let data = togetherSessionStorage.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PochiTogetherSession.self, from: data)
    }
    private func persistTogether(_ session: PochiTogetherSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        togetherSessionStorage = String(decoding: data, as: UTF8.self)
    }
    private func startTogether(_ preset: HabitPreset) {
        guard togetherSession == nil else { return }
        if let index = habitPresets.firstIndex(where: { $0.id == preset.id }) {
            habitPresets[index] = preset; persistPresets()
        }
        pendingWorkoutPhoto = nil
        persistTogether(PochiTogetherSession(preset: preset))
        PochiWorkoutWidget.remember(preset.id, in: appGroupDefaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
        WorkoutSounds.shared.play(.start)
    }
    private func toggleTogetherPause() {
        guard var session = togetherSession else { return }
        if session.isPaused { session.resume(at: Date()) } else { session.pause(at: Date()) }
        persistTogether(session)
    }
    private func finishTogether(_ values: [Int]) -> Bool {
        guard let session = togetherSession, !values.isEmpty, values.allSatisfy({ $0 > 0 }) else { return false }
        let now = Date()
        guard save(logs: session.recording(in: logs, at: now, calendar: calendar, values: values,
            recordsDuration: session.preset.workoutPlan.mode == .timed)) else { return false }
        if let (image, date) = pendingWorkoutPhoto, calendar.isDate(date, inSameDayAs: now) {
            _ = memoryStore.rememberToday(image: image, name: displayPochiName(pochiName), date: date,
                                         replaceExisting: true, workoutPhoto: true)
        }
        pendingWorkoutPhoto = nil
        togetherSessionStorage = ""
        homeScene?.setWorkout(nil)
        homeScene?.enqueueReaction(.strength, id: session.id)
        selectedLogDate = now; displayedMonth = now; currentDate = now
        reviewActionCount += 1
        var policy = promptPolicy
        policy.recordCompletion(id: session.id, at: now, calendar: calendar)
        storePromptPolicy(policy)
        pendingPostWorkoutPrompt = true
        WorkoutSounds.shared.play(.saved)
        return true
    }
    private var monthNavigation: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("前の月")
            Spacer()
            Text(displayedMonth, format: .dateTime.year().month()).font(pochiPixelFont(17))
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("次の月")
        }.foregroundStyle(Color.cocoa)
    }
    private func shiftMonth(_ delta: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }
    private func openAddPreset() {
        editingPreset = nil; draftPresetTitle = ""; draftPresetIconName = "dumbbell.fill"
        draftPlan = WorkoutPlan(); showingPresetEditor = true
    }
    private func openEditPreset(_ preset: HabitPreset) {
        editingPreset = preset; draftPresetTitle = preset.title; draftPresetIconName = preset.iconName
        draftPlan = preset.workoutPlan; showingPresetEditor = true
    }
    private func applyTemplate(_ preset: HabitPreset) {
        draftPresetTitle = preset.title; draftPresetIconName = preset.iconName; draftPlan = preset.workoutPlan
    }
    private func savePreset() {
        let title = draftPresetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let preset = HabitPreset(id: editingPreset?.id ?? "strength.custom." + UUID().uuidString,
            title: title, iconName: draftPresetIconName, tintName: .peach, workoutPlan: draftPlan)
        if let index = habitPresets.firstIndex(where: { $0.id == preset.id }) { habitPresets[index] = preset }
        else { habitPresets.append(preset) }
        persistPresets(); showingPresetEditor = false
    }
    private func deletePreset() {
        guard let preset = editingPreset else { return }
        habitPresets.removeAll { $0.id == preset.id }; persistPresets(); showingPresetEditor = false
    }
    private func addLog(for preset: HabitPreset, on date: Date, values: [Int]) -> Bool {
        guard canAddLog(for: date), !values.isEmpty,
              !logs(for: date).contains(where: { $0.presetID == preset.id }) else { return false }
        let id = UUID().uuidString
        return save(logs: logs + [HabitLog(id: id, presetID: preset.id, title: preset.title,
            completedAt: mergeDate(date, withTimeFrom: Date()),
            workouts: [WorkoutRecord(id: id, plan: preset.workoutPlan, values: values)])])
    }
    private func handleWidgetURL(_ url: URL) {
        guard let link = PochiWorkoutWidgetLink(url: url) else { return }
        selectedTab = 0
        showingMemories = false
        showingPochiProfileEditor = false
        showingPresetEditor = false
        showingAddLogSheet = false
        showingPremiumPrompt = false
        loadPresets()
        // Existing running/paused sessions take priority over another shortcut.
        guard togetherSession == nil, didSelectInitialPresets || !habitPresetsStorage.isEmpty,
              case .preset(let id) = link,
              let preset = habitPresets.first(where: { $0.id == id }) else { return }
        startTogether(preset)
    }

    private var promptPolicy: WorkoutPromptPolicy {
        guard let data = promptPolicyStorage.data(using: .utf8),
              let value = try? JSONDecoder().decode(WorkoutPromptPolicy.self, from: data) else { return .init() }
        return value
    }
    private func storePromptPolicy(_ value: WorkoutPromptPolicy) {
        if let data = try? JSONEncoder().encode(value) { promptPolicyStorage = String(decoding: data, as: UTF8.self) }
    }
    private func presentPostWorkoutPrompt() {
        guard pendingPostWorkoutPrompt else { return }
        pendingPostWorkoutPrompt = false
        guard togetherSession == nil, bannerEligible, !isStoreScreenshotSession,
              !showingPresetEditor, !showingInitialPresetPicker, !showingPochiProfileEditor,
              UIApplication.shared.applicationState == .active else { return }
        var policy = promptPolicy
        guard let prompt = policy.nextPrompt(at: Date(), isPremium: subscriptionManager.isSubscribed) else { return }
        if prompt == .premium && subscriptionManager.products.isEmpty { return }
        policy.markPresented(prompt, at: Date()); storePromptPolicy(policy)
        switch prompt {
        case .review: requestReview()
        case .premium: showingPremiumPrompt = true
        }
    }

    private func deleteLog(_ log: HabitLog) {
        homeScene?.cancelReaction(id:log.id)
        if undoableLog?.id == log.id { undoableLog = nil }
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

private struct PochiTodayCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("pochiCoat", store: appGroupDefaults) private var coatName = PochiCoat.kinako.rawValue
    let pochiName: String
    let collarColor: Color
    let bondCharm: String
    let chosenPresets: [HabitPreset]
    let completedPresetIDsToday: Set<String>
    let learnedHabits: PochiLifeHabits
    let worldState: PochiWorldState
    var togetherSession: PochiTogetherSession? = nil
    var onStartTogether: (HabitPreset) -> Void = { _ in }
    var onPauseTogether: () -> Void = {}
    var onUpdateSession: (PochiTogetherSession) -> Void = { _ in }
    var onFinishTogether: ([Int]) -> Bool = { _ in false }
    var onRecorded: () -> Void = {}
    var onDiscardTogether: () -> Void = {}
    let onCustomize: () -> Void
    let onAdd: () -> Void
    let onEdit: (HabitPreset) -> Void
    let onSceneReady: (PochiPixelRoomScene) -> Void
    @State private var scene: PochiPixelRoomScene?
    @State private var confirmingDiscard = false
    @State private var saveFailed = false
    @State private var finished = false
    @State private var countdownCues = WorkoutCountdownCues()
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var trainingPresets: [HabitPreset] { chosenPresets.filter { $0.id != "strength" && PochiWorkoutCatalog.isWorkout($0) } }
    private func recordWorkout() {
        guard var session = togetherSession else { return }
        let now = Date()
        if session.preset.workoutPlan.mode == .timed, !session.awaitingNextSet, session.remaining(at: now) == 0 {
            session.completeSet(at: now)
        } else { session.pause(at: now) }
        onUpdateSession(session)
        guard onFinishTogether(session.suggestedValues(at: now)) else {
            saveFailed = true
            return
        }
        finished = true
        onRecorded()
    }
    var body: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width > geometry.size.height
            let layout = horizontal ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
            VStack(spacing: 8) {
                HStack {
                    Text(localizedFormat("%@と筋トレ", pochiName)).font(pochiPixelFont(20)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    Button(action: onCustomize) { PochiPixelGlyph(kind: .settings, color: .grassDark, size: 24) }
                        .frame(width: 44, height: 44).accessibilityLabel("プロフィール")
                }
                layout {
                    PochiRoomView(coat: PochiCoat(rawValue: coatName) ?? .kinako,
                        activity: .idle, activityToken: 0, learnedHabits: learnedHabits, worldState: worldState,
                        compact: true, workoutPreset: togetherSession?.isPaused == false ? togetherSession?.preset : nil) { ready in
                        scene = ready; onSceneReady(ready)
                    }
                    .frame(width: horizontal ? geometry.size.width * 0.4 : nil,
                           height: horizontal ? max(120, geometry.size.height - 60) : min(190, max(150, geometry.size.height * 0.32)))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Group {
                        if let session = togetherSession {
                            ScrollView { sessionPanel(session).padding(.bottom, 8) }
                        } else {
                            WorkoutSelectionPanel(presets: trainingPresets, finished: finished, compact: horizontal,
                                onStart: { finished = false; onStartTogether($0) },
                                onEdit: onEdit, onAdd: onAdd)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.padding(.horizontal, 16).padding(.bottom, 8)
        }.background(Color.cream).foregroundStyle(Color.cocoa)
            .onReceive(timer) { now in
                guard var session = togetherSession, session.preset.workoutPlan.mode == .timed,
                      !session.isPaused, !session.awaitingNextSet else { return }
                let remaining = session.remaining(at: now)
                if let cue = countdownCues.cue(sessionID: session.id, remaining: remaining,
                    isRunning: true, isForeground: scenePhase == .active) {
                    WorkoutSounds.shared.play(cue)
                }
                guard remaining == 0 else { return }
                session.completeSet(at: now); onUpdateSession(session)
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { WorkoutSounds.shared.stop() }
            }
            .alert("記録できませんでした", isPresented: $saveFailed) { Button("閉じる", role: .cancel) {} }
            .confirmationDialog("計測を終了しますか？", isPresented: $confirmingDiscard) {
                Button("記録せず終了", role: .destructive) { scene?.setWorkout(nil); onDiscardTogether() }
                Button("続ける", role: .cancel) {}
            }
    }
    private func sessionPanel(_ session: PochiTogetherSession) -> some View {
        VStack(spacing: 14) {
            HStack {
                WorkoutIcon(name: session.preset.iconName, size: 34)
                Text(localizedPresetTitle(id: session.preset.id, storedTitle: session.preset.title)).font(pochiPixelFont(19)); Spacer()
            }
            if session.awaitingNextSet {
                Text("おつかれさま！記録しよう。")
                    .font(.headline).multilineTextAlignment(.center)
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    VStack(spacing: 6) {
                        if session.preset.workoutPlan.mode == .timed {
                            Text(PochiElapsedTime.string(Double(session.remaining(at: context.date))))
                                .font(pochiPixelFont(40).monospacedDigit()).accessibilityLabel("残り時間")
                        } else {
                            Text(localizedFormat("%lld回", session.preset.workoutPlan.target)).font(pochiPixelFont(36))
                        }
                        Text(session.isPaused ? "ひとやすみ中" : "いっしょに筋トレ中").font(.caption)
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                PochiPrimaryButton(title: localizedText("終了して記録する"),
                    isEnabled: !session.suggestedValues(at: context.date).isEmpty, action: recordWorkout)
            }
            if !session.awaitingNextSet {
                Button(session.isPaused ? "再開する" : "ひとやすみ", action: onPauseTogether)
                    .frame(minWidth: 90, minHeight: 48)
            }
            Button("記録せず終了") { confirmingDiscard = true }.font(.caption).frame(minHeight: 44)
        }.padding(16).background(Color.pochiSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PochiPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photo: UIImage
    let name: String
    let onSave: () -> Bool
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(uiImage: photo).resizable().interpolation(.none).scaledToFit()
                        .frame(maxHeight: 440).accessibilityLabel(name)
                    Text("きろくに残して、あとからシェアできます。")
                        .font(pochiPixelFont(14)).multilineTextAlignment(.center)
                    PochiPrimaryButton(title: localizedText("今日の一枚にする")) {
                        if onSave() { dismiss() } else { saveFailed = true }
                    }
                }.padding(20)
            }.background(Color.cream).foregroundStyle(Color.cocoa)
                .navigationTitle(localizedText("今日のぽち")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
                .alert("思い出を保存できませんでした。", isPresented: $saveFailed) {
                    Button("閉じる", role: .cancel) {}
                }
        }
    }
}

private func activityForPromise(_ preset: HabitPreset) -> PochiRoomActivity {
    PochiPromiseReaction.activity(for: preset)
}


private struct PochiCompanion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: Int
    let hasBond: Bool
    let hasPromiseToday: Bool
    let celebrates: Bool
    let collarColor: Color

    var body: some View {
        if reduceMotion {
            companionPose(stage >= 2 ? "pochiWalking" : (hasBond ? "pochiGreeting" : "done"))
        } else if stage >= 2 {
            TimelineView(.periodic(from: .now, by: 0.42)) { context in
                let isFirstStep = Int(context.date.timeIntervalSinceReferenceDate / 0.42).isMultiple(of: 2)
                companionPose(isFirstStep ? "pochiWalking" : "pochiWalkingAlternate")
            }
        } else {
            TimelineView(.periodic(from: .now, by: 0.8)) { context in
                let isBreathingIn = Int(context.date.timeIntervalSinceReferenceDate / 0.8).isMultiple(of: 2)
                companionPose(hasBond ? "pochiGreeting" : "done", breathing: isBreathingIn)
            }
        }
    }

    private func companionPose(_ imageName: String, breathing: Bool = false) -> some View {
        mascot(imageName, breathing: breathing)
            .overlay(alignment: .topTrailing) {
                if hasPromiseToday {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.peach)
                        .background(Circle().fill(Color.cream).frame(width: 25, height: 25))
                        .rotationEffect(.degrees(12))
                        .offset(x: -13, y: 17)
                        .scaleEffect(celebrates ? 1.3 : 1)
                        .opacity(0.95)
                        .accessibilityHidden(true)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hasPromiseToday)
    }

    private func mascot(_ imageName: String, breathing: Bool = false) -> some View {
        PochiPortrait(imageName: imageName, collarColor: collarColor, width: 142, height: 112)
            .offset(x: stage >= 2 ? 28 : 0, y: 6 + (celebrates ? -8 : (breathing ? -2 : 0)))
            .scaleEffect(celebrates ? 1.06 : (breathing ? 1.015 : 1))
            .animation(.easeInOut(duration: 0.16), value: imageName)
            .animation(.easeInOut(duration: 0.72), value: breathing)
            .accessibilityHidden(true)
    }
}

private func pochiIconKind(for preset: HabitPreset) -> PochiPixelIconKind {
    if PochiWorkoutCatalog.isWorkout(preset) { return .dumbbell }
    let id = preset.id.lowercased()
    if ["water"].contains(id) { return .water }
    if ["stretch", "exercise"].contains(id) { return .stretch }
    if ["walk", "outside"].contains(id) { return .shoe }
    if id == "bath" { return .bath }
    if id == "breakfast" { return .meal }
    if id == "dishes" { return .dishes }
    if ["reading", "readingpage"].contains(id) { return .book }
    if ["study", "studyquestion", "journal"].contains(id) { return .pencil }
    if id == "language" { return .language }
    if id == "focus" { return .target }
    if id == "prepare" { return .clipboard }
    if id == "sleeproutine" { return .bed }
    if ["sleep", "rest"].contains(id) { return .moon }
    if id == "clean" { return .broom }
    if id == "teeth" { return .toothbrush }
    if id == "breath" { return .breath }
    if id == "plants" { return .leaf }
    if id == "music" { return .music }
    if id == "photo" { return .camera }
    if id == "laundry" { return .shirt }
    if id == "message" { return .envelope }
    if id == "thanks" { return .heart }
    if presetIcons.contains(preset.iconName) {
        return pochiIconKind(iconName: preset.iconName)
    }
    switch preset.category {
    case .care: return .heart
    case .home: return .broom
    case .learning: return .book
    case .connection: return .heart
    case .hobbies: return .sparkle
    }
}

private struct PochiRoomView: View {
    @AppStorage("pochiStrengthDays", store: appGroupDefaults) private var strengthDays = 0
    @AppStorage("pochiMuscleAppearance", store: appGroupDefaults) private var muscleAppearance = -1
    let muscleStageOverride: PochiMuscleStage?
    private var effectiveMuscleStage: PochiMuscleStage {
        muscleStageOverride ?? .visible(selection: muscleAppearance, earned: .earned(days: strengthDays))
    }
    @AppStorage("pochiBreed", store: appGroupDefaults) private var breedName = PochiBreed.shiba.rawValue
    @AppStorage("pochiCoat", store: appGroupDefaults) private var shibaCoatName = "kinako"
    @AppStorage("pochiCoat.dalmatian", store: appGroupDefaults) private var dalmatianCoatName = "kinako"
    @AppStorage("pochiCoat.pomeranian", store: appGroupDefaults) private var pomeranianCoatName = "kinako"
    private var effectiveCoat: PochiCoat {
        if breedOverride != nil { return coat }
        let raw: String
        switch effectiveBreed {
        case .shiba: raw = shibaCoatName
        case .dalmatian: raw = dalmatianCoatName
        case .pomeranian: raw = pomeranianCoatName
        }
        return PochiCoat(rawValue: raw) ?? .kinako
    }
    @AppStorage("isSubscribed") private var hasPremium = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    let coat: PochiCoat
    let activity: PochiRoomActivity
    let activityToken: Int
    let learnedHabits: PochiLifeHabits
    let worldState: PochiWorldState
    let breedOverride: PochiBreed?
    private var effectiveBreed: PochiBreed {
        if let breedOverride { return breedOverride }
        let selected = PochiBreed(rawValue: breedName) ?? .shiba
        return !selected.requiresPremium || hasPremium ? selected : .shiba
    }
    let compact: Bool
    let workoutPreset: HabitPreset?
    let onReady: ((PochiPixelRoomScene) -> Void)?
    @State private var isVisible = false
    @State private var roomScene: PochiPixelRoomScene

    init(coat: PochiCoat, activity: PochiRoomActivity, activityToken: Int, learnedHabits: PochiLifeHabits = .init(), worldState: PochiWorldState = .init(), breedOverride: PochiBreed? = nil, muscleStageOverride: PochiMuscleStage? = nil, compact: Bool = false, workoutPreset: HabitPreset? = nil, onReady: ((PochiPixelRoomScene) -> Void)? = nil) {
        self.learnedHabits = learnedHabits
        self.worldState = worldState
        self.breedOverride = breedOverride
        self.muscleStageOverride = muscleStageOverride
        self.workoutPreset = workoutPreset
        self.compact = compact
        self.onReady = onReady
        self.coat = coat
        self.activity = activity
        self.activityToken = activityToken
        _roomScene = State(initialValue: PochiPixelRoomScene(
            size: CGSize(width: 240, height: 320),
            coat: coat,
            activity: activity
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: roomScene)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.sky)
                .onAppear { if compact { roomScene.resizeCompactRoom(to: geometry.size) } }
                .onChange(of: geometry.size) { if compact { roomScene.resizeCompactRoom(to: $0) } }
                .accessibilityLabel(localizedText("四つ足の犬が一緒に筋トレをしたり、休んだりする画面"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { isVisible = true; roomScene.setDarkAppearance(colorScheme == .dark); roomScene.setMuscleStage(effectiveMuscleStage); roomScene.setBreed(effectiveBreed); roomScene.setCoat(effectiveCoat); roomScene.setLearnedHabits(learnedHabits); roomScene.setWorldState(worldState); roomScene.resumeLife(); onReady?(roomScene); roomScene.setWorkout(workoutPreset) }
        .onChange(of: workoutPreset) { roomScene.setWorkout($0) }
        .onChange(of: colorScheme) { roomScene.setDarkAppearance($0 == .dark) }
        .onChange(of: effectiveMuscleStage) { roomScene.setMuscleStage($0) }
        .onChange(of: effectiveBreed) { roomScene.setBreed($0); roomScene.setCoat(effectiveCoat) }
        .onChange(of: learnedHabits) { roomScene.setLearnedHabits($0) }
        .onChange(of: worldState) { roomScene.setWorldState($0) }
        .onDisappear { isVisible = false; roomScene.pauseLife() }
        .onChange(of: scenePhase) { phase in
            if phase == .active && isVisible { roomScene.resumeLife() } else { roomScene.pauseLife() }
        }
        .onChange(of: activityToken) { _ in roomScene.play(activity) }
        .onChange(of: effectiveCoat) { newValue in roomScene.setCoat(newValue) }
    }
}

private final class PochiPixelRoomScene: SKScene {
    private let dogDisplayScale: CGFloat = 4

    private typealias IdleMove = PochiIdleMove
    private var dailyRoutine = PochiDailyRoutine()
    private var togetherActivity: PochiRoomActivity?
    private var togetherEpisode = 0
    private var strollsRight = true
    private var lastRecordedActivity: PochiRoomActivity?

    private var muscleStage: PochiMuscleStage = .puppy
    private var breed: PochiBreed = .shiba
    private var coat: PochiCoat
    private var activity: PochiRoomActivity
    private var dog: SKSpriteNode!
    private var groundY: CGFloat = -12
    private var frameTextures: [SKTexture] = []
    private var backdrop: SKSpriteNode!
    private var floor: SKSpriteNode!
    private var floorLine: SKSpriteNode!
    private var displayedHour = Calendar.current.component(.hour, from: Date())
    private var usesDarkAppearance = false
    private var reactionQueue = PochiReactionQueue()
    private var activeRecordIDs: [String] = []
    private var learnedHabits: PochiLifeHabits = .init()
    private var worldState = PochiWorldState()
    private var scheduledPhase: PochiLifePhase?
    private var restUntil: TimeInterval = 0
    private var nightSettled = false
    private var routineNap = false
    var memoryStore: PochiMemoryStore?
    var memoryDogName = ""
    private var nextStoryTime = Date.timeIntervalSinceReferenceDate + 45
    var onWorkoutPhoto: ((UIImage, Date) -> Void)?
    private var workoutIcon: String?
    private var wantsWorkoutPhoto = false
    private var workoutPhotoReadyAt = Date.distantFuture
    private var workoutStartedAt: TimeInterval = 0
    private var isCoreWorkout: Bool {
        ["plank", "sidePlank", "birdDog", "deadBug"].contains(workoutIcon ?? "")
    }

    init(size: CGSize, coat: PochiCoat, activity: PochiRoomActivity) {
        self.coat = coat
        self.activity = activity
        super.init(size: size)
        scaleMode = .aspectFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.84, green: 0.82, blue: 0.72, alpha: 1)
    }

    required init?(coder: NSCoder) { nil }

    override func update(_ currentTime: TimeInterval) {
        if wantsWorkoutPhoto, workoutIcon != nil, togetherActivity == .strength, dog?.action(forKey: "reaction") == nil,
           Date() >= workoutPhotoReadyAt, let image = capture() {
            wantsWorkoutPhoto = false
            onWorkoutPhoto?(image, Date())
        }
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let phase = PochiLifePhase.at(now, calendar: Calendar.current)
        if phase != scheduledPhase, activity == .idle, activeRecordIDs.isEmpty, workoutIcon == nil {
            scheduledPhase = phase
            dog?.removeAction(forKey:"behavior")
            dog?.removeAction(forKey:"reaction")
            dog?.position.y = groundY
            removeTemporaryItem()
            scheduleNextAutonomousMove(after:0.3)
        }
        ensureWorkoutAnimation()
        guard hour != displayedHour else { return }
        displayedHour = hour
        updatePalette()
    }

    override func didEvaluateActions() {
        guard workoutIcon != nil, togetherActivity == .strength, let dog, !isPaused else { return }
        if isCoreWorkout {
            let effort = PochiCoreEffort.sample(elapsed: Date.timeIntervalSinceReferenceDate - workoutStartedAt,
                                               reduceMotion: UIAccessibility.isReduceMotionEnabled)
            dog.position = CGPoint(x: effort.x, y: groundY + effort.y)
            if workoutIcon != "birdDog" {
                applyFrame((effort.bracing ? PochiPose.plankBrace : .plankExhale).rawValue)
            }
        }
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.backgroundColor = backgroundColor
        view.layer.magnificationFilter = .nearest
        view.layer.minificationFilter = .nearest
        view.isUserInteractionEnabled = true
        if children.isEmpty { buildGameScreen() }
        ensureWorkoutAnimation()
    }

    func resumeLife() {
        isPaused = false
        let phase = PochiLifePhase.at(Date(),calendar:Calendar.current)
        if scheduledPhase != phase, activity == .idle {
            dog?.removeAction(forKey:"behavior")
            dog?.removeAction(forKey:"reaction")
            dog?.position.y = groundY
            removeTemporaryItem()
        }
        if activity == .idle, dog?.action(forKey: "behavior") == nil {
            scheduleNextAutonomousMove(after: 0.5)
        }
        ensureWorkoutAnimation()
    }

    func setTogetherActivity(_ newActivity: PochiRoomActivity?) {
        guard togetherActivity != newActivity else { return }
        togetherActivity = newActivity
        togetherEpisode = 0
        guard dog != nil, activeRecordIDs.isEmpty else { return }
        dog.removeAction(forKey: "behavior")
        dog.removeAction(forKey: "reaction")
        removeTemporaryItem()
        routineNap = false
        nightSettled = false
        restUntil = 0
        startActivity(.idle)
    }

    func pauseLife() {
        isPaused = true
    }

    func setDarkAppearance(_ isDark: Bool) {
        guard usesDarkAppearance != isDark else { return }
        usesDarkAppearance = isDark
        updatePalette()
    }

    func capture() -> UIImage? {
        guard let texture = view?.texture(from: self, crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }

    func setWorldState(_ state: PochiWorldState) {
        worldState = state
    }

    func setLearnedHabits(_ habits: PochiLifeHabits) {
        learnedHabits = habits
        memoryStore?.discover(habits)
    }

    func enqueueReaction(_ activity: PochiRoomActivity, id: String) {
        guard !activeRecordIDs.contains(id) else { return }
        reactionQueue.enqueue(id: id, activity: activity)
        if activeRecordIDs.isEmpty { startNextReaction() }
    }

    private func startNextReaction() {
        guard dog != nil, let next = reactionQueue.next() else { return }
        activeRecordIDs = next.recordIDs
        startActivity(next.activity)
    }

    func cancelReaction(id: String) {
        reactionQueue.cancel(id: id)
        guard activeRecordIDs.contains(id) else { return }
        activeRecordIDs.removeAll { $0 == id }
        if activeRecordIDs.isEmpty {
            childNode(withName: "pochi-completion-cue")?.removeFromParent()
            routineNap = false
            restUntil = 0
            nightSettled = false
            startActivity(.idle)
        }
    }

    func play(_ newActivity: PochiRoomActivity) {
        if newActivity == .idle { startActivity(.idle) }
        else { enqueueReaction(newActivity, id: UUID().uuidString) }
    }

    #if DEBUG
    /// Repeats the production animation without creating a completion or record.
    func previewStrengthMove(_ move: PochiIdleMove) {
        guard dog != nil else { return }
        activity = .strength
        dog.removeAllActions()
        removeTemporaryItem()
        dog.position.y = groundY
        dog.yScale = dogDisplayScale
        dog.zRotation = 0
        dog.run(.repeatForever(autonomousAction(move)), withKey: "behavior")
    }
    #endif

    private func startActivity(_ newActivity: PochiRoomActivity) {
        guard dog != nil else { activity = newActivity; return }
        activity = newActivity
        nightSettled = false
        if newActivity != .sleep && newActivity != .idle { routineNap = false; restUntil = 0 }
        dog.removeAction(forKey: "behavior")
        dog.removeAction(forKey: "reaction")
        dog.removeAction(forKey: "workout")
        dog.xScale = dogDisplayScale
        dog.yScale = dogDisplayScale
        dog.zRotation = 0
        dog.position.y = groundY
        applyFrame(PochiPose.stand.rawValue)
        removeTemporaryItem()
        if newActivity != .idle { showCompletionCue() }

        switch newActivity {
        case .idle:
            if reactionQueue.batches.isEmpty { scheduleNextAutonomousMove(after: 0.25) } else { startNextReaction() }
        case .eat:
            performMeal()
        case .drink:
            performDrink()
        case .sleep:
            performSleep()
        case .exercise:
            performExercise()
        case .strength:
            performStrength()
        case .study:
            performStudy()
        case .clean:
            performClean()
        case .selfCare:
            performSelfCare()
        case .joy:
            performJoy()
        case .stretch: performStretch()
        case .stroll: performStroll()
        case .rest: performRest()
        case .breathe: performBreathing()
        case .read: performRest()
        case .wash: performWash()
        case .listen: performListening()
        case .pose: performPhotoPose()
        }
    }

    func setMuscleStage(_ stage: PochiMuscleStage) {
        guard muscleStage != stage else { return }
        muscleStage = stage
        guard dog != nil else { return }
        let currentActivity = activity
        dog.removeAllActions()
        dog.removeFromParent()
        frameTextures.removeAll(keepingCapacity: true)
        removeTemporaryItem()
        buildDog()
        startActivity(currentActivity)
    }

    func setBreed(_ newValue: PochiBreed) {
        guard breed != newValue else { return }
        breed = newValue
        guard dog != nil else { return }
        // Restart only the current visual with its new atlas; queued record IDs survive.
        let currentActivity = activity
        dog.removeAllActions()
        dog.removeFromParent()
        frameTextures.removeAll()
        removeTemporaryItem()
        buildDog()
        startActivity(currentActivity)
    }

    func setCoat(_ newValue: PochiCoat) {
        guard coat != newValue else { return }
        coat = newValue
        guard dog != nil else { return }
        // Changing appearance cancels the current visual action and resumes it
        // using the new sheet, exactly as changing breed does.
        let currentActivity = activity
        dog.removeAllActions()
        dog.removeFromParent()
        frameTextures.removeAll(keepingCapacity: true)
        removeTemporaryItem()
        buildDog()
        startActivity(currentActivity)
    }

    private func buildGameScreen() {
        removeAllChildren()
        frameTextures.removeAll(keepingCapacity: true)
        buildBackdrop()
        buildDog()
        play(.idle)
    }

    private func buildBackdrop() {
        backdrop = SKSpriteNode(color: .clear, size: size)
        backdrop.position = .zero
        backdrop.zPosition = 0
        addChild(backdrop)

        floor = SKSpriteNode(color: .clear, size: CGSize(width: size.width, height: 212))
        floor.position = CGPoint(x: 0, y: -54)
        floor.zPosition = 1
        addChild(floor)

        floorLine = SKSpriteNode(color: .clear, size: CGSize(width: size.width, height: 3))
        floorLine.position = CGPoint(x: 0, y: 52)
        floorLine.zPosition = 2
        addChild(floorLine)
        updatePalette()
    }

    private func updatePalette() {
        let isNight = displayedHour >= 20 || displayedHour < 6
        let isTwilight = (displayedHour >= 6 && displayedHour < 8) || (displayedHour >= 18 && displayedHour < 20)
        var wall = isNight
            ? UIColor(red: 0.50, green: 0.56, blue: 0.62, alpha: 1)
            : (isTwilight ? UIColor(red: 0.86, green: 0.72, blue: 0.63, alpha: 1) : UIColor(red: 0.88, green: 0.86, blue: 0.77, alpha: 1))
        var ground = isNight
            ? UIColor(red: 0.42, green: 0.51, blue: 0.53, alpha: 1)
            : (isTwilight ? UIColor(red: 0.65, green: 0.71, blue: 0.59, alpha: 1) : UIColor(red: 0.70, green: 0.77, blue: 0.64, alpha: 1))
        var seam = isNight ? UIColor(red: 0.32, green: 0.40, blue: 0.43, alpha: 1) : UIColor(red: 0.50, green: 0.59, blue: 0.44, alpha: 1)
        if usesDarkAppearance {
            wall = isNight ? UIColor(red: 0.12, green: 0.17, blue: 0.20, alpha: 1)
                : (isTwilight ? UIColor(red: 0.24, green: 0.19, blue: 0.18, alpha: 1) : UIColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1))
            ground = isNight ? UIColor(red: 0.17, green: 0.24, blue: 0.25, alpha: 1)
                : (isTwilight ? UIColor(red: 0.25, green: 0.29, blue: 0.22, alpha: 1) : UIColor(red: 0.23, green: 0.30, blue: 0.23, alpha: 1))
            seam = UIColor(red: 0.36, green: 0.45, blue: 0.35, alpha: 1)
        }
        backdrop?.color = wall
        backdrop?.colorBlendFactor = 1
        floor?.color = ground
        floor?.colorBlendFactor = 1
        floorLine?.color = seam
        floorLine?.colorBlendFactor = 1
        backgroundColor = wall
        view?.backgroundColor = wall
    }

    private func buildDog() {
        let base = PochiBreedSprites.atlas(for: breed) ?? UIImage(named: "pochiPixelAtlas")!.cgImage!
        let motion = PochiMotionSprites.atlas(for: breed, base: base) ?? base
        let image = coat.applying(to: PochiMuscleSprites.atlas(base: motion, breed: breed, stage: muscleStage), breed: breed)
        let atlas = SKTexture(cgImage: image)
        atlas.filteringMode = .nearest
        let columns = PochiMuscleSprites.columns, rows = PochiMuscleSprites.rows
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: 1 - CGFloat(row + 1) / CGFloat(rows),
                    width: 1 / CGFloat(columns),
                    height: 1 / CGFloat(rows)
                )
                let texture = SKTexture(rect: rect, in: atlas)
                texture.filteringMode = .nearest
                frameTextures.append(texture)
            }
        }
        dog = SKSpriteNode(texture: frameTextures[3], size: CGSize(width: 32, height: 32))
        groundY = -12
        dog.position = CGPoint(x: 0, y: groundY)
        dog.zPosition = 10
        dog.xScale = dogDisplayScale
        dog.yScale = dogDisplayScale
        addChild(dog)
    }

    private func pixelRect(_ size: CGSize, color: UIColor, at point: CGPoint, z: CGFloat = 1, parent: SKNode) {
        let node = SKSpriteNode(color: color, size: CGSize(width: max(1, round(size.width)), height: max(1, round(size.height))))
        node.position = CGPoint(x: round(point.x), y: round(point.y))
        node.zPosition = z
        parent.addChild(node)
    }

    private func showBowl(at point: CGPoint, water: Bool = false) -> SKNode {
        let item = SKNode()
        item.name = "pochi-temporary-item"
        item.position = point
        item.zPosition = 8
        item.setScale(0.2)
        item.alpha = 0
        let rim = UIColor(red: 0.70, green: 0.82, blue: 0.80, alpha: 1)
        let bowl = UIColor(red: 0.37, green: 0.53, blue: 0.60, alpha: 1)
        let food = UIColor(red: 0.80, green: 0.57, blue: 0.32, alpha: 1)
        pixelRect(CGSize(width: 32, height: 5), color: bowl, at: CGPoint(x: 0, y: -3), parent: item)
        pixelRect(CGSize(width: 36, height: 5), color: rim, at: CGPoint(x: 0, y: 1), z: 1, parent: item)
        pixelRect(CGSize(width: 16, height: 3), color: water ? UIColor(red: 0.40, green: 0.73, blue: 0.84, alpha: 1) : food, at: CGPoint(x: 0, y: 5), z: 2, parent: item)
        addChild(item)
        item.run(.group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.18)]))
        return item
    }

    private func showCushion(at point: CGPoint) -> SKNode {
        let item = SKNode()
        item.name = "pochi-temporary-item"
        item.position = point
        item.zPosition = 7
        item.setScale(0.2)
        item.alpha = 0
        pixelRect(CGSize(width: 70, height: 14), color: UIColor(red: 0.53, green: 0.38, blue: 0.34, alpha: 1), at: CGPoint(x: 0, y: -4), parent: item)
        pixelRect(CGSize(width: 62, height: 14), color: UIColor(red: 0.79, green: 0.58, blue: 0.55, alpha: 1), at: .zero, z: 1, parent: item)
        pixelRect(CGSize(width: 18, height: 6), color: UIColor(red: 0.94, green: 0.82, blue: 0.72, alpha: 1), at: CGPoint(x: -20, y: 5), z: 2, parent: item)
        addChild(item)
        item.run(.group([.fadeIn(withDuration: 0.20), .scale(to: 1, duration: 0.20)]))
        return item
    }

    private func showSparkles() -> SKNode {
        let item = SKNode()
        item.name = "pochi-temporary-item"
        item.zPosition = 12
        item.position = CGPoint(x: dog.position.x, y: dog.position.y + 44)
        let gold = UIColor(red: 0.94, green: 0.76, blue: 0.36, alpha: 1)
        let pink = UIColor(red: 0.89, green: 0.52, blue: 0.48, alpha: 1)
        for (index, point) in [CGPoint(x: -48, y: 5), CGPoint(x: 44, y: 14), CGPoint(x: 30, y: -20), CGPoint(x: -30, y: -18)].enumerated() {
            let color = index.isMultiple(of: 2) ? gold : pink
            pixelRect(CGSize(width: 3, height: 3), color: color, at: point, parent: item)
            pixelRect(CGSize(width: 3, height: 3), color: color, at: CGPoint(x: point.x - 3, y: point.y - 3), parent: item)
            pixelRect(CGSize(width: 3, height: 3), color: color, at: CGPoint(x: point.x + 3, y: point.y + 3), parent: item)
        }
        addChild(item)
        item.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.32), .fadeAlpha(to: 1, duration: 0.32)])))
        return item
    }

    private func removeTemporaryItem() {
        childNode(withName: "pochi-temporary-item")?.removeAllActions()
        childNode(withName: "pochi-temporary-item")?.removeFromParent()
    }

    private func dismiss(_ item: SKNode?) -> SKAction {
        guard let item else { return .wait(forDuration: 0) }
        return .run { [weak item] in
            item?.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 0.75, duration: 0.25)]), .removeFromParent()]))
        }
    }

    private var motionTempo: Double {
        switch breed { case .shiba: return 1.5; case .dalmatian: return 1.45; case .pomeranian: return 1.55 }
    }

    private func applyFrame(_ index: Int) {
        dog.texture = frameTextures[index]

    }

    private func frames(_ poses: [PochiPose], each duration: Double = 0.16) -> SKAction {
        frameSequence(poses.map(\.rawValue), each: duration * motionTempo)
    }

    private func frameSequence(_ indices: [Int], each duration: Double) -> SKAction {
        .sequence(indices.flatMap { index in
            [SKAction.run { [weak self] in self?.applyFrame(index) }, .wait(forDuration: duration)]
        })
    }

    private func walk(to destination: CGPoint, duration: TimeInterval) -> SKAction {
        let duration = duration * motionTempo
        let cycle = 0.9 * motionTempo
        let count = max(1, Int(ceil(duration / cycle)))
        let walking = SKAction.repeat(frameSequence([0, 1, 2, 3], each: duration / Double(count * 4)), count: count)
        return .sequence([
            .run { [weak self] in
                self?.groundY = destination.y
                self?.face(right: destination.x >= (self?.dog.position.x ?? 0))
            },
            .group([walking, .move(to: destination, duration: duration)]),
            frames([.stand], each: 0.08)
        ])
    }

    private func idleFrames(duration: TimeInterval = 0.5) -> SKAction {
        frames([.stand, .blink, .stand], each: duration / 3)
    }

    private func wagFrames(duration: TimeInterval = 0.9) -> SKAction {
        frames([.stand, .tailUp, .tailDown, .tailUp, .tailDown, .stand], each: duration / 6)
    }

    private func jump() -> SKAction {
        let height: CGFloat = breed == .pomeranian ? 7 : breed == .dalmatian ? 13 : 10
        return .sequence([
            frames([.jumpReady], each: 0.12), frames([.stand], each: 0.04),
            .moveBy(x: 0, y: height, duration: 0.16 * motionTempo),
            .moveBy(x: 0, y: -height, duration: 0.19 * motionTempo),
            frames([.landing, .stand], each: 0.12)
        ])
    }

    private func settleToSleep() -> SKAction {
        .sequence([
            frames([.stand, .crouch, .sit], each: 0.22),
            frames([.sitBlink, .yawnSmall, .yawnWide, .yawnSmall, .sit], each: 0.2),
            frames([.drowsy, .crouch, .lie, .lieBlink, .sleep], each: 0.26)
        ])
    }

    private func wakeUp() -> SKAction {
        frames([.sleep, .lieBlink, .lie, .wake, .crouch, .sit, .stand], each: 0.2)
    }

    private func stretch() -> SKAction {
        .sequence([frames([.stand, .stretchStart, .stretchFull], each: 0.23),
                   .wait(forDuration: 0.5), frames([.stretchStart, .stand], each: 0.23)])
    }

    private func finishToIdle(after delay: TimeInterval = 0.45) -> SKAction {
        .sequence([.wait(forDuration: delay), .run { [weak self] in
            guard let self else { return }
            self.removeTemporaryItem()
            if self.activity != .idle {
                self.dailyRoutine.didComplete(self.activity)
                self.lastRecordedActivity = self.activity.learningActivity
                self.nextStoryTime = max(self.nextStoryTime, Date.timeIntervalSinceReferenceDate + 90)
            }
            self.activity = .idle
            self.dog.xScale = self.dogDisplayScale
            self.dog.yScale = self.dogDisplayScale
            self.dog.zRotation = 0
            self.activeRecordIDs = []
            if self.reactionQueue.batches.isEmpty { self.scheduleNextAutonomousMove(after: 1.5) } else { self.startNextReaction() }
        }])
    }

    private func performDrink() {
        let bowl = showBowl(at: CGPoint(x: 48, y: -60), water: true)
        dog.run(.sequence([
            walk(to: CGPoint(x: 8, y: -22), duration: 0.8),
            frames([.stand, .eatUp, .mealLower, .eatDown], each: 0.2),
            .repeat(frames([.eatDown, .lick, .eatDown, .lick], each: 0.12), count: 4),
            frames([.mealLower, .eatUp, .stand], each: 0.2),
            wagFrames(), dismiss(bowl), finishToIdle()
        ]), withKey: "behavior")
    }

    private func performMeal() {
        let target = CGPoint(x: 8, y: -22)
        let bowl = showBowl(at: CGPoint(x: 48, y: -60))
        dog.run(.sequence([
            wagFrames(duration: 0.5), walk(to: target, duration: 0.82),
            frames([.stand, .eatUp, .mealLower, .eatDown], each: 0.18),
            .repeat(frames([.eatUp, .mealLower, .eatDown, .lick, .eatDown], each: 0.16), count: 3),
            frames([.eatUp, .stand], each: 0.18), wagFrames(duration: 0.85),
            dismiss(bowl), finishToIdle(after: 0.25)
        ]), withKey: "behavior")
    }

    private func performSleep() {
        restUntil = Date.timeIntervalSinceReferenceDate + 120
        routineNap = true
        let cushion = showCushion(at: CGPoint(x: 0, y: -76))
        dog.run(.sequence([
            walk(to: CGPoint(x: 0, y: -16), duration: 0.75), settleToSleep(),
            .repeat(frames([.sleep, .breathe], each: 0.8), count: 3),
            .run { [weak self] in
                if PochiLifePhase.at(Date(),calendar:Calendar.current) == .deepNight { self?.nightSettled = true }
            },
            dismiss(cushion), finishToIdle(after: 0.35)
        ]), withKey: "behavior")
    }

    private func performStrength() {
        if UIAccessibility.isReduceMotionEnabled {
            dog.run(.sequence([frames([muscleStage.rawValue >= 2 ? .proudChest : .sit], each: 2), finishToIdle()]), withKey: "behavior")
            return
        }
        let celebration = muscleStage.rawValue >= 2 ? autonomousAction(.proudPose) : wagFrames(duration: 1.5)
        dog.run(.sequence([autonomousAction(.squats), celebration, finishToIdle()]), withKey: "behavior")
    }

    private func performExercise() {
        dog.run(.sequence([
            stretch(), walk(to: CGPoint(x: 26, y: -18), duration: 0.62), jump(),
            walk(to: CGPoint(x: -26, y: -18), duration: 0.76), stretch(),
            wagFrames(duration: 0.9), finishToIdle(after: 0.25)
        ]), withKey: "behavior")
    }

    private func performStretch() {
        dog.run(.sequence([stretch(), .wait(forDuration: 2),
            frames([.crouch, .sit, .sitBlink, .sit], each: 0.35),
            .wait(forDuration: 3), frames([.crouch, .stand], each: 0.3),
            wagFrames(duration: 1.2), finishToIdle()]), withKey: "behavior")
    }

    private func performStroll() {
        dog.run(.sequence([
            walk(to: CGPoint(x: -22, y: -18), duration: 1.5),
            frames([.look, .tilt, .look], each: 0.4), .wait(forDuration: 2),
            walk(to: CGPoint(x: 22, y: -18), duration: 2),
            frames([.look, .lookBlink, .look], each: 0.4),
            wagFrames(duration: 1.2), finishToIdle()]), withKey: "behavior")
    }

    private func performRest() {
        dog.run(.sequence([
            frames([.crouch, .lie, .lieBlink, .lie], each: 0.4),
            .wait(forDuration: 8), frames([.lieBlink, .lie], each: 0.4),
            .wait(forDuration: 6), frames([.wake, .crouch, .sit, .stand], each: 0.35),
            finishToIdle()]), withKey: "behavior")
    }

    private func performBreathing() {
        dog.run(.sequence([
            frames([.crouch, .sit], each: 0.4),
            .repeat(.sequence([.wait(forDuration: 3), frames([.sitBlink, .sit], each: 0.35)]), count: 3),
            frames([.crouch, .stand], each: 0.35), finishToIdle()]), withKey: "behavior")
    }

    private func performWash() {
        let bubbles = SKNode()
        bubbles.name = "pochi-temporary-item"
        bubbles.zPosition = 12
        addChild(bubbles)
        for (index, offset) in [CGPoint(x: -58, y: 5), CGPoint(x: 55, y: 18), CGPoint(x: -40, y: 55), CGPoint(x: 36, y: 65)].enumerated() {
            let bubble = SKNode()
            bubble.position = CGPoint(x: dog.position.x + offset.x, y: dog.position.y + offset.y)
            bubbles.addChild(bubble)
            let color = UIColor(red: 0.84, green: 0.94, blue: 0.94, alpha: 1)
            pixelRect(CGSize(width: 6, height: 2), color: color, at: CGPoint(x: 0, y: 4), parent: bubble)
            pixelRect(CGSize(width: 6, height: 2), color: color, at: CGPoint(x: 0, y: -4), parent: bubble)
            pixelRect(CGSize(width: 2, height: 6), color: color, at: CGPoint(x: -4, y: 0), parent: bubble)
            pixelRect(CGSize(width: 2, height: 6), color: color, at: CGPoint(x: 4, y: 0), parent: bubble)
            bubble.run(.sequence([.wait(forDuration: Double(index) * 0.35),
                .moveBy(x: 0, y: 12, duration: 3), .fadeOut(withDuration: 0.8)]))
        }
        dog.run(.sequence([frames([.look, .lookBlink, .look], each: 0.45),
            wagFrames(duration: 1.8), .wait(forDuration: 1), dismiss(bubbles),
            finishToIdle()]), withKey: "behavior")
    }

    private func performListening() {
        dog.run(.sequence([frames([.look, .tilt, .look], each: 0.4),
            .wait(forDuration: 3), frames([.tiltOther, .look, .lookBlink, .look], each: 0.4),
            .wait(forDuration: 3), wagFrames(duration: 1.5), finishToIdle()]), withKey: "behavior")
    }

    private func performPhotoPose() {
        dog.run(.sequence([walk(to: CGPoint(x: 0, y: -18), duration: 1.2),
            frames([.look, .lookBlink, .look], each: 0.4),
            .wait(forDuration: 5), finishToIdle()]), withKey: "behavior")
    }

    private func performClean() {
        dog.run(.sequence([
            walk(to:CGPoint(x:0,y:-18),duration:0.65),
            frames([.look,.tilt,.look],each:0.25),
            .run { [weak self] in _ = self?.showSparkles() },
            wagFrames(duration:1.2), jump(), finishToIdle(after:0.3)
        ]),withKey:"behavior")
    }

    private func nightRest() -> SKAction {
        let settle = nightSettled ? SKAction.wait(forDuration:0) : settleToSleep()
        nightSettled = true
        return .sequence([
            settle,
            .repeat(frames([.sleep,.breathe],each:1.25),count:4),
            .run { [weak self] in self?.scheduleNextAutonomousMove(after:0.5) }
        ])
    }

    private func performStudy() {
        dog.run(.sequence([
            walk(to: CGPoint(x: -12, y: -18), duration: 0.7),
            frames([.crouch, .sit, .sitBlink], each: 0.25),
            .wait(forDuration: 5.0), frames([.sitBlink, .sit], each: 0.38),
            .wait(forDuration: 0.6), frames([.look, .tilt, .look], each: 0.3),
            wagFrames(), finishToIdle(after: 0.35)
        ]), withKey: "behavior")
    }

    private func performSelfCare() {
        let sparkles = showSparkles()
        dog.run(.sequence([
            frames([.sit, .sitBlink, .sit], each: 0.4), wagFrames(duration: 1.6), dismiss(sparkles),
            finishToIdle(after: 0.25)
        ]), withKey: "behavior")
    }

    private func performJoy() {
        let sparkles = showSparkles()
        dog.run(.sequence([
            frames([.look, .lookBlink, .look], each: 0.35), wagFrames(duration: 1.4), dismiss(sparkles),
            finishToIdle(after: 0.25)
        ]), withKey: "behavior")
    }

    private func showCompletionCue() {
        let cue = SKNode()
        cue.name = "pochi-completion-cue"
        cue.position = CGPoint(x: 0, y: 112)
        cue.zPosition = 30
        let label = SKLabelNode(text: localizedText("できた！"))
        label.fontName = "PixelMplus12-Bold"
        label.fontSize = 12
        label.fontColor = UIColor(red: 0.36, green: 0.35, blue: 0.26, alpha: 1)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.numberOfLines = 1
        cue.addChild(label)
        let gold = UIColor(red: 0.94, green: 0.76, blue: 0.36, alpha: 1)
        for point in [CGPoint(x: -40, y: 1), CGPoint(x: 40, y: 1)] {
            pixelRect(CGSize(width: 3, height: 3), color: gold, at: point, parent: cue)
            pixelRect(CGSize(width: 3, height: 3), color: gold, at: CGPoint(x: point.x + (point.x < 0 ? -3 : 3), y: 4), parent: cue)
        }
        addChild(cue)
        cue.run(.sequence([.wait(forDuration: 1.1), .fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func scheduleNextAutonomousMove(after delay: TimeInterval) {
        guard activity == .idle, view != nil, !isPaused else { return }
        let phase = PochiLifePhase.at(Date(), calendar: Calendar.current)
        scheduledPhase = phase
        if let togetherActivity {
            let episode: SKAction
            if togetherActivity == .strength, workoutIcon != nil {
                ensureWorkoutAnimation()
                return
            } else {
                let moves = PochiTogetherRoutine.moves(for: togetherActivity, muscleLevel: muscleStage.rawValue)
                let move = moves[togetherEpisode % moves.count]; togetherEpisode += 1
                episode = UIAccessibility.isReduceMotionEnabled ? frames([.sit], each: 12) : autonomousAction(move)
            }
            dog.run(.sequence([.wait(forDuration: delay), episode,
                .run { [weak self] in self?.scheduleNextAutonomousMove(after: 3) }
            ]), withKey: "behavior")
            return
        }
        if phase != .deepNight && nightSettled {
            nightSettled = false
            routineNap = false
            dog.run(.sequence([wakeUp(),.run { [weak self] in self?.scheduleNextAutonomousMove(after:1) }]),withKey:"behavior")
            return
        }
        if phase == .deepNight {
            routineNap = false
            removeTemporaryItem()
            dog.run(nightRest(),withKey:"behavior")
            return
        }
        if routineNap && Date.timeIntervalSinceReferenceDate < restUntil {
            dog.run(.sequence([frames([.sleep,.breathe],each:1),.run { [weak self] in self?.scheduleNextAutonomousMove(after:1) }]),withKey:"behavior")
            return
        }
        if routineNap {
            routineNap = false
            dog.run(.sequence([wakeUp(),.run { [weak self] in self?.scheduleNextAutonomousMove(after:1) }]),withKey:"behavior")
            return
        }
        var storyActivities: [PochiRoomActivity] = phase == .evening ? [.sleep] : [.exercise, .sleep]
        if let recent = lastRecordedActivity, storyActivities.contains(recent) {
            storyActivities.removeAll { $0 == recent }
            storyActivities.insert(recent, at: 0)
        }
        if Date.timeIntervalSinceReferenceDate >= nextStoryTime,
           let story = memoryStore?.pendingStory(among: storyActivities) {
            playStory(story, delay: delay)
            return
        }
        let step = dailyRoutine.next(phase: phase, now: Date.timeIntervalSinceReferenceDate,
            world: worldState, habits: learnedHabits)
        let move: IdleMove = muscleStage.rawValue >= 2 && step.move == .look && phase == .morning ? .proudPose
            : muscleStage.rawValue >= 3 && step.move == .look && phase == .daytime ? .proudWalk : step.move
        dog.run(.sequence([
            .wait(forDuration: delay),
            autonomousAction(move),
            .run { [weak self] in self?.scheduleNextAutonomousMove(after: step.pause) }
        ]), withKey: "behavior")
    }

    private func playStory(_ story: PochiStory, delay: TimeInterval) {
        // Mark complete only after the visible scene was captured and saved.
        // Interrupted scenes remain pending and can be experienced on a later visit.
        nextStoryTime = Date.timeIntervalSinceReferenceDate + 240
        let moment: SKAction
        switch story.activity {
        case .exercise:
            moment = .sequence([
                walk(to: CGPoint(x: 0, y: -18), duration: 0.7),
                frames([.look, .tilt, .stand], each: 0.3),
                story.stage >= 1 ? stretch() : idleFrames(),
                story.stage == 2 ? jump() : wagFrames(), frames([.look], each: 0.3)
            ])
        default:
            moment = .sequence([
                .run { [weak self] in _ = self?.showCushion(at: CGPoint(x: 0, y: -76)) },
                walk(to: CGPoint(x: 0, y: -16), duration: 0.8),
                story.stage == 0 ? frames([.look, .tilt, .sit], each: 0.4) : autonomousAction(.yawn),
                story.stage == 2 ? settleToSleep() : frames([.sit, .sitBlink], each: 0.5)
            ])
        }
        dog.run(.sequence([
            .wait(forDuration: max(delay, 2)), moment, .wait(forDuration: 0.6),
            .wait(forDuration: 2),
            (story.stage == 2 && story.activity != .exercise)
                ? wakeUp() : frames([.sitBlink, .sit, .crouch, .stand], each: 0.18),
            .run { [weak self] in self?.removeTemporaryItem() },
            .run { [weak self] in self?.scheduleNextAutonomousMove(after: 3) }
        ]), withKey: "behavior")
    }

    func resizeCompactRoom(to viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        // Match the wide card's aspect ratio, so the entire dog stays visible.
        size = CGSize(width: viewport.width / viewport.height * 160, height: 160)
        backdrop?.size = size
        floor?.size.width = size.width
        floorLine?.size.width = size.width
    }

    func setWorkout(_ preset: HabitPreset?) {
        let icon = preset?.iconName
        let changed = workoutIcon != icon
        workoutIcon = icon
        if changed {
            dog?.removeAction(forKey: "workout")
            dog?.zRotation = 0
            dog?.position = CGPoint(x: 0, y: groundY)
            workoutStartedAt = Date.timeIntervalSinceReferenceDate
            workoutPhotoReadyAt = Date().addingTimeInterval(2)
            wantsWorkoutPhoto = preset != nil
        }
        setTogetherActivity(preset == nil ? nil : .strength)
        if changed, preset != nil, dog != nil {
            // A newly started set takes priority over the previous completion
            // celebration. Otherwise its reaction can overwrite training frames.
            dog.removeAction(forKey: "behavior")
            dog.removeAction(forKey: "reaction")
            childNode(withName: "pochi-completion-cue")?.removeFromParent()
            activeRecordIDs = []
            reactionQueue = PochiReactionQueue()
            activity = .idle
            groundY = -12
            dog.position = CGPoint(x: 0, y: groundY)
            dog.xScale = dogDisplayScale
            dog.yScale = dogDisplayScale
            scheduleNextAutonomousMove(after: 0.1)
        }
        ensureWorkoutAnimation()
    }

    /// SpriteView can reattach after navigation or a layout change. Restore the
    /// active exercise if its action was removed while the scene was detached.
    private func ensureWorkoutAnimation() {
        guard workoutIcon != nil, togetherActivity == .strength,
              let dog, view != nil, !isPaused, dog.action(forKey: "workout") == nil else { return }
        activity = .idle
        dog.removeAction(forKey: "reaction")
        dog.removeAction(forKey: "behavior")
        dog.run(.repeatForever(workoutAction()), withKey: "workout")
    }

    private func workoutAction() -> SKAction {
        let icon = workoutIcon ?? "pushup"
        let core = ["plank", "sidePlank", "birdDog", "deadBug"].contains(icon)
        let motion: SKAction
        switch icon {
        case "squat", "figure.strengthtraining.traditional": motion = frames([.stand, .squatLow], each: 0.45)
        case "pushup", "figure.strengthtraining.functional": motion = frames([.pushupHigh, .pushupLow], each: 0.45)
        case "crunch":
            motion = frames([.plank, .plankBrace, .plankBrace, .plank], each: 0.4)
        case "plank": motion = frames([.plank], each: 8)
        case "sidePlank":
            motion = .group([frames([.plank], each: 8),
                .sequence([.rotate(toAngle: 0.08, duration: 0.5), .wait(forDuration: 11.5)])])
        case "birdDog": motion = frames([.plank, .birdDogLeft, .birdDogLeft, .plank, .birdDogRight, .birdDogRight], each: 0.55)
        case "deadBug": motion = frames([.plank], each: 8)
        case "lunge": motion = .repeat(frames([.stand, .stretchStart, .squatLow, .stand], each: 0.75), count: 4)
        case "bridge": motion = frames([.squatLow, .stand, .stand, .squatLow], each: 0.45)
        case "calf":
            motion = .repeat(.sequence([frames([.stand], each: 0.4),
                .moveBy(x: 0, y: 3, duration: 0.7), .wait(forDuration: 0.5),
                .moveBy(x: 0, y: -3, duration: 0.7)]), count: 5)
        default: motion = frames([.toyLiftLow, .toyLiftHigh], each: 0.65)
        }
        if UIAccessibility.isReduceMotionEnabled {
            if core { return frames([.plank], each: 12) }
            // Keep deliberate exercise poses slow for Reduce Motion.
            motion.speed = 0.6
            return motion
        }
        return motion
    }

    private func autonomousAction(_ move: IdleMove) -> SKAction {
        switch move {
        case .pushups:
            return .sequence([walk(to: CGPoint(x: 0, y: -18), duration: 1.2),
                frames([.stretchStart, .pushupHigh], each: 0.4),
                .repeat(.sequence([frames([.pushupHigh], each: 0.8),
                    frames([.pushupLow], each: 1.0), frames([.pushupHigh], each: 0.8),
                    .wait(forDuration: 0.8)]), count: 4),
                frames([.plank], each: 2), frames([.stretchStart, .stand, .sit], each: 0.4),
                .wait(forDuration: 4), frames([.stand], each: 0.4)])
        case .squats:
            return .sequence([frames([.stand, .look, .stand], each: 0.35),
                .repeat(.sequence([frames([.squatLow], each: 1),
                    frames([.stand], each: 1), .wait(forDuration: 0.6)]), count: 4),
                frames([.sit, .sitBlink, .sit], each: 0.5), .wait(forDuration: 4),
                frames([.stand], each: 0.3)])
        case .dumbbells:
            return .sequence([frames([.stand, .pushupHigh, .toyLiftLow], each: 0.4),
                .repeat(frames([.toyLiftLow, .toyLiftHigh, .toyLiftHigh, .toyLiftLow], each: 0.7), count: 4),
                frames([.pushupLow, .pushupHigh, .stand], each: 0.4),
                .wait(forDuration: 4)])
        case .proudPose:
            return .sequence([frames([.stand, .proudTail], each: 0.4),
                .wait(forDuration: 0.5), frames([.proudChest], each: 2.5),
                .run { [weak self] in _ = self?.showSparkles() },
                frames([.proudTail, .proudChest], each: 1.5),
                .run { [weak self] in self?.removeTemporaryItem() },
                frames([.look, .stand], each: 0.4)])
        case .proudWalk:
            return .sequence([walk(to: CGPoint(x: -22, y: -18), duration: 1.8),
                frames([.proudTail], each: 2), walk(to: CGPoint(x: 22, y: -18), duration: 2),
                frames([.proudChest], each: 3), frames([.look, .stand], each: 0.4)])
        case .togetherListen:
            return .sequence([frames([.look, .tilt, .look], each: 0.5),
                .wait(forDuration: 6), frames([.tiltOther, .lookBlink, .look], each: 0.5),
                .wait(forDuration: 6), wagFrames(duration: 2),
                frames([.crouch, .sit], each: 0.4), .wait(forDuration: 10),
                frames([.sitBlink, .sit, .stand], each: 0.4)])
        case .togetherBreathe:
            return .sequence([frames([.crouch, .lie], each: 0.5),
                .repeat(frames([.lie, .breathe, .lieBlink, .lie], each: 2), count: 3),
                wakeUp()])
        case .specialRest:
            return .sequence([walk(to: CGPoint(x: 0, y: -24), duration: 1.8),
                frames([.look, .lookBlink], each: 0.4), settleToSleep(),
                .repeat(frames([.sleep, .breathe], each: 1.8), count: 12), wakeUp()])
        case .playInvite:
            return .sequence([frames([.look, .tilt, .stand], each: 0.25), stretch(),
                              wagFrames(duration: 0.6), jump(), wagFrames(duration: 0.6)])
        case .bedtime:
            return .sequence([autonomousAction(.yawn), settleToSleep(),
                              .repeat(frames([.sleep, .breathe], each: 1.8), count: 16), wakeUp()])
        case .careRelax:
            return .sequence([stretch(), frames([.crouch, .lie, .lieBlink], each: 0.3),
                              .wait(forDuration: 1.8), wakeUp(), wagFrames(duration: 0.6)])
        case .cozyRest:
            return .sequence([walk(to: CGPoint(x: 0, y: -24), duration: 0.9),
                              frames([.look, .lookBlink, .crouch, .lie, .lieBlink], each: 0.3),
                              .wait(forDuration: 12), frames([.lie, .lieBlink, .lie], each: 0.5),
                              .wait(forDuration: 10), wakeUp()])
        case .welcome:
            return .sequence([walk(to: CGPoint(x: 0, y: -28), duration: 0.65),
                              frames([.look, .tilt, .look], each: 0.22), jump(),
                              wagFrames(duration: 1.2)])
        case .walk:
            let limit = max(8, min(size.width * 0.22, size.width * 0.5 - dog.size.width * dogDisplayScale * 0.5 - 6))
            // A short purposeful stroll, followed by sitting in the routine.
            let destination = CGPoint(x: strollsRight ? limit * 0.65 : -limit * 0.65, y: -18)
            strollsRight.toggle()
            return .sequence([walk(to: destination, duration: 1.8), idleFrames(duration: 1)])
        case .sit:
            return .sequence([frames([.stand, .crouch, .sit], each: 0.22),
                              .wait(forDuration: 8), frames([.sitBlink, .sit], each: 0.25),
                              .wait(forDuration: 6), frames([.crouch, .stand], each: 0.3)])
        case .look:
            return .sequence([frames([.stand, .look, .lookBlink, .look], each: 0.22),
                              .wait(forDuration: 0.8), frames([.stand])])
        case .tilt:
            return .sequence([frames([.look, .tilt], each: 0.25), .wait(forDuration: 0.5),
                              frames([.look, .tiltOther, .look, .stand], each: 0.25)])
        case .stretch: return stretch()
        case .nap:
            return .sequence([settleToSleep(), .repeat(frames([.sleep, .breathe], each: 1.6), count: 12), wakeUp()])
        case .hop: return .sequence([jump(), wagFrames(duration: 0.6)])
        case .togetherRead, .togetherTidy, .shelfLook, .deskWatch, .ballPlay, .readRest:
            return autonomousAction(.cozyRest)
        case .blink: return .sequence([idleFrames(), .wait(forDuration: 1.2), idleFrames()])
        case .ears: return frames([.stand, .ear, .stand, .earBack, .stand], each: 0.2)
        case .wag: return wagFrames(duration: 1.4)
        case .approach:
            return .sequence([walk(to: CGPoint(x: 0, y: -28), duration: 0.9),
                              frames([.look, .lookBlink, .look], each: 0.25), wagFrames()])
        case .yawn:
            return frames([.crouch, .sit, .sitBlink, .yawnSmall, .yawnWide, .yawnSmall, .sit, .stand], each: 0.25)
        }
    }

    private func face(right: Bool) {
        // All motion atlases face left; mirror only when walking right.
        dog.xScale = right ? -dogDisplayScale : dogDisplayScale
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard workoutIcon == nil, activity == .idle, dog.action(forKey: "reaction") == nil, let point = touches.first?.location(in: self), dog.contains(point) else { return }
        if PochiLifePhase.at(Date(),calendar:Calendar.current) == .deepNight {
            dog.removeAction(forKey:"behavior")
            dog.run(.sequence([frames([.lieBlink,.lie,.lieBlink],each:0.3),
                .run { [weak self] in self?.scheduleNextAutonomousMove(after:0.3) }]),withKey:"reaction")
            return
        }
        dog.removeAction(forKey: "behavior")
        removeTemporaryItem()
        dog.yScale = dogDisplayScale
        dog.zRotation = 0
        face(right: point.x >= dog.position.x)
        dog.position.y = groundY
        dog.run(.sequence([
            walk(to: CGPoint(x: 0, y: -28), duration: 0.65),
            frames([.look, .lookBlink, .look, .tilt, .look], each: 0.18),
            .run { [weak self] in _ = self?.showSparkles() },
            wagFrames(duration: 0.8),
            .run { [weak self] in self?.removeTemporaryItem() },
            .run { [weak self] in self?.scheduleNextAutonomousMove(after: 0.6) }
        ]), withKey: "reaction")
    }
}

private struct PochiPortrait: View {
    @AppStorage("pochiStrengthDays", store: appGroupDefaults) private var strengthDays = 0
    @AppStorage("pochiMuscleAppearance", store: appGroupDefaults) private var muscleAppearance = -1
    @AppStorage("pochiCoat", store: appGroupDefaults) private var coatName = PochiCoat.kinako.rawValue
    let imageName: String
    let collarColor: Color
    let width: CGFloat
    let height: CGFloat
    var coatOverride: PochiCoat? = nil
    var charmOverride: String? = nil

    private var coat: PochiCoat {
        coatOverride ?? PochiCoat(rawValue: coatName) ?? .kinako
    }

    @AppStorage("pochiBreed", store: appGroupDefaults) private var breedName = "shiba"
    @AppStorage("isSubscribed") private var hasPremium = false
    @AppStorage("pochiCoat.dalmatian", store: appGroupDefaults) private var dalmatianCoatName = "kinako"
    @AppStorage("pochiCoat.pomeranian", store: appGroupDefaults) private var pomeranianCoatName = "kinako"
    private var portrait: UIImage? {
        let selected = PochiBreed(rawValue: breedName) ?? .shiba
        let breed: PochiBreed = !selected.requiresPremium || hasPremium ? selected : .shiba
        let raw = breed == .shiba ? coatName : breed == .dalmatian ? dalmatianCoatName : pomeranianCoatName
        let selectedCoat = (breed == .shiba ? coatOverride : nil) ?? PochiCoat(rawValue: raw) ?? .kinako
        guard let base = PochiBreedSprites.atlas(for: breed) ?? UIImage(named: "pochiPixelAtlas")?.cgImage,
              let atlas = PochiMotionSprites.atlas(for: breed, base: base) else { return nil }
        let frame = imageName == "done" ? 6 : 3
        let muscular = PochiMuscleSprites.atlas(base: atlas, breed: breed,
            stage: .visible(selection: muscleAppearance, earned: .earned(days: strengthDays)))
        return selectedCoat.applying(to: muscular, breed: breed)
            .cropping(to: CGRect(x: frame % 4 * 32, y: frame / 4 * 32, width: 32, height: 32)).map { UIImage(cgImage: $0) }
    }
    var body: some View {
        Group {
            if let portrait { Image(uiImage: portrait).resizable().interpolation(.none).scaledToFit() }
        }.frame(width: width, height: height)
    }
}

private struct PochiProfileEditor: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var previewBreed: PochiBreed = .shiba
    @State private var showingUpgrade = false
    @State private var previewActivity: PochiRoomActivity = .idle
    @State private var previewToken = 0

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldIsFocused: Bool
    @State private var pochiName: String
    @State private var coatName: String

    @State private var dalmatianCoatName: String
    @State private var pomeranianCoatName: String
    private var visiblePochiName: String { displayPochiName(pochiName) }

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        _previewBreed = State(initialValue: PochiBreed(rawValue: appGroupDefaults.string(forKey: "pochiBreed") ?? "shiba") ?? .shiba)
        _pochiName = State(initialValue: appGroupDefaults.string(forKey: "pochiName") ?? "ぽち")
        _coatName = State(initialValue: appGroupDefaults.string(forKey: "pochiCoat") ?? "kinako")
        _dalmatianCoatName = State(initialValue: appGroupDefaults.string(forKey: "pochiCoat.dalmatian") ?? "kinako")
        _pomeranianCoatName = State(initialValue: appGroupDefaults.string(forKey: "pochiCoat.pomeranian") ?? "kinako")
    }

    private func saveProfile() {
        guard !previewBreed.requiresPremium || subscriptionManager.isSubscribed else {
            showingUpgrade = true
            return
        }
        let name = pochiName.trimmingCharacters(in: .whitespacesAndNewlines)
        appGroupDefaults.set(name.isEmpty ? "ぽち" : name, forKey: "pochiName")
        appGroupDefaults.set(previewBreed.rawValue, forKey: "pochiBreed")
        appGroupDefaults.set(coatName, forKey: "pochiCoat")
        appGroupDefaults.set(dalmatianCoatName, forKey: "pochiCoat.dalmatian")
        appGroupDefaults.set(pomeranianCoatName, forKey: "pochiCoat.pomeranian")
        WidgetCenter.shared.reloadAllTimelines()
        nameFieldIsFocused = false
        dismiss()
    }

    private var selectedCoat: PochiCoat {
        PochiCoat(rawValue: previewBreed == .shiba ? coatName : previewBreed == .dalmatian ? dalmatianCoatName : pomeranianCoatName) ?? .kinako
    }

    private var breedPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("犬種").font(pochiPixelFont(14))
            ForEach(PochiBreed.allCases) { breed in
                Button {
                    previewBreed = breed
                    previewActivity = .joy
                    previewToken += 1
                } label: {
                    HStack {
                        Text(localizedText(breed.titleKey))
                        Spacer()
                        if breed.requiresPremium && !subscriptionManager.isSubscribed {
                            Text("プレミアム").font(pochiPixelFont(11))
                        }
                        if previewBreed == breed { PochiPixelGlyph(kind: .check, color: .grassDark, size: 16) }
                    }.font(pochiPixelFont(14)).padding(.horizontal, 12).frame(minHeight: 48)
                        .background(previewBreed == breed ? Color.mist : Color.cream, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.grassDark, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityAddTraits(previewBreed == breed ? .isSelected : [])
            }
            HStack {
                Button("筋トレ") { previewActivity = .strength; previewToken += 1 }
                Button("ひとやすみ") { previewActivity = .sleep; previewToken += 1 }
            }.font(pochiPixelFont(13)).buttonStyle(.bordered).frame(minHeight: 44)
            if previewBreed.requiresPremium && !subscriptionManager.isSubscribed {
                Text("動きをおためし中です。購入するまで見た目は変わりません。")
                    .font(pochiPixelFont(12)).fixedSize(horizontal: false, vertical: true)
                PochiPrimaryButton(title: localizedText("全部入りプランを見る")) { showingUpgrade = true }
            }
        }.foregroundStyle(Color.cocoa)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        PochiRoomView(
                            coat: selectedCoat,
                            activity: previewActivity,
                            activityToken: previewToken,
                            breedOverride: previewBreed
                        )
                        .frame(height: 208)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        Text("\(visiblePochiName)と、これからも一緒")
                            .font(pochiPixelFont(13))
                            .foregroundStyle(Color.cocoa)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.mist.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))

                    breedPicker

                    VStack(alignment: .leading, spacing: 10) {
                        Text("なまえ")
                            .font(pochiPixelFont(13))
                            .foregroundStyle(Color.cocoa)
                        TextField("ぽち", text: $pochiName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .textFieldStyle(PochiRetroFieldStyle())
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cocoa.opacity(0.25), lineWidth: 1))
                            .focused($nameFieldIsFocused)
                            .onChange(of: pochiName) { newValue in
                                if newValue.count > 12 {
                                    pochiName = String(newValue.prefix(12))
                                }
                            }
                        Text("いつでも変えられるよ")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cocoa.opacity(0.58))
                    }

                    PochiCoatPicker(breed: previewBreed, selection: selectedCoat) { coat in
                        switch previewBreed {
                        case .shiba: coatName = coat.rawValue
                        case .dalmatian: dalmatianCoatName = coat.rawValue
                        case .pomeranian: pomeranianCoatName = coat.rawValue
                        }
                    }

                }
                .padding(20)
            }
            .background(Color.cream.ignoresSafeArea())
            .sheet(isPresented: $showingUpgrade) {
                PaywallSheet(subscriptionManager: subscriptionManager, isPresented: $showingUpgrade)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ぽちのプロフィール")
                        .font(pochiPixelFont(13))
                        .foregroundStyle(Color.cocoa)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存する", action: saveProfile)
                    .font(pochiPixelFont(11))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        nameFieldIsFocused = false
                        dismiss()
                    }
                    .font(pochiPixelFont(11))
                }
            }
            .toolbarBackground(Color.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct InstantLogCard: View {
    let preset: HabitPreset

    var body: some View {
        VStack(spacing: 10) {
            PresetIconView(name: preset.iconName, size: 64, tint: preset.tint)
            Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
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
    @AppStorage("pochiName", store: appGroupDefaults) private var pochiName = "ぽち"
    @AppStorage("pochiCollarTint", store: appGroupDefaults) private var collarTintName = PresetTint.peach.rawValue
    @AppStorage("pochiCoat", store: appGroupDefaults) private var coatName = PochiCoat.kinako.rawValue
    @AppStorage("pochiCharm", store: appGroupDefaults) private var charmName = PochiCharm.heart.rawValue

    let preset: HabitPreset
    let isAlreadyDone: Bool
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
                        Text(isAlreadyDone ? "今日はもうできたよ" : "できた")
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
                    .disabled(isCompleting || isAlreadyDone)
                    .opacity(isAlreadyDone ? 0.65 : 1)

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
            Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                .font(.title2.bold())
                .foregroundStyle(Color.cocoa)
        }
        .frame(maxWidth: .infinity)
    }

    private var back: some View {
        VStack(spacing: 16) {
            PochiRoomView(
                coat: PochiCoat(rawValue: coatName) ?? .kinako,
                activity: .joy,
                activityToken: isFlipped ? 1 : 0
            )
            .frame(height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("\(displayPochiName(pochiName))に伝えた！")
                .font(.title2.bold())
                .foregroundStyle(Color.candyBlue)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PresetGridView: View {
    @AppStorage("pochiCollarTint", store: appGroupDefaults) private var collarTintName = PresetTint.peach.rawValue

    let presets: [HabitPreset]
    let selectedPresetID: String
    let completionsThisWeek: [String: Int]
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
                    let completedThisWeek = min(completionsThisWeek[preset.id, default: 0], preset.weeklyTarget)
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        ZStack {
                            if isDoneToday {
                                PochiPortrait(
                                    imageName: "pochiGreeting",
                                    collarColor: (PresetTint(rawValue: collarTintName) ?? .peach).color,
                                    width: 88,
                                    height: 88
                                )
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundStyle(Color.candyBlue)
                                            .background(Circle().fill(Color.cream))
                                    }
                            } else {
                                PresetIconView(
                                    name: preset.iconName,
                                    size: 88,
                                    tint: selectedPresetID == preset.id ? Color.pochiOnAccent : Color.cocoa
                                )
                            }
                        }
                        Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                            .font(.title3.bold())
                        Text(localizedFormat("今週 %lld / %lld 回", completedThisWeek, preset.weeklyTarget))
                            .font(.caption.bold())
                            .foregroundStyle(completedThisWeek >= preset.weeklyTarget ? Color.grassDark : Color.cocoa.opacity(0.62))
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
                            .foregroundStyle(selectedPresetID == preset.id ? Color.pochiOnAccent.opacity(0.95) : Color.candyBlue)
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
                            Text("種目名")
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

private struct PochiHabitChip: View {
    let preset: HabitPreset
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                WorkoutIcon(name: preset.iconName, size: 24)
                Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                    .font(pochiPixelFont(13))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                if isDone {
                    PochiPixelGlyph(kind: .check, color: Color.grassDark, size: 16)
                } else {
                    PochiPixelGlyph(kind: .empty, color: Color.cocoa.opacity(0.55), size: 14)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isDone ? Color.grassDark : Color.cocoa)
            .background(isDone ? Color(red: 0.85, green: 0.90, blue: 0.78) : Color(red: 0.97, green: 0.93, blue: 0.84), in: RoundedRectangle(cornerRadius: 5, style: .circular))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .circular).stroke(isDone ? Color.grassDark : Color.cocoa.opacity(0.75), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(isDone)
        .accessibilityLabel(localizedFormat("%@ %@", localizedPresetTitle(id: preset.id, storedTitle: preset.title) as NSString, localizedText(isDone ? "達成済み" : "記録する") as NSString))
    }
}

private struct WeeklyDotsCard: View {
    let days: [Date]
    let logsByDay: [String: [HabitLog]]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private var weekdaySymbols: [String] {
        localizedWeekdaySymbols()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今週の足あと")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.cocoa)
                Spacer()
                Text("できた日がふえていくよ")
                    .font(.caption)
                    .foregroundStyle(Color.cocoa.opacity(0.58))
            }

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

private struct HabitTemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingIDs: Set<String>
    let onSelect: (HabitPreset) -> Void
    var body: some View {
        NavigationStack {
            List(initialSelectablePresets) { preset in
                Button { onSelect(preset) } label: {
                    HStack(spacing: 12) {
                        PochiPixelGlyph(kind: .dumbbell, color: .grassDark, size: 24)
                        Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                            .font(pochiPixelFont(14)).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if existingIDs.contains(preset.id) { Text("登録済み").font(pochiPixelFont(11)) }
                    }.frame(minHeight: 44)
                }.disabled(existingIDs.contains(preset.id))
                    .listRowBackground(Color.cream)
            }.scrollContentBackground(.hidden).background(Color.cream).foregroundStyle(Color.cocoa)
                .navigationTitle(localizedText("種目を選ぶ")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}

private struct InitialPresetPickerSheet: View {
    private enum OnboardingStep: Int {
        case meet = 0
        case choose = 1
        case ready = 2
    }

    @AppStorage("pochiName", store: appGroupDefaults) private var pochiName = "ぽち"
    @AppStorage("pochiCoat", store: appGroupDefaults) private var coatName = PochiCoat.kinako.rawValue
    @State private var step: OnboardingStep = .meet
    @State private var editedBasics: [HabitPreset] = PochiWorkoutCatalog.presets
    @State private var editingBasic: HabitPreset?
    @State private var onboardingPlan = WorkoutPlan()
    @State private var customPresets: [HabitPreset] = []
    @State private var showingCustomHabitEditor = false
    @State private var roomActivity: PochiRoomActivity = .idle
    @State private var activityToken = 0

    let presets: [HabitPreset]
    let onSelect: ([HabitPreset]) -> Void

    private var allPresets: [HabitPreset] { editedBasics + customPresets }
    private var selectedPresets: [HabitPreset] {
        allPresets
    }
    private var chosenCoat: PochiCoat { PochiCoat(rawValue: coatName) ?? .kinako }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Group {
                    switch step {
                    case .meet: meetPochi
                    case .choose: choosePromises
                    case .ready: readyToStart
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                navigationControls
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(Color.cream)
            }
            .background(Color.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingBasic) { preset in
                NavigationStack {
                    Form { WorkoutPlanFields(plan: $onboardingPlan) }
                        .navigationTitle(preset.title).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("保存する") {
                                if let i = editedBasics.firstIndex(where: { $0.id == preset.id }) { editedBasics[i] = preset.withPlan(onboardingPlan) }
                                if let i = customPresets.firstIndex(where: { $0.id == preset.id }) { customPresets[i] = preset.withPlan(onboardingPlan) }
                                editingBasic = nil
                            }
                        } }
                }
            }
            .sheet(isPresented: $showingCustomHabitEditor) {
                InitialCustomHabitSheet(category: .care) { preset in
                    customPresets.append(preset)
                    roomActivity = .joy
                    activityToken += 1
                }
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index <= step.rawValue ? Color.grassDark : Color.grassEmpty)
                    .frame(height: 5)
            }
        }
        .accessibilityLabel(localizedFormat("3つのステップの%d番目", step.rawValue + 1))
    }

    private var meetPochi: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ぽちと、筋トレをはじめよう")
                        .font(pochiPixelFont(22))
                        .foregroundStyle(Color.cocoa)
                    Text("ひとりだと続かない筋トレも、ぽちと一緒に。")
                        .font(.subheadline)
                        .foregroundStyle(Color.cocoa.opacity(0.68))
                }

                Button {
                    roomActivity = .joy
                    activityToken += 1
                } label: {
                    PochiRoomView(
                        coat: chosenCoat,
                        activity: roomActivity,
                        activityToken: activityToken,
                        muscleStageOverride: .puppy
                    )
                    .frame(height: 248)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        PochiPixelGlyph(kind: .heart, color: Color.peach, size: 20)
                            .padding(12)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("ぽちをタップして反応を見る"))

                Button {
                    roomActivity = .strength
                    activityToken += 1
                } label: {
                    Text("ぽちの筋トレを見てみる").font(pochiPixelFont(14)).frame(minHeight: 44)
                }
                Text("おためしなので、記録には残りません").font(pochiPixelFont(12)).foregroundStyle(Color.cocoa.opacity(0.7))
                Text("回数や時間を決めて、できたら記録。ぽちと一緒に続けよう。")
                    .font(.subheadline).foregroundStyle(Color.cocoa.opacity(0.8))


                VStack(alignment: .leading, spacing: 8) {
                    Text("なまえ")
                        .font(pochiPixelFont(14))
                        .foregroundStyle(Color.cocoa)
                    TextField("ぽち", text: $pochiName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .textFieldStyle(PochiRetroFieldStyle())
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cocoa.opacity(0.28), lineWidth: 1.5))
                        .onChange(of: pochiName) { value in
                            if value.count > 12 { pochiName = String(value.prefix(12)) }
                        }
                }

                PochiCoatPicker(breed: .shiba, selection: chosenCoat) { coat in
                    coatName = coat.rawValue
                }

            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var choosePromises: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("基本メニューを準備しました").font(pochiPixelFont(20))
                Text("そのまま始めても、回数・時間を変えても大丈夫。あとからいつでも編集できます。")
                    .font(.subheadline)
                ForEach(allPresets) { preset in
                    Button { onboardingPlan = preset.workoutPlan; editingBasic = preset } label: {
                        HStack(spacing: 12) {
                            WorkoutIcon(name: preset.iconName, size: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title)).font(pochiPixelFont(14))
                                Text(preset.workoutPlan.summary).font(.caption)
                            }
                            Spacer(); Image(systemName: "pencil")
                        }.padding(12).frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.pochiSurface, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                Button("自分の種目を追加") { showingCustomHabitEditor = true }.frame(minHeight: 48)
            }.padding(22).foregroundStyle(Color.cocoa)
        }
    }

    private var readyToStart: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 5) {
                    Text("準備ができたら、ぽちと始めよう")
                        .font(pochiPixelFont(21))
                        .foregroundStyle(Color.cocoa)
                    Text("今日の筋トレも、ぽちと一緒に。")
                        .font(.subheadline)
                        .foregroundStyle(Color.cocoa.opacity(0.68))
                }
                PochiRoomView(
                    coat: chosenCoat,
                    activity: .strength,
                    activityToken: activityToken,
                    muscleStageOverride: .puppy
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onAppear {
                    roomActivity = .strength
                    activityToken += 1
                }
                Text("種目を選んでスタート。時間の種目はセットごとにカウントダウンします。")
                    .font(.subheadline).multilineTextAlignment(.center)
                Text("休む日があっても大丈夫。自分のペースで続けよう。")
                    .font(.caption).foregroundStyle(Color.cocoa.opacity(0.68))
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日からの筋トレ")
                        .font(pochiPixelFont(14))
                        .foregroundStyle(Color.cocoa)
                    if selectedPresets.isEmpty {
                        Text("基本メニューはそのまま始められます。").font(pochiPixelFont(13))
                    } else {
                        ForEach(selectedPresets) { preset in
                            promiseSummary(preset)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func promiseSummary(_ preset: HabitPreset) -> some View {
        HStack(spacing: 9) {
            WorkoutIcon(name: preset.iconName, size: 24)
            Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                .font(pochiPixelFont(13))
                .foregroundStyle(Color.cocoa)
                .lineLimit(1)
            Spacer()
            Text(preset.workoutPlan.summary)
                .font(.caption)
                .foregroundStyle(Color.cocoa.opacity(0.58))
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
        .background(Color.pochiSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 5))
    }

    private var navigationControls: some View {
        HStack(spacing: 12) {
            if step != .meet {
                PochiOutlineButton(title: localizedText("もどる")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = step == .ready ? .choose : .meet
                    }
                }
            }
            PochiPrimaryButton(title: localizedText(step == .ready ? "ぽちと筋トレをはじめる" : "つぎへ")) {
                switch step {
                case .meet:
                    withAnimation(.easeInOut(duration: 0.2)) { step = .choose }
                case .choose:
                    withAnimation(.easeInOut(duration: 0.2)) { step = .ready }
                case .ready:
                    onSelect(PochiWorkoutCatalog.initialSelection(selectedPresets))
                }
            }
            .accessibilityHint(localizedText(step == .ready ? "選んだ種目を保存して筋トレのホームを開きます" : "次のステップへ進みます"))
        }
    }
}

private struct InitialCustomHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var iconName = "dumbbell.fill"
    @State private var plan = WorkoutPlan()
    let category: HabitCategory
    let onAdd: (HabitPreset) -> Void
    var body: some View {
        PresetEditorSheet(title: $title, iconName: $iconName, plan: $plan, existingIDs: [], onTemplate: { _ in }, canDelete: false,
            onSave: {
                onAdd(HabitPreset(id: PochiWorkoutCatalog.customID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    iconName: iconName, tintName: .peach, workoutPlan: plan))
                dismiss()
            }, onDelete: {}, onCancel: { dismiss() })
    }
}

private struct PresetEditorSheet: View {
    @Binding var title: String
    @Binding var iconName: String
    @Binding var plan: WorkoutPlan
    let existingIDs: Set<String>
    let onTemplate: (HabitPreset) -> Void
    let canDelete: Bool
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    @State private var confirmingDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("種目の名前") { TextField("例：ベンチプレス", text: $title) }
                Section("回数・時間") { WorkoutPlanFields(plan: $plan) }
                Section("アイコンを選ぶ") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(PochiWorkoutCatalog.presets) { preset in
                            Button { iconName = preset.iconName } label: {
                                VStack(spacing: 6) {
                                    WorkoutIcon(name: preset.iconName, size: 32)
                                    Text(preset.title).font(.caption2).lineLimit(2)
                                }.frame(maxWidth: .infinity, minHeight: 72)
                                    .background(iconName == preset.iconName ? Color.mist : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).accessibilityAddTraits(iconName == preset.iconName ? .isSelected : [])
                        }
                    }
                }
                if canDelete { Button("種目を削除", role: .destructive) { confirmingDelete = true } }
            }.scrollContentBackground(.hidden).background(Color.cream)
                .navigationTitle(canDelete ? "種目を編集" : "自分の種目を追加").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("やめる", action: onCancel) } }
                .safeAreaInset(edge: .bottom) {
                    PochiPrimaryButton(title: localizedText("保存する"), isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: onSave)
                        .padding().background(Color.cream)
                }
                .confirmationDialog("この種目を削除しますか？", isPresented: $confirmingDelete) {
                    Button("けす", role: .destructive, action: onDelete)
                }
        }
    }
}

private struct HabitGrassCard: View {
    let days: [Date]
    let selectedDate: Date
    let displayedMonth: Date
    let logsByDay: [String: [HabitLog]]
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var weekdaySymbols: [String] {
        localizedWeekdaySymbols()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("できたのあしあと")
                .font(pochiPixelFont(14))
                .foregroundStyle(Color.cocoa)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { label in
                    Text(label)
                        .font(pochiPixelFont(11))
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
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.day()))
                                .font(pochiPixelFont(11))
                                .opacity(localeAwareGregorianCalendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) ? 1 : 0.4)
                            if count > 0 {
                                PochiPixelGlyph(kind: .paw, color: count > 1 ? .pochiOnAccent : .cocoa, size: 12)
                            } else {
                                Color.clear.frame(width: 12, height: 12)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(count > 1 ? Color.pochiOnAccent : Color.cocoa)
                        .background(fillColor(count: count, selected: isSameDay(day, selectedDate)), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(isSameDay(day, selectedDate) ? Color.cocoa : .clear, lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel(dayTitleFormatter.string(from: day))
                    .accessibilityValue(Text("\(count)"))
                    .accessibilityAddTraits(isSameDay(day, selectedDate) ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.pochiSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cocoa.opacity(0.22), lineWidth: 1))
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
                Text(localizedFormat("%@ のきろく", dayTitleFormatter.string(from: date) as NSString))
                    .font(pochiPixelFont(14))
                    .foregroundStyle(Color.cocoa)
                Spacer()
                if canAdd {
                    Button("追加") {
                        onAdd()
                    }
                    .font(pochiPixelFont(12))
                    .foregroundStyle(Color.grassDark)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }

            if logs.isEmpty {
                    Text(localizedText("きょうから、すこしずつ。"))
                    .font(pochiPixelFont(13))
                    .foregroundStyle(Color.cocoa.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
            } else {
                ForEach(logs) { log in
                    HStack(spacing: 12) {
                        Text(logTimeFormatter.string(from: log.completedAt))
                            .font(pochiPixelFont(12).monospacedDigit())
                            .foregroundStyle(Color.cocoa.opacity(0.7))
                            .frame(width: 60, alignment: .leading)

                        let iconInfo = iconForLog(log)
                        PresetIconView(name: iconInfo.name, size: 24, tint: iconInfo.tint)
                            .frame(width: 28, height: 28)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizedPresetTitle(id: log.presetID, storedTitle: log.title))
                                .font(pochiPixelFont(13))
                                .foregroundStyle(Color.cocoa)
                            ForEach(log.workouts) { workout in
                                Text(workout.values.map { String($0) }.joined(separator: " / ") + " " + localizedText(workout.plan.mode == .timed ? "秒" : "回"))
                                    .font(pochiPixelFont(12)).foregroundStyle(Color.grassDark)
                            }
                        }
                        Spacer()
                        Button {
                            pendingDeleteLog = log
                        } label: {
                            VStack(spacing: 3) {
                                PochiPixelGlyph(kind: .trash, color: Color.cocoa, size: 24)
                                Text("削除").font(pochiPixelFont(11))
                            }.frame(width: 44).frame(minHeight: 48)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 10)
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.pochiSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cocoa.opacity(0.22), lineWidth: 1))
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
    let onAdd: (HabitPreset, [Int]) -> Bool
    let onCancel: () -> Void
    @State private var selected: HabitPreset?
    var body: some View {
        NavigationStack {
            List(presets) { preset in
                Button { selected = preset } label: {
                    HStack(spacing: 12) {
                        WorkoutIcon(name: preset.iconName)
                        VStack(alignment: .leading) { Text(preset.title); Text(preset.workoutPlan.summary).font(.caption) }
                    }.frame(minHeight: 52)
                }
            }.navigationTitle("きろくを追加").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("やめる", action: onCancel) } }
                .sheet(item: $selected) { preset in
                    WorkoutResultSheet(preset: preset, values: [preset.workoutPlan.target],
                        onSave: { onAdd(preset, $0) }, onCancel: { selected = nil })
                }
        }
    }
}


#Preview {
    ContentView()
}

#if DEBUG
/// Displays real views with disposable sample bindings for appearance review.
struct PochiAppearanceReviewScreen: View {
    let screen: String
    @StateObject private var manager = SubscriptionManager()
    @State private var title = "腕立て伏せ"
    @State private var icon = "dumbbell.fill"
    @State private var tint = PresetTint.lavender
    @State private var reviewPlan = WorkoutPlan()
    @State private var trainingPreview: PochiPixelRoomScene?

    var body: some View {
        Group {
            switch screen {
            case "muscle0", "muscle1", "muscle2", "muscle3", "muscle4":
                let stage = PochiMuscleStage(rawValue: Int(screen.suffix(1)) ?? 0) ?? .puppy
                VStack(spacing: 12) {
                    Text(localizedText(stage.titleKey)).font(pochiPixelFont(22))
                    Text(localizedFormat("筋トレ %lld日", stage.requiredDays)).font(pochiPixelFont(16))
                    PochiRoomView(coat: .kinako, activity: .idle, activityToken: 0,
                        muscleStageOverride: stage) { scene in
                            trainingPreview = scene
                            scene.previewStrengthMove(.pushups)
                        }
                    HStack {
                        Button("腕立て") { trainingPreview?.previewStrengthMove(.pushups) }
                        Button("スクワット") { trainingPreview?.previewStrengthMove(.squats) }
                        Button("おもちゃ") { trainingPreview?.previewStrengthMove(.dumbbells) }
                        Button("しっぽ") { trainingPreview?.previewStrengthMove(.proudPose) }
                    }.font(pochiPixelFont(12)).buttonStyle(.bordered)
                }.padding(20)
            case "onboarding":
                InitialPresetPickerSheet(presets: initialSelectablePresets, onSelect: { _ in })
            case "add":
                PresetEditorSheet(title: $title, iconName: $icon, plan: $reviewPlan,
                    existingIDs: [], onTemplate: { _ in }, canDelete: false,
                    onSave: {}, onDelete: {}, onCancel: {})
            case "profile":
                PochiProfileEditor(subscriptionManager: manager)
            case "settings":
                SettingsView(subscriptionManager: manager, onEditPochi: {})
            case "records":
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            let today = Date()
                            let days = (-14...13).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
                            let log = HabitLog(presetID: "pushups", title: "腕立て伏せ", durationSeconds: 732)
                            HabitGrassCard(days: days, selectedDate: today, displayedMonth: today,
                                logsByDay: [ymdFormatter.string(from: today): [log, log]], onSelect: { _ in })
                            DayLogListCard(date: today, logs: [log], iconForLog: { _ in ("dumbbell.fill", .peach) },
                                canAdd: true, onAdd: {}, onDelete: { _ in })
                        }.padding(16)
                    }
                    .background(Color.cream)
                    .navigationTitle("きろく")
                    .toolbarBackground(Color.cream, for: .navigationBar)
                }
            default:
                PochiTodayCard(pochiName: "ぽち", collarColor: .peach, bondCharm: "heart",
                    chosenPresets: Array(initialSelectablePresets.prefix(3)), completedPresetIDsToday: [],
                    learnedHabits: .init(), worldState: .init(), onCustomize: {},
                    onAdd: {}, onEdit: { _ in }, onSceneReady: { _ in })
            }
        }
        .foregroundStyle(Color.cocoa)
        .background(Color.cream)
        .tint(Color.grassDark)
    }
}
#endif
