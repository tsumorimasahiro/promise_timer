import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    // Register as a non-consumable in App Store Connect before release.
    static let lifetimeProductID = "promise_timer.premium.lifetime"
    static let monthlyProductID = "promise_timer.monthly"
    static let yearlyProductID = "promise_timer.yearly"
    private static let legacyIDs = [monthlyProductID, yearlyProductID]

    @Published var products: [Product] = []
    // Keep the existing property/cache name for compatibility with all feature gates.
    @Published var isSubscribed = false
    @Published var hasLifetime = false
    @Published var hasLegacySubscription = false
    @Published var isLoading = false
    @Published var statusMessage: String?
    private var updatesTask: Task<Void, Never>?

    deinit { updatesTask?.cancel() }

    func start() async {
        listenForUpdates()
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.lifetimeProductID])
                .filter { $0.type == .nonConsumable }
            statusMessage = products.isEmpty ? "購入情報を取得できませんでした。時間をおいて再試行してください。" : nil
        } catch {
            products = []
            statusMessage = "購入情報を取得できませんでした。時間をおいて再試行してください。"
        }
    }

    func refreshEntitlements() async {
        var lifetime = false, legacy = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.lifetimeProductID { lifetime = true }
            if Self.legacyIDs.contains(transaction.productID), !transaction.isUpgraded { legacy = true }
        }
        hasLifetime = lifetime
        hasLegacySubscription = legacy
        isSubscribed = lifetime || legacy
    }

    func productIDs() -> [String] { [Self.lifetimeProductID] }
    func product(for productID: String) -> Product? { products.first { $0.id == productID } }
    func productPrice(for productID: String) -> String { product(for: productID)?.displayPrice ?? localizedText("読み込み中") }

    func purchase(_ product: Product) async -> Bool {
        guard product.id == Self.lifetimeProductID, product.type == .nonConsumable else { return false }
        statusMessage = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    statusMessage = "購入を確認できませんでした。購入を復元してください。"
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                return isSubscribed
            case .pending:
                statusMessage = "購入は承認待ちです。承認後に反映されます。"
            case .userCancelled:
                break
            @unknown default:
                statusMessage = "購入を完了できませんでした"
            }
        } catch { statusMessage = "購入を完了できませんでした" }
        return false
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isSubscribed ? "購入を復元しました" : "復元できる購入はありませんでした"
        } catch { statusMessage = "復元できませんでした。もう一度お試しください。" }
    }

    private func listenForUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                guard transaction.productID == Self.lifetimeProductID || Self.legacyIDs.contains(transaction.productID) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }
}
