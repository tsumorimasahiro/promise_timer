import SwiftUI
import UserNotifications

extension WorkoutPlan {
    var summary: String {
        String(format: NSLocalizedString(mode == .timed ? "%lld秒" : "%lld回", comment: "Workout target"), target)
    }
}

struct WorkoutNumberField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...999
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .frame(width: 64).textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
                .onChange(of: value) { value = min(max($0, range.lowerBound), range.upperBound) }
            Stepper(label, value: $value, in: range).labelsHidden().fixedSize()
        }.frame(minHeight: 48)
    }
}

struct WorkoutPlanFields: View {
    @Binding var plan: WorkoutPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("記録方法", selection: $plan.mode) {
                Text("回数").tag(WorkoutMode.repetitions)
                Text("時間").tag(WorkoutMode.timed)
            }.pickerStyle(.segmented)
                .onChange(of: plan.mode) { plan.target = $0 == .timed ? 30 : 10 }
            WorkoutNumberField(label: NSLocalizedString(plan.mode == .timed ? "1セットの秒数" : "1セットの回数", comment: ""),
                value: $plan.target, range: 1...(plan.mode == .timed ? 3600 : 999))
        }.font(pochiPixelFont(.subheadline)).foregroundStyle(Color.cocoa)
    }
}

/// Crisp square pixels match Pochi and the rest of the app's artwork.
struct WorkoutIcon: View {
    let name: String
    var size: CGFloat = 28
    var color: Color = .grassDark
    var body: some View {
        Canvas { context, bounds in
            let unit = min(bounds.width, bounds.height) / 24
            for pixel in WorkoutPixelArt.pixels(for: name) {
                let rect = CGRect(x: CGFloat(pixel.x) * unit, y: CGFloat(pixel.y) * unit, width: unit, height: unit)
                let tone = pixel.tone == 2 ? Color.cocoa : pixel.tone == 3 ? color.opacity(0.4) : color
                context.fill(Path(rect), with: .color(tone), style: FillStyle(antialiased: false))
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct WorkoutResultSheet: View {
    let preset: HabitPreset
    let onSave: ([Int]) -> Bool
    let onCancel: () -> Void
    @State private var values: [Int]
    @State private var failed = false
    init(preset: HabitPreset, values: [Int], onSave: @escaping ([Int]) -> Bool, onCancel: @escaping () -> Void) {
        self.preset = preset; self.onSave = onSave; self.onCancel = onCancel
        _values = State(initialValue: values)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { WorkoutIcon(name: preset.iconName); Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title)).font(pochiPixelFont(.headline)) }
                    Text(preset.workoutPlan.summary).foregroundStyle(.secondary)
                    Text("予定どおりなら、そのまま保存。違うときは実際の回数・時間に直せます。")
                }
                Section("実際にできた分") {
                    ForEach(values.indices, id: \.self) { index in
                        WorkoutNumberField(label: String(format: NSLocalizedString(preset.workoutPlan.mode == .timed ? "%lldセット目・秒" : "%lldセット目・回", comment: ""), index + 1),
                            value: Binding(get: { values[index] }, set: { values[index] = $0 }), range: 0...3600)
                    }
                    Button("セットを追加") { if values.count < 20 { values.append(preset.workoutPlan.target) } }
                        .disabled(values.count >= 20)
                    if !values.isEmpty { Button("最後のセットを外す") { values.removeLast() } }
                }
            }.scrollContentBackground(.hidden).background(Color.cream)
                .pochiNavigationTitle("筋トレを記録する").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("もどる", action: onCancel) } }
                .safeAreaInset(edge: .bottom) {
                    PochiPrimaryButton(title: NSLocalizedString("この内容で記録する", comment: ""), isEnabled: values.contains { $0 > 0 }) {
                        if !onSave(values.filter { $0 > 0 }) { failed = true }
                    }.padding().background(Color.cream)
                }
                .alert("記録できませんでした", isPresented: $failed) { Button("閉じる", role: .cancel) {} }
        }
    }
}

/// Embedded below Pochi: only the exercise list scrolls, while the start action stays visible.
struct WorkoutSelectionPanel: View {
    let presets: [HabitPreset]
    let finished: Bool
    var compact = false
    var logs: [HabitLog] = []
    var onQuickStart: (HabitPreset) -> Void = { _ in }
    var strengthDays = 0
    var lastCompleted: HabitPreset? = nil
    var showNativeAd = false
    var onViewRecords: () -> Void = {}
    @State private var showingReminder = false
    var onShare: (() -> Void)? = nil
    let onStart: (HabitPreset) -> Void
    let onEdit: (HabitPreset) -> Void
    let onAdd: () -> Void
    @State private var selectedID: String?
    @State private var editingTarget = false
    @State private var draftPlans: [String: WorkoutPlan] = [:]

    private var selected: HabitPreset? {
        guard let preset = presets.first(where: { $0.id == selectedID }) else { return nil }
        return draftPlans[preset.id].map { preset.withPlan($0) } ?? preset
    }

    private var previousPreset: HabitPreset? {
        WorkoutHomeSelection.previous(presets: presets, lastCompleted: lastCompleted, logs: logs, now: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let stage = PochiMuscleStage.earned(days: strengthDays)
                if let next = stage.next {
                    HStack {
                        Text(localizedFormat("次の姿まであと%lld日", next.requiredDays - strengthDays)).font(pochiPixelFont(.caption)).padding(.leading, 16)
                        Spacer(minLength: 0)
                    }
                    ProgressView(value: Double(strengthDays), total: Double(next.requiredDays)).tint(Color.grassDark)
                } else {
                    HStack {
                        Text("ぽちと最高の相棒になったよ！").font(pochiPixelFont(.caption)).padding(.leading, 16)
                        Spacer(minLength: 0)
                    }
                }
                if finished {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("記録したよ。おつかれさま！").font(pochiPixelFont(14))
                        if let previous = previousPreset {
                            Text(localizedPresetTitle(id: previous.id, storedTitle: previous.title) + " · " + previous.workoutPlan.summary).font(pochiPixelFont(.caption))
                        }
                        if let onShare { Button("今日の写真を見る", action: onShare).frame(minHeight: 44) }
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mist, in: RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Text("種目を選ぶ").font(pochiPixelFont(15)).padding(.leading, 16)
                    Spacer(minLength: 0)
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets) { preset in exerciseButton(preset).id(preset.id) }
                            Button(action: onAdd) {
                                VStack(spacing: 6) {
                                    Image(systemName: "plus").frame(height: 32)
                                    Text("自分の種目を追加").font(pochiPixelFont(.caption))
                                }.frame(width: 110, height: 76)
                            }.buttonStyle(.bordered)
                        }.padding(3)
                    }
                    .onAppear { proxy.scrollTo(selectedID, anchor: .center) }
                    .onChange(of: selectedID) { id in proxy.scrollTo(id, anchor: .center) }
                }
                if let selected {
                    HStack {
                        Text(selected.workoutPlan.summary).font(pochiPixelFont(18))
                        Spacer()
                        Button("今日は軽めに") {
                            draftPlans[selected.id] = selected.workoutPlan.lightSession
                        }.font(pochiPixelFont(.caption)).frame(minHeight: 44)
                        Menu {
                            Button("回数・時間を変更") { editingTarget = true }
                            Button("名前・アイコンを編集") { onEdit(selected) }
                        } label: {
                            Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                        }.accessibilityLabel("種目の設定")
                    }
                }
                PochiPrimaryButton(title: localizedText("この種目で始める"), isEnabled: selected != nil) {
                    if let selected { onQuickStart(selected) }
                }
                if !logs.isEmpty || showNativeAd {
                    let summary = WorkoutWeekSummary(logs: logs, now: Date(), calendar: localeAwareGregorianCalendar)
                    Button(action: onViewRecords) {
                        HStack {
                            Text(localizedFormat("今週は%lld日できた", summary.days))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }.font(pochiPixelFont(.subheadline)).padding(.vertical, 14)
                    }.buttonStyle(.plain)
                }
                if showNativeAd { PochiNativeAd() }
            }.padding(.bottom, 16)
        }.foregroundStyle(Color.cocoa)
            .onAppear(perform: restoreSelection)
            .onChange(of: presets) { _ in if selected == nil { restoreSelection() } }
            .sheet(isPresented: $editingTarget) {
                NavigationStack {
                    ScrollView { if let selected { inlineTargetEditor(selected).padding() } }
                        .pochiNavigationTitle("回数・時間を変更")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { editingTarget = false } } }
                }.presentationDetents([.medium, .large])
            }
    }

    private func restoreSelection() {
        guard selected == nil else { return }
        let previous = previousPreset
        selectedID = previous?.id ?? presets.first?.id
        if let previous { draftPlans[previous.id] = previous.workoutPlan }
    }

    private func inlineTargetEditor(_ preset: HabitPreset) -> some View {
        let plan = Binding<WorkoutPlan>(get: { draftPlans[preset.id] ?? preset.workoutPlan },
            set: { draftPlans[preset.id] = $0.validated })
        return VStack(alignment: .leading, spacing: 12) {
            Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title)).font(pochiPixelFont(16))
            Picker("記録方法", selection: plan.mode) {
                Text("回数").tag(WorkoutMode.repetitions)
                Text("時間").tag(WorkoutMode.timed)
            }.pickerStyle(.segmented)
                .onChange(of: plan.wrappedValue.mode) { mode in
                    var updated = plan.wrappedValue
                    updated.target = mode == .timed ? 30 : 10
                    plan.wrappedValue = updated
                }
            HStack {
                Text(plan.wrappedValue.summary).font(pochiPixelFont(24).monospacedDigit())
                Spacer()
                Stepper(NSLocalizedString(plan.wrappedValue.mode == .timed ? "1セットの秒数" : "1セットの回数", comment: ""),
                        value: plan.target, in: 1...(plan.wrappedValue.mode == .timed ? 3600 : 999))
                    .labelsHidden().fixedSize().frame(minHeight: 44)
                    .accessibilityValue(plan.wrappedValue.summary)
            }
            HStack(spacing: 8) {
                ForEach(plan.wrappedValue.mode == .timed ? [15, 30, 60] : [5, 10, 15], id: \.self) { target in
                    Button {
                        var updated = plan.wrappedValue; updated.target = target; plan.wrappedValue = updated
                    } label: {
                        Text(WorkoutPlan(mode: plan.wrappedValue.mode, target: target).summary)
                            .font(pochiPixelFont(.subheadline)).frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.mist, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }.padding(14).background(Color.pochiSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseButton(_ preset: HabitPreset) -> some View {
        let isSelected = selectedID == preset.id
        return Button { selectedID = preset.id } label: {
            VStack(spacing: 6) {
                WorkoutIcon(name: preset.iconName, size: 36)
                Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                    .font(pochiPixelFont(12)).lineLimit(2).multilineTextAlignment(.center)
            }.frame(width: 112, height: 82)
                .foregroundStyle(Color.cocoa)
                .background(isSelected ? Color.mist : Color.pochiSurface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.grassDark.opacity(isSelected ? 1 : 0.2), lineWidth: isSelected ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if isSelected { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.grassDark).padding(5) }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

}


struct WorkoutReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var weekday = 4
    @State private var time = Date()
    @State private var status: String?
    @State private var saving = false
    private let identifier = "pochi.workout.weekly.v1"

    var body: some View {
        NavigationStack {
            Form {
                Toggle("筋トレのお知らせ", isOn: $enabled)
                if enabled {
                    Picker("曜日", selection: $weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(localeAwareGregorianCalendar.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                    Text("選んだ曜日に週1回お知らせします。いつでもオフにできます。")
                        .font(pochiPixelFont(.caption))
                }
                if let status { Text(localizedText(status)).foregroundStyle(.secondary) }
                Button("保存する") { Task { await save() } }.disabled(saving)
            }
            .pochiNavigationTitle("次の筋トレをお知らせ")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
            .task {
                let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
                if let trigger = requests.first(where: { $0.identifier == identifier })?.trigger as? UNCalendarNotificationTrigger {
                    enabled = true
                    weekday = trigger.dateComponents.weekday ?? 4
                    time = Calendar.current.date(bySettingHour: trigger.dateComponents.hour ?? 20,
                        minute: trigger.dateComponents.minute ?? 0, second: 0, of: Date()) ?? Date()
                }
            }
        }
    }

    @MainActor private func save() async {
        saving = true
        defer { saving = false }
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            dismiss()
            return
        }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                status = "通知が許可されていません。iPhone・iPadの設定で通知を許可してください。"
                return
            }
            let content = UNMutableNotificationContent()
            content.title = localizedText("ぽちと、ひとつだけ筋トレしよう")
            content.body = localizedText("今日は軽めでも大丈夫。あなたのペースで。")
            content.sound = .default
            var components = Calendar.current.dateComponents([.hour, .minute], from: time)
            components.weekday = weekday
            try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            dismiss()
        } catch { status = "お知らせを保存できませんでした。もう一度お試しください。" }
    }
}
