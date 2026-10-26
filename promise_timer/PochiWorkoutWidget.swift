import Foundation

enum PochiWorkoutWidgetLink: Equatable {
    case home
    case preset(String)

    var url: URL {
        var components = URLComponents()
        components.scheme = "promise-timer"
        switch self {
        case .home: components.host = "workout"
        case .preset(let id):
            components.host = "preset"
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%"))
            components.percentEncodedPath = "/" + id.addingPercentEncoding(withAllowedCharacters: allowed)!
        }
        return components.url!
    }

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "promise-timer", parts.query == nil, parts.fragment == nil else { return nil }
        if parts.host == "workout", parts.path.isEmpty || parts.path == "/" { self = .home; return }
        guard parts.host == "preset", parts.percentEncodedPath.hasPrefix("/") else { return nil }
        let path = String(parts.percentEncodedPath.dropFirst())
        guard !path.isEmpty, !path.contains("/"), let id = path.removingPercentEncoding, !id.isEmpty else { return nil }
        self = .preset(id)
    }
}

enum PochiWorkoutWidget {
    static let recentKey = "pochiWidgetRecentPresets.v1"

    static func presets(from defaults: UserDefaults) -> [HabitPreset] {
        guard let stored = defaults.string(forKey: "habitPresetsStore"),
              let data = stored.data(using: .utf8),
              let saved = try? JSONDecoder().decode([HabitPreset].self, from: data) else {
            return PochiWorkoutCatalog.starterPresets
        }
        return saved.filter { $0.id != "strength" && PochiWorkoutCatalog.isWorkout($0) }
    }

    static func choices(in presets: [HabitPreset], recentIDs: [String], activeID: String?) -> [HabitPreset] {
        let priority = [activeID].compactMap { $0 } + recentIDs + ["squats", "strength.plank", "pushups"] + presets.map(\.id)
        var seen = Set<String>()
        return priority.compactMap { id -> HabitPreset? in
            guard seen.insert(id).inserted,
                  let preset = presets.first(where: { $0.id == id }) else { return nil }
            return preset
        }.prefix(3).map { $0 }
    }

    static func remember(_ id: String, in defaults: UserDefaults) {
        let previous = defaults.stringArray(forKey: recentKey) ?? []
        defaults.set(Array(([id] + previous.filter { $0 != id }).prefix(3)), forKey: recentKey)
    }
}
