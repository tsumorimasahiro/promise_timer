import Foundation

enum PochiWorkoutCatalog {
    static var presets: [HabitPreset] {
        [make("squats", "スクワット", "squat"),
         make("pushups", "腕立て伏せ", "pushup"),
         make("strength.crunches", "腹筋", "crunch"),
         make("strength.plank", "プランク", "plank"),
         make("strength.sidePlank", "サイドプランク", "sidePlank"),
         make("strength.birdDog", "バードドッグ", "birdDog"),
         make("strength.deadBug", "デッドバグ", "deadBug"),
         make("strength.lunges", "ランジ", "lunge"),
         make("dumbbells", "ダンベル", "dumbbell.fill"),
         make("strength.gluteBridge", "ヒップリフト", "bridge"),
         make("strength.calfRaises", "かかと上げ", "calf")]
    }
    static var starterPresets: [HabitPreset] { presets }
    static func customID() -> String { "strength.custom." + UUID().uuidString }
    static func isWorkout(_ preset: HabitPreset) -> Bool {
        PochiPromiseReaction.activity(for: preset) == .strength
    }
    static func initialSelection(_ selected: [HabitPreset]) -> [HabitPreset] {
        selected.isEmpty ? starterPresets : selected
    }
    static func installingBasics(in saved: [HabitPreset]) -> [HabitPreset] {
        let retained = saved.filter { $0.id != "strength" }
        return presets.map { basic in
            guard let old = retained.first(where: { $0.id == basic.id }) else { return basic }
            return HabitPreset(id: old.id, title: old.title, iconName: basic.iconName,
                tintName: .peach, workoutPlan: old.workoutPlan)
        } + retained.filter { old in !presets.contains { $0.id == old.id } }
    }
    private static func make(_ id: String, _ title: String, _ icon: String) -> HabitPreset {
        HabitPreset(id: id, title: NSLocalizedString(title, comment: "Strength exercise"),
                    iconName: icon, tintName: .peach)
    }
}
