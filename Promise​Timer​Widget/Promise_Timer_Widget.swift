//
//  Promise_Timer_Widget.swift
//  PromiseTimerWidget
//
//  Created by 津守将弘 on 2026/04/04.
//

import WidgetKit
import SwiftUI
import AppIntents

fileprivate let appGroupID = "group.com.tsumori.promise_timer"
fileprivate let habitLogsKey = "habitLogsStore"
fileprivate let habitPresetsKey = "habitPresetsStore"

enum PresetTint: String, Codable, CaseIterable {
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
    let iconName: String
    let tintName: PresetTint

    var tint: Color { tintName.color }
}

fileprivate struct HabitLog: Identifiable, Codable, Hashable {
    let id: String
    let presetID: String
    let title: String
    let completedAt: Date
}

fileprivate struct WidgetData {
    let presets: [HabitPreset]
    let logs: [HabitLog]
}

fileprivate struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    let selectedPreset: HabitPreset?
    let selectedPresetID: String?
}

struct SelectPresetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "やることを選ぶ"
    static var description = IntentDescription("ウィジェットに表示するやることを選びます。")

    @Parameter(title: "やること")
    var preset: PresetEntity?
}

struct PresetEntity: AppEntity, Identifiable, Codable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "やること")
    static var defaultQuery = PresetQuery()

    let id: String
    let title: String
    let iconName: String
    let tintName: PresetTint

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct PresetQuery: EntityQuery {
    func entities(for identifiers: [PresetEntity.ID]) async throws -> [PresetEntity] {
        let items = loadPresets().filter { identifiers.contains($0.id) }
        return items.map { PresetEntity(id: $0.id, title: $0.title, iconName: $0.iconName, tintName: $0.tintName) }
    }

    func suggestedEntities() async throws -> [PresetEntity] {
        let items = loadPresets()
        return items.map { PresetEntity(id: $0.id, title: $0.title, iconName: $0.iconName, tintName: $0.tintName) }
    }

    func defaultResult() async -> PresetEntity? {
        try? await suggestedEntities().first
    }
}

fileprivate struct Provider: AppIntentTimelineProvider {
    typealias Intent = SelectPresetIntent

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            data: WidgetData(presets: samplePresets, logs: sampleLogs),
            selectedPreset: samplePresets.first,
            selectedPresetID: samplePresets.first?.id
        )
    }

    func snapshot(for configuration: SelectPresetIntent, in context: Context) async -> WidgetEntry {
        let data = loadData()
        let selectedPreset = configuration.preset.map { HabitPreset(id: $0.id, title: $0.title, iconName: $0.iconName, tintName: $0.tintName) }
        let selectedID = selectedPreset?.id ?? data.presets.first?.id
        return WidgetEntry(date: Date(), data: data, selectedPreset: selectedPreset, selectedPresetID: selectedID)
    }

    func timeline(for configuration: SelectPresetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let data = loadData()
        let selectedPreset = configuration.preset.map { HabitPreset(id: $0.id, title: $0.title, iconName: $0.iconName, tintName: $0.tintName) }
        let selectedID = selectedPreset?.id ?? data.presets.first?.id
        let entry = WidgetEntry(date: Date(), data: data, selectedPreset: selectedPreset, selectedPresetID: selectedID)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30)))
    }
}

fileprivate func loadData() -> WidgetData {
    let defaults = UserDefaults(suiteName: appGroupID)
    let presets = loadPresets(from: defaults)
    let logs = loadLogs(from: defaults)
    return WidgetData(presets: presets, logs: logs)
}

fileprivate func loadPresets(from defaults: UserDefaults?) -> [HabitPreset] {
    if let raw = defaults?.string(forKey: habitPresetsKey),
       let data = raw.data(using: .utf8) {
        let decoder = JSONDecoder()
        return (try? decoder.decode([HabitPreset].self, from: data)) ?? []
    }
    return []
}

fileprivate func loadPresets() -> [HabitPreset] {
    loadPresets(from: UserDefaults(suiteName: appGroupID))
}

fileprivate func loadLogs(from defaults: UserDefaults?) -> [HabitLog] {
    if let raw = defaults?.string(forKey: habitLogsKey),
       let data = raw.data(using: .utf8) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HabitLog].self, from: data)) ?? []
    }
    return []
}

fileprivate let samplePresets: [HabitPreset] = [
    HabitPreset(id: "study", title: "勉強", iconName: "study", tintName: .sunshine),
    HabitPreset(id: "reading", title: "読書", iconName: "book", tintName: .lavender),
    HabitPreset(id: "exercise", title: "運動", iconName: "run", tintName: .candyBlue)
]

fileprivate let sampleLogs: [HabitLog] = [
    HabitLog(id: "1", presetID: "study", title: "勉強", completedAt: Date()),
    HabitLog(id: "2", presetID: "reading", title: "読書", completedAt: Date())
]

fileprivate struct HabitCardWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetEntry

    var body: some View {
        if family == .systemMedium {
            WeeklyDotsWidgetView(entry: entry)
        } else {
            let preset = selectedPreset
            ZStack {
                if let preset {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(preset.tint.opacity(0.25))
                    VStack(spacing: -4) {
                        PresetIconView(name: isCompletedToday ? "done" : preset.iconName, size: iconSize, tint: preset.tint)
                        VStack(spacing: -2) {
                            Text(preset.title)
                                .font(.headline)
                                .foregroundStyle(Color.cocoa)
                            if isCompletedToday {
                                Text("できた")
                                    .font(.caption)
                                    .foregroundStyle(Color.cocoa.opacity(0.75))
                            }
                        }
                    }
                    .padding(0)
                } else {
                    Text("やることがないよ")
                        .font(.caption)
                }
            }
            .widgetURL(preset.map { URL(string: "promise-timer://preset/\($0.id)") } ?? nil)
        }
    }

    private var iconSize: CGFloat {
        family == .systemMedium ? 180 : 140
    }

    private var selectedPreset: HabitPreset? {
        if let preset = entry.selectedPreset {
            return preset
        }
        guard let id = entry.selectedPresetID else { return entry.data.presets.first }
        return entry.data.presets.first(where: { $0.id == id }) ?? entry.data.presets.first
    }

    private var isCompletedToday: Bool {
        guard let preset = selectedPreset else { return false }
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: entry.date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }
        return entry.data.logs.contains { log in
            log.presetID == preset.id && log.completedAt >= startOfDay && log.completedAt < endOfDay
        }
    }
}

fileprivate struct WeeklyDotsWidgetView: View {
    let entry: WidgetEntry

    private let calendar = Calendar(identifier: .gregorian)
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.sunshine.opacity(0.12))

            VStack(spacing: 6) {
                Text("できたのあしあと")
                    .font(.headline.bold())
                    .foregroundStyle(Color.cocoa.opacity(0.8))

                HStack(spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { label in
                        Text(label)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.cocoa.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(weekDays, id: \.self) { day in
                        let count = logCount(on: day)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(fillColor(count: count))
                            .frame(height: 36)
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
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
    }

    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: entry.date)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func logCount(on day: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        return entry.data.logs.filter { log in
            log.completedAt >= startOfDay && log.completedAt < endOfDay
        }.count
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

struct HabitCardWidget: Widget {
    let kind = "PromiseTimerHabitCardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectPresetIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                HabitCardWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HabitCardWidgetView(entry: entry)
                    .padding()
            }
        }
        .configurationDisplayName("やることカード")
        .description("やることを1つ表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

fileprivate struct PresetIconView: View {
    let name: String
    let size: CGFloat
    let tint: Color

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
                .foregroundStyle(tint)
        }
    }
}

fileprivate let customIconNames: Set<String> = [
    "study", "book", "run", "clean", "bath", "eat", "done"
]

extension Color {
    static let candyBlue = Color(red: 0.16, green: 0.45, blue: 0.48)
    static let mintGreen = Color(red: 0.60, green: 0.78, blue: 0.67)
    static let sunshine = Color(red: 0.88, green: 0.68, blue: 0.24)
    static let peach = Color(red: 0.89, green: 0.55, blue: 0.45)
    static let lavender = Color(red: 0.66, green: 0.63, blue: 0.79)
    static let sky = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let cocoa = Color(red: 0.29, green: 0.24, blue: 0.21)
    static let grassEmpty = Color(red: 0.90, green: 0.88, blue: 0.84)
    static let grassLight = Color(red: 0.72, green: 0.84, blue: 0.72)
    static let grassDark = Color(red: 0.25, green: 0.54, blue: 0.36)
}

#Preview(as: .systemSmall) {
    HabitCardWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(presets: samplePresets, logs: sampleLogs), selectedPreset: samplePresets.first, selectedPresetID: samplePresets.first?.id)
}
