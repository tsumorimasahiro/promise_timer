import SwiftUI

struct SettingsView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var adPrivacy = AdPrivacyManager.shared
    @State private var showingPrivacyError = false
    let onEditPochi: () -> Void
    @Environment(\.openURL) private var openURL
    @AppStorage(WorkoutSounds.enabledKey, store: WorkoutSounds.defaults) private var workoutSoundsEnabled = true

    private let inquiryURLString = "https://docs.google.com/forms/d/e/1FAIpQLSelR3Rc9eZtn_iu127LODCK1CHUQuVxRkkOrLEw1_fqfsqy_A/viewform?usp=publish-editor"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsSection("プラン") {
                        NavigationLink {
                            UpgradeView(subscriptionManager: subscriptionManager)
                        } label: {
                            settingRow(
                                icon: .sparkle,
                                title: "プレミアム",
                                detail: subscriptionManager.isSubscribed ? "有効" : "広告なし・追加の犬種",
                                trailing: subscriptionManager.isSubscribed ? "有効" : "見る"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("ぽち") {
                        Button(action: onEditPochi) {
                            settingRow(
                                icon: .paw,
                                title: "なまえ・見た目を変える",
                                detail: "名前、犬種、毛色",
                                trailing: "編集"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("サウンド") {
                        Toggle(isOn: $workoutSoundsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("筋トレの効果音").font(pochiPixelFont(12))
                                    .foregroundStyle(Color.cocoa)
                                Text("開始・残り3秒・時間終了・記録保存")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.cocoa.opacity(0.64))
                            }
                        }
                        .tint(Color.grassDark)
                        .frame(minHeight: 72)
                        .onChange(of: workoutSoundsEnabled) { enabled in
                            if !enabled { WorkoutSounds.shared.stop() }
                        }
                    }

                    settingsSection("サポート") {
                        Link(destination: URL(string: "https://github.com/tsumorimasahiro/promise_timer/blob/main/privacy_policy.txt")!) {
                            settingRow(icon: .leaf, title: "プライバシーポリシー", detail: "データの取り扱いについて", trailing: "開く")
                        }
                        .buttonStyle(.plain)
                        if adPrivacy.isPrivacyOptionsRequired {
                            Button {
                                Task {
                                    do { try await adPrivacy.presentOptions() }
                                    catch { showingPrivacyError = true }
                                }
                            } label: {
                                settingRow(icon: .leaf, title: "広告のプライバシー設定", detail: "広告に関する同意を変更", trailing: "開く")
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if let url = URL(string: inquiryURLString) {
                                openURL(url)
                            }
                        } label: {
                            settingRow(
                                icon: .share,
                                title: "お問い合わせ",
                                detail: "筋トレやぽちについてのご意見もこちら",
                                trailing: "開く"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color.cream)
            .tint(Color.grassDark)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("設定")
                        .font(pochiPixelFont(16))
                        .foregroundStyle(Color.cocoa)
                }
            }
            .toolbarBackground(Color.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("プライバシー設定を開けませんでした", isPresented: $showingPrivacyError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("時間をおいて、もう一度お試しください。")
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(pochiPixelFont(12))
                .foregroundStyle(Color.cocoa.opacity(0.68))
                .padding(.leading, 2)

            VStack(spacing: 0, content: content)
                .padding(.horizontal, 12)
                .background(Color.pochiSurface.opacity(0.68), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cocoa.opacity(0.18), lineWidth: 1))
        }
    }

    private func settingRow(
        icon: PochiPixelIconKind,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        trailing: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 12) {
            PochiPixelGlyph(kind: icon, color: Color.grassDark, size: 22)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(pochiPixelFont(12))
                    .foregroundStyle(Color.cocoa)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cocoa.opacity(0.64))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(trailing)
                .font(pochiPixelFont(10))
                .foregroundStyle(Color.grassDark)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}
