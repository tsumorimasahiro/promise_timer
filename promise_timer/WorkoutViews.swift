import SwiftUI

extension WorkoutPlan {
    var summary: String {
        String(format: NSLocalizedString(mode == .timed ? "%lld秒" : "%lld回", comment: "Workout target"), target)
    }
}
extension HabitPreset {
    func withPlan(_ plan: WorkoutPlan) -> Self {
        Self(id: id, title: title, iconName: iconName, tintName: .peach, workoutPlan: plan)
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
        }.font(.subheadline).foregroundStyle(Color.cocoa)
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
                    HStack { WorkoutIcon(name: preset.iconName); Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title)).font(.headline) }
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
                .navigationTitle("筋トレを記録する").navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        let footerLayout = compact ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
        VStack(spacing: 8) {
            HStack {
                Text(editingTarget ? "回数・時間" : "種目を選ぶ").font(pochiPixelFont(16))
                Spacer()
                if editingTarget {
                    Button("種目に戻る") { editingTarget = false }.font(.caption).frame(minHeight: 36)
                } else if finished {
                    Text("記録したよ。おつかれさま！").font(.caption).foregroundStyle(Color.grassDark)
                }
            }.frame(minHeight: 36)
            ScrollView {
                if editingTarget, let selected {
                    inlineTargetEditor(selected)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(presets) { preset in exerciseButton(preset) }
                    }.padding(2)
                    Button("自分の種目を追加", action: onAdd)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.mist, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 8)
                }
            }
            footerLayout {
                if let selected {
                    HStack(spacing: 8) {
                        if !compact {
                            WorkoutIcon(name: selected.iconName, size: 24)
                            Text(localizedPresetTitle(id: selected.id, storedTitle: selected.title))
                                .font(pochiPixelFont(13)).lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        Button { editingTarget.toggle() } label: {
                            HStack(spacing: 4) {
                                Text(selected.workoutPlan.summary).font(.subheadline)
                                Image(systemName: "pencil").font(.caption)
                            }.frame(minHeight: 44)
                        }.accessibilityLabel("回数・時間を変更")
                        Menu {
                            Button("回数・時間を変更") { editingTarget = true }
                            Button("名前・アイコンを編集") { onEdit(selected) }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 32, height: 44)
                        }.accessibilityLabel("種目の設定")
                    }
                }
                PochiPrimaryButton(title: NSLocalizedString(selected == nil ? "種目を選んでね" : "この種目で始める", comment: ""), isEnabled: selected != nil) {
                    guard let selected else { return }
                    onStart(selected)
                }
            }.padding(10).background(Color.pochiSurface, in: RoundedRectangle(cornerRadius: 12))
        }.foregroundStyle(Color.cocoa)
            .onChange(of: presets) { _ in
                if selected == nil { selectedID = nil; editingTarget = false }
            }
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
                            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.mist, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }.padding(14).background(Color.pochiSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseButton(_ preset: HabitPreset) -> some View {
        let isSelected = selectedID == preset.id
        let displayed = draftPlans[preset.id].map { preset.withPlan($0) } ?? preset
        return Button { selectedID = preset.id } label: {
            HStack(spacing: 8) {
                WorkoutIcon(name: preset.iconName, size: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedPresetTitle(id: preset.id, storedTitle: preset.title))
                        .font(pochiPixelFont(13)).lineLimit(2)
                    Text(displayed.workoutPlan.summary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.grassDark) }
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(10)
                .foregroundStyle(Color.cocoa)
                .background(isSelected ? Color.mist : Color.pochiSurface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.grassDark.opacity(isSelected ? 1 : 0.2), lineWidth: isSelected ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
            .accessibilityLabel(localizedPresetTitle(id: preset.id, storedTitle: preset.title) + ", " + displayed.workoutPlan.summary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
