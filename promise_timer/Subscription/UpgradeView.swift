import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var isWorking = false
    private var product: Product? { subscriptionManager.product(for: SubscriptionManager.lifetimeProductID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("ぽちログ プレミアム").font(pochiPixelFont(22))
                Text("一度の購入で、全部入り。自動更新はありません。")
                    .font(pochiPixelFont(14)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    perk("広告を非表示", icon: .leaf)
                    perk("ダルメシアン・ポメラニアンを選べる", icon: .paw)
                    perk("今後追加する犬種・着せ替えも含まれます", icon: .sparkle)
                }.padding(16).background(Color.mist, in: RoundedRectangle(cornerRadius: 7))

                Text("筋トレの登録・時間の計測は無料で使えます").font(pochiPixelFont(12))

                if subscriptionManager.hasLifetime {
                    Text("購入済みです").font(pochiPixelFont(16))
                } else if subscriptionManager.hasLegacySubscription {
                    Text("現在のサブスク特典は引き続き利用できます。")
                        .font(pochiPixelFont(14))
                    Text("買い切りへの移行は既存の契約を確認してからご案内します。")
                        .font(pochiPixelFont(12))
                } else if let product {
                    Text(product.displayPrice).font(pochiPixelFont(24))
                    PochiPrimaryButton(title: localizedText("買い切りで購入"), isEnabled: !isWorking) {
                        Task {
                            isWorking = true
                            _ = await subscriptionManager.purchase(product)
                            isWorking = false
                        }
                    }
                } else {
                    if subscriptionManager.isLoading { ProgressView() }
                    Button("購入情報を再読み込み") { Task { await subscriptionManager.loadProducts() } }
                        .font(pochiPixelFont(14)).frame(minHeight: 44)
                        .disabled(subscriptionManager.isLoading)
                }

                if let message = subscriptionManager.statusMessage {
                    Text(localizedText(message)).font(pochiPixelFont(12)).fixedSize(horizontal: false, vertical: true)
                }
                Button("購入を復元") {
                    Task { isWorking = true; await subscriptionManager.restore(); isWorking = false }
                }.font(pochiPixelFont(14)).frame(minHeight: 44).disabled(isWorking)
                if subscriptionManager.hasLegacySubscription {
                    Link("サブスクリプションを管理", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        .font(pochiPixelFont(14)).frame(minHeight: 44)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Link("プライバシーポリシー", destination: URL(string: "https://github.com/tsumorimasahiro/promise_timer/blob/main/privacy_policy.txt")!)
                    Link("利用規約（EULA）", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }.font(pochiPixelFont(12))
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color.cream).foregroundStyle(Color.cocoa).tint(Color.grassDark)
            .task { if subscriptionManager.products.isEmpty { await subscriptionManager.loadProducts() } }
    }

    private func perk(_ title: String, icon: PochiPixelIconKind) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PochiPixelGlyph(kind: icon, color: .grassDark, size: 20)
            Text(localizedText(title)).font(pochiPixelFont(14)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
