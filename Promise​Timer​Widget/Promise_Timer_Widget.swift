import WidgetKit
import SwiftUI
import AppIntents

// Retain the identifier so already placed habit cards can become the new dog widget.
private let pochiWidgetKind = "PromiseTimerHabitCardWidget"
private let widgetDefaults = UserDefaults(suiteName: "group.com.tsumori.promise_timer")!

struct PochiWidgetEntry: TimelineEntry {
    let date: Date
    let name: String
    let breed: String
    let coat: String
    let pose: Int
    let muscleStage: PochiMuscleStage
    let workouts: [HabitPreset]
    let activePresetID: String?
    var asset: String { "pochi-widget-\(breed)-\(coat)-\(pose)" }

    static func make(at date: Date, preview: Bool = false) -> Self {
        let storedBreed = widgetDefaults.string(forKey: "pochiBreed") ?? "shiba"
        let breed = !preview && widgetDefaults.bool(forKey: "isSubscribed") && ["dalmatian", "pomeranian"].contains(storedBreed) ? storedBreed : "shiba"
        let coatKey = breed == "shiba" ? "pochiCoat" : "pochiCoat.\(breed)"
        let storedCoat = widgetDefaults.string(forKey: coatKey) ?? "kinako"
        let coat = ["kinako", "milk", "black"].contains(storedCoat) ? storedCoat : "kinako"
        let hour = Calendar.current.component(.hour, from: date)
        let night = hour >= 23 || hour < 6
        let lastPet = widgetDefaults.double(forKey: "pochiWidgetLastPet")
        let elapsed = date.timeIntervalSince1970 - lastPet
        let reaction = widgetDefaults.integer(forKey: "pochiWidgetPetPose")
        // A reaction persists until the next OS-managed refresh. Never schedule frame loops.
        let pose = !preview && elapsed >= 0 && elapsed < 900 && [10, 12, 14].contains(reaction)
            ? reaction : night ? 6 : hour >= 20 ? 16 : [7, 12, 16][hour % 3]
        let rawName = widgetDefaults.string(forKey: "pochiName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let earned = PochiMuscleStage.earned(days: widgetDefaults.integer(forKey: "pochiStrengthDays"))
        let selection = widgetDefaults.object(forKey: "pochiMuscleAppearance") as? Int ?? -1
        let session = widgetDefaults.string(forKey: "pochiTogetherSession.v1")
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(PochiTogetherSession.self, from: $0) }
        let activeSession = preview ? nil : session
        let presets = preview ? PochiWorkoutCatalog.starterPresets : PochiWorkoutWidget.presets(from: widgetDefaults)
        let activeID = activeSession?.preset.id
        let available = activeSession.map { active in [active.preset] + presets.filter { $0.id != active.preset.id } } ?? presets
        let workouts = PochiWorkoutWidget.choices(in: available,
            recentIDs: preview ? [] : widgetDefaults.stringArray(forKey: PochiWorkoutWidget.recentKey) ?? [], activeID: activeID)
        return Self(date: date, name: preview || rawName.isEmpty ? NSLocalizedString("ぽち", comment: "Default dog name") : rawName,
                    breed: breed, coat: coat, pose: preview ? 16 : pose,
                    muscleStage: preview ? .puppy : .visible(selection: selection, earned: earned),
                    workouts: workouts, activePresetID: activeID)
    }
}

struct PochiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PochiWidgetEntry { .make(at: Date(), preview: true) }
    func getSnapshot(in context: Context, completion: @escaping (PochiWidgetEntry) -> Void) {
        completion(.make(at: Date(), preview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PochiWidgetEntry>) -> Void) {
        let now = Date()
        // Modest refresh cadence; WidgetKit controls actual delivery and animation.
        let entries = (0..<5).map { PochiWidgetEntry.make(at: now.addingTimeInterval(Double($0) * 1800)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PetPochiIntent: AppIntent {
    static var title: LocalizedStringResource = "ぽちをなでる"
    static var description = IntentDescription("ぽちがこちらを向いたり、尻尾を上げたりします。")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let poses = [12, 10, 14]
        let previous = widgetDefaults.integer(forKey: "pochiWidgetPetPose")
        let index = poses.firstIndex(of: previous).map { ($0 + 1) % poses.count } ?? 0
        widgetDefaults.set(poses[index], forKey: "pochiWidgetPetPose")
        widgetDefaults.set(Date().timeIntervalSince1970, forKey: "pochiWidgetLastPet")
        WidgetCenter.shared.reloadTimelines(ofKind: pochiWidgetKind)
        return .result()
    }
}

private struct PochiCompanionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    let entry: PochiWidgetEntry
    private let ink = Color("PochiCocoa")
    private let green = Color("PochiGrassDark")

    private var companionImage: Image {
        guard entry.muscleStage != .puppy,
              let breed = PochiBreed(rawValue: entry.breed),
              let coat = PochiCoat(rawValue: entry.coat),
              let base = PochiBreedSprites.atlas(for: breed) ?? UIImage(named: "pochiPixelAtlas")?.cgImage,
              let motion = PochiMotionSprites.atlas(for: breed, base: base) else { return Image(entry.asset) }
        let muscle = PochiMuscleSprites.atlas(base: motion, breed: breed, stage: entry.muscleStage)
        let colored = coat.applying(to: muscle, breed: breed)
        guard let frame = colored.cropping(to: CGRect(x: entry.pose % 4 * 32, y: entry.pose / 4 * 32, width: 32, height: 32)) else { return Image(entry.asset) }
        return Image(uiImage: UIImage(cgImage: frame))
    }

    private var primaryURL: URL {
        entry.workouts.first.map { PochiWorkoutWidgetLink.preset($0.id).url } ?? PochiWorkoutWidgetLink.home.url
    }

    var body: some View {
        GeometryReader { geometry in
            if family == .systemSmall {
                VStack(spacing: 2) {
                    Text(entry.name).font(.custom("PixelMplus12-Bold", size: 13))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    dogImage(size: 64)
                        .frame(maxHeight: .infinity)
                    if let preset = entry.workouts.first {
                        Text(presetTitle(preset)).font(.system(size: 12, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.7)
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            Text(entry.activePresetID != nil ? NSLocalizedString("筋トレに戻る", comment: "") : target(preset))
                                .font(.system(size: 12, weight: .semibold))
                        }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 28)
                            .background(green, in: RoundedRectangle(cornerRadius: 8))
                    } else { emptyStart }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 12) {
                    VStack(spacing: 3) {
                        Text(entry.name).font(.custom("PixelMplus12-Bold", size: 14))
                            .lineLimit(1).minimumScaleFactor(0.7)
                        dogImage(size: 96)
                        Text("すぐ筋トレ").font(.system(size: 11, weight: .medium)).foregroundStyle(green)
                    }.frame(width: min(110, geometry.size.width * 0.36))
                    VStack(spacing: 6) {
                        if entry.workouts.isEmpty { emptyStart }
                        ForEach(entry.activePresetID == nil ? entry.workouts : Array(entry.workouts.prefix(1))) { preset in
                            Link(destination: PochiWorkoutWidgetLink.preset(preset.id).url) {
                                HStack(spacing: 7) {
                                    exerciseIcon(preset.iconName).frame(width: 23, height: 23)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(presetTitle(preset)).font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                        Text(entry.activePresetID == preset.id ? NSLocalizedString("筋トレに戻る", comment: "") : target(preset))
                                            .font(.system(size: 10)).foregroundStyle(green)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "play.fill").font(.system(size: 10)).foregroundStyle(green)
                                }.padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 38)
                                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                                .accessibilityLabel(presetTitle(preset) + "、" + target(preset) + "、" + NSLocalizedString("開始", comment: ""))
                        }
                    }.frame(maxWidth: .infinity)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ink)
        .padding(12)
        .widgetURL(family == .systemSmall ? primaryURL : PochiWorkoutWidgetLink.home.url)
        .containerBackground(Color("PochiCream"), for: .widget)
    }

    private func dogImage(size: CGFloat) -> some View {
        companionImage.resizable().interpolation(.none).frame(width: size, height: size)
            .id(entry.asset).transition(.opacity)
            .animation(reduceMotion || luminanceReduced ? nil : .easeInOut(duration: 0.5), value: entry.asset)
            .accessibilityLabel(Text(entry.pose == 6 ? "眠っているぽち" : "くつろぐぽち"))
    }

    private var emptyStart: some View {
        Text("種目を選ぶ").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(green).frame(maxWidth: .infinity, minHeight: 36)
    }

    private func target(_ preset: HabitPreset) -> String {
        String(format: NSLocalizedString(preset.workoutPlan.mode == .timed ? "%lld秒で開始" : "%lld回で開始", comment: ""), preset.workoutPlan.target)
    }

    private func presetTitle(_ preset: HabitPreset) -> String {
        let keys = ["スクワット", "腕立て伏せ", "腹筋", "プランク", "サイドプランク", "バードドッグ", "デッドバグ", "ランジ", "ダンベル", "ヒップリフト", "かかと上げ"]
        guard let index = PochiWorkoutCatalog.presets.firstIndex(where: { $0.id == preset.id }) else { return preset.title }
        let key = keys[index]
        let isDefaultTitle = ["ja", "en", "ko", "zh-Hans", "zh-Hant"].contains { locale in
            guard let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return false }
            return bundle.localizedString(forKey: key, value: nil, table: nil) == preset.title
        }
        return isDefaultTitle ? NSLocalizedString(key, comment: "") : preset.title
    }

    private func exerciseIcon(_ name: String) -> some View {
        Canvas { context, bounds in
            let unit = min(bounds.width, bounds.height) / 24
            for pixel in WorkoutPixelArt.pixels(for: name) {
                let rect = CGRect(x: CGFloat(pixel.x)*unit, y: CGFloat(pixel.y)*unit, width: unit, height: unit)
                context.fill(Path(rect), with: .color(pixel.tone == 2 ? ink : green), style: FillStyle(antialiased: false))
            }
        }.accessibilityHidden(true)
    }
}

struct PochiCompanionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: pochiWidgetKind, provider: PochiWidgetProvider()) { entry in
            PochiCompanionWidgetView(entry: entry)
        }
        .configurationDisplayName("筋トレの相棒、ぽち")
        .description("種目をタップして、設定した回数や時間ですぐ筋トレを始められます。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) { PochiCompanionWidget() } timeline: {
    PochiWidgetEntry.make(at: Date(), preview: true)
}
#Preview(as: .systemMedium) { PochiCompanionWidget() } timeline: {
    PochiWidgetEntry.make(at: Date(), preview: true)
}
