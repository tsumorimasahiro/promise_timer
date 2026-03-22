import SwiftUI
import StoreKit

struct PaywallSheet: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            UpgradeView(subscriptionManager: subscriptionManager)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") {
                            isPresented = false
                        }
                    }
                }
        }
        .task {
            await subscriptionManager.refreshEntitlements()
        }
    }
}
