import Foundation

enum PochiPromiseTheme: String, Codable, CaseIterable {
    case reading, cleaning, exercise, studying, sleeping, general

    static func infer(_ preset: HabitPreset) -> Self {
        if preset.id.hasPrefix("strength.") || ["strength", "squats", "pushups", "dumbbells"].contains(preset.id) { return .exercise }
        let ids: [String: Self] = ["reading": .reading, "readingPage": .reading,
            "clean": .cleaning, "exercise": .exercise, "stretch": .exercise, "walk": .exercise,
            "outside": .exercise, "study": .studying, "studyQuestion": .studying,
            "language": .studying, "focus": .studying, "sleep": .sleeping, "sleepRoutine": .sleeping]
        let title = preset.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = Set(title.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        let terms: [(Self, [String], [String])] = [
            (.reading, ["読書", "読む", "読ん", "독서", "책 읽", "阅读", "閱讀", "读书", "讀書", "看书", "看書"], ["read", "reading", "book", "books"]),
            (.cleaning, ["掃除", "片づけ", "片付", "清掃", "청소", "정리", "打扫", "打掃", "清洁", "清潔", "整理房"], ["clean", "cleaning", "tidy", "vacuum"]),
            (.exercise, ["運動", "散歩", "筋トレ", "ストレッチ", "운동", "산책", "스트레칭", "运动", "運動", "散步", "锻炼", "鍛鍊"], ["exercise", "workout", "walk", "walking", "stretch", "stretching", "run", "running"]),
            (.studying, ["勉強", "学習", "공부", "학습", "学习", "學習", "語学", "외국어"], ["study", "studying", "learn", "learning"]),
            (.sleeping, ["早寝", "就寝", "眠る", "寝る", "睡眠", "布団", "잠자", "잠들", "취침", "수면", "早睡", "睡前", "睡觉", "睡覺"], ["sleep", "sleeping", "bedtime", "bed"])
        ]
        for (theme, phrases, english) in terms {
            if phrases.contains(where: title.contains) || !words.isDisjoint(with: english) { return theme }
        }
        if let theme = ids[preset.id] { return theme }
        switch preset.iconName.lowercased() {
        case "book", "book.fill", "book.closed.fill", "reading": return .reading
        case "clean", "broom", "trash", "house.fill": return .cleaning
        case "run", "walk", "figure.run", "figure.walk", "stretch", "exercise": return .exercise
        case "study", "textformat", "target": return .studying
        case "bed.double.fill", "moon.fill", "sleep": return .sleeping
        default: return preset.category == .learning ? .studying : .general
        }
    }
}

enum PochiGrowthPolicy {
    static let first = 3
    static let playful = 7
    static let favorite = 14
    static let special = 30
    static let maximumClutter = 3
}

/// Metadata only: never writes or migrates achievement history. Weekdays use
/// Calendar's 1...7 values. The current editor uses flexible weekly targets.
struct PochiWorldRule: Codable, Equatable {
    var theme: PochiPromiseTheme
    var weeklyTarget: Int
    var weekdays: Set<Int>?
    var startedAt: Date
    var timeZoneID: String
    var firstWeekday: Int

    init(preset: HabitPreset, now: Date, calendar: Calendar, weekdays: Set<Int>? = nil) {
        theme = .infer(preset)
        weeklyTarget = preset.weeklyTarget
        self.weekdays = weekdays.map { Set($0.filter { (1...7).contains($0) }) }
        startedAt = now
        timeZoneID = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
    }
    static func synchronize(_ saved: [String: Self], presets: [HabitPreset], now: Date, calendar: Calendar) -> [String: Self] {
        var result: [String: Self] = [:]
        for preset in presets {
            if let old = saved[preset.id], old.theme == .infer(preset), old.weeklyTarget == preset.weeklyTarget,
               old.timeZoneID == calendar.timeZone.identifier, old.firstWeekday == calendar.firstWeekday {
                result[preset.id] = old
            } else {
                // A changed theme/frequency starts a fresh observation period.
                result[preset.id] = Self(preset: preset, now: now, calendar: calendar)
            }
        }
        return result
    }
}

enum PochiLifePhase: Equatable {
    case morning, daytime, evening, deepNight
    static func at(_ date: Date, calendar: Calendar) -> Self {
        switch calendar.component(.hour, from: date) {
        case 6..<10: return .morning
        case 10..<19: return .daytime
        case 19..<23: return .evening
        default: return .deepNight
        }
    }
}

struct PochiWorldState: Equatable {
    var activeThemes: Set<PochiPromiseTheme> = []
    var clutter: [PochiPromiseTheme: Int] = [:]
    var growth: [PochiPromiseTheme: Int] = [:]
    var totalCompletions = 0
    var phase: PochiLifePhase = .daytime

    struct ClutterObject: Equatable {
        let theme: PochiPromiseTheme
        let slot: Int
    }
    /// Slots are reserved by registered themes, not by current mess. Tidying one
    /// theme must never reveal more mess or move objects in another theme.
    var clutterObjects: [ClutterObject] {
        let themes = [PochiPromiseTheme.reading, .cleaning, .studying].filter { activeThemes.contains($0) }
        guard !themes.isEmpty else { return [] }
        return (0..<PochiGrowthPolicy.maximumClutter).compactMap { slot in
            let theme = themes[slot % themes.count]
            let level = slot / themes.count + 1
            return clutter[theme, default:0] >= level ? ClutterObject(theme:theme,slot:slot) : nil
        }
    }
    var visibleClutter: [PochiPromiseTheme] { clutterObjects.map(\.theme) }

    static func evaluate(presets: [HabitPreset], logs: [HabitLog], rules: [String: PochiWorldRule], now: Date, calendar: Calendar) -> Self {
        var state = Self(phase: .at(now, calendar: calendar))
        let active = Dictionary(presets.map { ($0.id, PochiPromiseTheme.infer($0)) }, uniquingKeysWith: { first, _ in first })
        state.activeThemes = Set(active.values).subtracting([.general])
        // Group once: evaluation stays linear in the amount of saved history.
        let validLogs = logs.filter { $0.completedAt <= now }
        let byPreset = Dictionary(grouping:validLogs, by: \.presetID)
        let byTheme = Dictionary(grouping:presets) { PochiPromiseTheme.infer($0) }
        var latestByTheme: [PochiPromiseTheme: Date] = [:]
        var unique: [String: Set<Date>] = [:]
        for log in validLogs {
            unique[log.presetID, default: []].insert(calendar.startOfDay(for: log.completedAt))
            if let theme = active[log.presetID] {
                latestByTheme[theme] = max(latestByTheme[theme] ?? log.completedAt, log.completedAt)
            }
        }
        for (id, dates) in unique {
            state.totalCompletions += dates.count
            let theme = active[id] ?? .general
            state.growth[theme, default: 0] += dates.count
        }
        for theme in state.activeThemes {
            let relevant = byTheme[theme] ?? []
            let latest = latestByTheme[theme]
            var count = 0
            for preset in relevant {
                guard let rule = rules[preset.id], rule.theme == theme else { continue }
                count += overdue(rule: rule, logs: byPreset[preset.id] ?? [], lastThemeCompletion: latest, now: now)
            }
            state.clutter[theme] = min(PochiGrowthPolicy.maximumClutter, count)
        }
        return state
    }

    private static func overdue(rule: PochiWorldRule, logs: [HabitLog], lastThemeCompletion: Date?, now: Date) -> Int {
        // Keep the rule's original local day boundaries when travelling; changing
        // device timezone must not create or erase missed deadlines retroactively.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: rule.timeZoneID) ?? .gmt
        calendar.firstWeekday = rule.firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: rule.startedAt)
        guard let firstFullDay = calendar.date(byAdding: .day, value: 1, to: start), firstFullDay < today else { return 0 }
        var from = firstFullDay
        if let latest = lastThemeCompletion, latest <= now {
            if rule.weeklyTarget < 7 && rule.weekdays == nil {
                if let week = calendar.dateInterval(of: .weekOfYear, for: latest)?.start { from = max(from, week) }
            } else {
                guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: latest)) else { return 0 }
                from = max(from, next)
            }
        }
        guard from < today else { return 0 }
        if rule.weeklyTarget == 7 || rule.weekdays != nil {
            if let weekdays = rule.weekdays {
                guard !weekdays.isEmpty else { return 0 }
                let days = calendar.dateComponents([.day], from: from, to: today).day ?? 0
                // Full weeks can be counted without iterating over years of absence.
                var missed = (days / 7) * weekdays.count
                var day = from
                for _ in 0..<(days % 7) {
                    if weekdays.contains(calendar.component(.weekday, from: day)) { missed += 1 }
                    day = calendar.date(byAdding: .day, value: 1, to: day)!
                }
                return min(PochiGrowthPolicy.maximumClutter, missed)
            }
            return min(PochiGrowthPolicy.maximumClutter, calendar.dateComponents([.day], from: from, to: today).day ?? 0)
        }
        guard var week = calendar.dateInterval(of: .weekOfYear, for: from)?.start else { return 0 }
        if week < from { week = calendar.date(byAdding: .day, value: 7, to: week)! }
        let dates = Set(logs.filter { $0.completedAt <= now }.map { calendar.startOfDay(for: $0.completedAt) })
        var misses = 0
        while week < today {
            guard let end = calendar.date(byAdding: .day, value: 7, to: week), end <= today else { break }
            let done = dates.filter { $0 >= week && $0 < end }.count
            misses += max(0, rule.weeklyTarget - done)
            if misses >= PochiGrowthPolicy.maximumClutter { return PochiGrowthPolicy.maximumClutter }
            week = end
        }
        return misses
    }
}
