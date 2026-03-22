import Foundation
import StoreKit
import Combine

fileprivate enum SubscriptionConfig {
    // TODO: Replace with your actual App Store Connect product IDs.
    static let monthlyProductID = "promise_timer.monthly"
    static let yearlyProductID = "promise_timer.yearly"
    static let productIDs = [monthlyProductID, yearlyProductID]
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let monthlyProductID = SubscriptionConfig.monthlyProductID
    static let yearlyProductID = SubscriptionConfig.yearlyProductID

    @Published var products: [Product] = []
    @Published var isSubscribed = false

    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        listenForUpdates()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: SubscriptionConfig.productIDs)
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if SubscriptionConfig.productIDs.contains(transaction.productID) {
                active = true
            }
        }
        isSubscribed = active
    }

    func productIDs() -> [String] {
        SubscriptionConfig.productIDs
    }

    func product(for productID: String) -> Product? {
        products.first(where: { $0.id == productID })
    }

    func productPrice(for productID: String) -> String {
        product(for: productID)?.displayPrice ?? "読み込み中"
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified = verification else { return false }
                await refreshEntitlements()
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    private func listenForUpdates() {
        updatesTask?.cancel()
        updatesTask = Task {
            for await _ in Transaction.updates {
                await refreshEntitlements()
            }
        }
    }
}
