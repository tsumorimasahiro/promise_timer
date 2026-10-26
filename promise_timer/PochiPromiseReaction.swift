import Foundation

/// Local, deterministic classification. Stable template IDs take precedence over
/// translated titles; custom promises use specific phrases before icon/category fallbacks.
enum PochiPromiseReaction {
    static func activity(for preset: HabitPreset) -> PochiRoomActivity {
        if preset.id.hasPrefix("strength.") { return .strength }
        let templates: [String: PochiRoomActivity] = [
            "strength": .strength, "squats": .strength, "pushups": .strength, "dumbbells": .strength,
            "water": .drink, "breakfast": .eat, "stretch": .stretch, "exercise": .stretch,
            "walk": .stroll, "outside": .stroll, "rest": .rest, "breath": .breathe,
            "bath": .wash, "teeth": .selfCare, "sleep": .sleep, "sleepRoutine": .sleep,
            "clean": .clean, "dishes": .clean, "laundry": .clean, "prepare": .study,
            "plants": .joy, "reading": .read, "readingPage": .read,
            "study": .study, "studyQuestion": .study, "language": .study,
            "journal": .study, "focus": .study, "message": .joy, "thanks": .joy,
            "hobby": .joy, "music": .listen, "photo": .pose
        ]
        if let activity = templates[preset.id] { return activity }
        let title = preset.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = Set(title.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        let rules: [(PochiRoomActivity, [String], [String])] = [
            (.strength, ["筋トレ", "筋力", "スクワット", "腕立て", "腹筋", "背筋", "ダンベル", "プランク", "ウェイト", "ウエイト", "근력", "스쿼트", "팔굽혀펴기", "덤벨", "플랭크", "力量训练", "力量訓練", "深蹲", "俯卧撑", "伏地挺身", "哑铃", "啞鈴", "平板支撑", "棒式"], ["strength", "weightlifting", "weights", "squat", "squats", "pushup", "pushups", "dumbbell", "dumbbells", "plank", "planks"]),
            (.clean, ["食器", "皿洗", "洗濯", "설거지", "빨래", "洗碗", "洗衣"], ["dishes", "laundry"]),
            (.joy, ["水やり", "水をあげ", "植物", "식물", "浇水", "澆水"], ["plants", "gardening"]),
            (.breathe, ["深呼吸", "瞑想", "심호흡", "명상", "冥想"], ["breathe", "breathing", "meditate", "meditation"]),
            (.stretch, ["ストレッチ", "ヨガ", "스트레칭", "요가", "拉伸", "瑜伽"], ["stretch", "stretching", "yoga"]),
            (.stroll, ["散歩", "歩く", "外の空気", "산책", "걷기", "散步", "走路"], ["walk", "walking", "stroll"]),
            (.exercise, ["運動", "筋トレ", "ランニング", "운동", "달리기", "运动", "跑步"], ["exercise", "workout", "run", "running"]),
            (.rest, ["休憩", "休む", "くつろ", "쉬기", "휴식", "休息"], ["rest", "break", "relax"]),
            (.wash, ["お風呂", "入浴", "シャワー", "목욕", "샤워", "洗澡", "淋浴"], ["bath", "bathe", "shower"]),
            (.selfCare, ["歯磨", "歯をみが", "スキンケア", "양치", "刷牙", "护肤", "護膚"], ["teeth", "skincare"]),
            (.drink, ["水を飲", "水分補給", "お茶を飲", "물 마", "喝水", "飲水"], ["drink", "hydrate", "hydration"]),
            (.eat, ["ご飯を食", "ごはんを食", "食事", "朝食", "昼食", "夕食", "朝ご飯", "朝ごはん", "밥 먹", "식사", "吃饭", "吃飯", "早餐", "晚餐"], ["eat", "meal", "breakfast", "lunch", "dinner"]),
            (.listen, ["音楽", "음악", "音乐", "音樂"], ["music"]),
            (.pose, ["写真", "사진", "拍照"], ["photo", "photograph"])
        ]
        for (activity, phrases, english) in rules {
            if phrases.contains(where: title.contains) || !words.isDisjoint(with: english) { return activity }
        }
        switch PochiPromiseTheme.infer(preset) {
        case .reading: return .read
        case .studying: return .study
        case .cleaning: return .clean
        case .exercise:
            return ["figure.walk", "walk"].contains(preset.iconName.lowercased()) ? .stroll : .exercise
        case .sleeping: return .sleep
        case .general: break
        }
        switch preset.iconName.lowercased() {
        case "drop.fill", "drop", "water": return .drink
        case "eat", "fork.knife", "food": return .eat
        case "dumbbell", "dumbbell.fill", "figure.strengthtraining.traditional", "figure.strengthtraining.functional": return .strength
        case "stretch": return .stretch
        case "wind", "breath": return .breathe
        case "bath": return .wash
        case "toothbrush": return .selfCare
        case "music.note": return .listen
        case "camera.fill": return .pose
        case "dishes", "tshirt.fill": return .clean
        default: return preset.category == .learning ? .study : .joy
        }
    }
}
