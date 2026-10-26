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
                        .font(pochiPixelFont(12))
                        .tint(Color.grassDark)
                    }
                }
                .toolbarBackground(Color.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await subscriptionManager.refreshEntitlements()
        }
    }
}
