import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    private let inquiryURLString = "https://docs.google.com/forms/d/e/1FAIpQLSelR3Rc9eZtn_iu127LODCK1CHUQuVxRkkOrLEw1_fqfsqy_A/viewform?usp=publish-editor"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        UpgradeView(subscriptionManager: subscriptionManager)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("プレミアム")
                                    .font(.headline)
                                Text(subscriptionManager.isSubscribed ? "有効" : "未加入")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.cocoa.opacity(0.65))
                            }
                            Spacer()
                            if !subscriptionManager.isSubscribed {
                                Text("アップグレード")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.candyBlue)
                            }
                        }
                    }
                }

                Section {
                    Button("お問い合わせ") {
                        if let url = URL(string: inquiryURLString) {
                            openURL(url)
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}
