import SwiftUI
import Combine
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdPrivacyManager: ObservableObject {
    static let shared = AdPrivacyManager()
    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var canRequestAds = false
    @Published private(set) var isPresentingOptions = false
    private var preparation: Task<Void, Never>?
    private var didStartAds = false

    /// One update per process launch, shared by any recreated SwiftUI task.
    func prepare() async {
        if let preparation { await preparation.value; return }
        let task = Task { @MainActor in
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    }
                }
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
            } catch {
                // An offline/error launch may use an existing valid consent decision.
                // Without one, leave ads disabled and keep the workout usable.
            }
            updateStatus()
        }
        preparation = task
        await task.value
    }

    func presentOptions() async throws {
        guard isPrivacyOptionsRequired, !isPresentingOptions else { return }
        isPresentingOptions = true
        canRequestAds = false
        defer { isPresentingOptions = false; updateStatus() }
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    private func updateStatus() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        canRequestAds = ConsentInformation.shared.canRequestAds
        if canRequestAds && !didStartAds {
            didStartAds = true
            MobileAds.shared.start(completionHandler: nil)
        }
    }
}
