import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager

    @State private var selectedProductID = SubscriptionManager.monthlyProductID
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    perks
                    planTiles
                    primaryAction
                    trialCaption
                    restoreRow
                    supportCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.cream, Color.roseCloud.opacity(0.55), Color.mist],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.candyBlue.opacity(0.08))
                .frame(width: 240, height: 240)
                .offset(x: 120, y: -180)

            Circle()
                .fill(Color.peach.opacity(0.12))
                .frame(width: 200, height: 200)
                .offset(x: -140, y: 220)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
            }

            Text("がんばる自分にごほうび")
                .font(.subheadline.bold())
                .foregroundStyle(Color.candyBlue)

            VStack(spacing: 8) {
                Text("プレミアムにアップグレード")
                    .font(.title2.bold())
                Text("やることを最大20個まで登録できます")
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa.opacity(0.7))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.cream.opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.peach.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.peach.opacity(0.18), radius: 18, x: 0, y: 12)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("応援お願いします")
                .font(.headline)
            Text("個人開発で、毎日こつこつ改善しています。プレミアムでの応援が励みになります。")
                .font(.subheadline)
                .foregroundStyle(Color.cocoa.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.roseCloud.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.peach.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var planTiles: some View {
        VStack(spacing: 12) {
            planTile(
                title: "月払い",
                subtitle: "2週間無料",
                productID: SubscriptionManager.monthlyProductID
            )

            planTile(
                title: "年払い",
                subtitle: "1ヶ月無料",
                productID: SubscriptionManager.yearlyProductID
            )
        }
    }

    private func planTile(title: String, subtitle: String, productID: String) -> some View {
        let isSelected = selectedProductID == productID
        let priceText = subscriptionManager.productPrice(for: productID)
        let isYearly = productID == SubscriptionManager.yearlyProductID

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if isYearly {
                            Text("おすすめ")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.peach)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.candyBlue)
                }
                Spacer()
                Text(priceText)
                    .font(.headline)
                    .foregroundStyle(Color.cocoa)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.peach.opacity(0.18) : Color.sky.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.peach : Color.candyBlue.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var primaryAction: some View {
        Button {
            Task {
                await purchaseSelected()
            }
        } label: {
            Text(primaryButtonTitle)
                .font(.headline.bold())
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.candyBlue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isPurchasing)
        .opacity(isPurchasing ? 0.6 : 1)
    }

    private var trialCaption: some View {
        Text("無料トライアル終了後はいつでも解約できます")
            .font(.footnote)
            .foregroundStyle(Color.cocoa.opacity(0.65))
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレミアム特典")
                .font(.headline)
            Text("・やることを最大20個まで登録")
                .font(.subheadline)
            Text("・今後の追加特典を優先適用")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cream.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var restoreRow: some View {
        Button("購入を復元") {
            Task {
                try? await AppStore.sync()
                await subscriptionManager.refreshEntitlements()
            }
        }
        .font(.subheadline.bold())
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var primaryButtonTitle: String {
        if selectedProductID == SubscriptionManager.monthlyProductID {
            return "2週間の無料トライアルを開始"
        }
        return "1ヶ月の無料トライアルを開始"
    }

    private func purchaseSelected() async {
        guard let product = subscriptionManager.product(for: selectedProductID) else {
            errorMessage = "プラン情報を読み込み中です"
            return
        }
        errorMessage = nil
        isPurchasing = true
        let success = await subscriptionManager.purchase(product)
        isPurchasing = false
        if !success {
            errorMessage = "購入を完了できませんでした"
        }
    }
}
