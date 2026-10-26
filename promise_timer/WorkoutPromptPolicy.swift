import Foundation

/// Prompts are considered only after a workout was saved and its result sheet closed.
/// A shared cooldown prevents review and premium sheets appearing back to back.
struct WorkoutPromptPolicy: Codable {
    enum Prompt { case review, premium }
    private(set) var completions = 0
    private(set) var trainingDays: Set<String> = []
    private(set) var lastSessionID: String?
    private(set) var lastPromptAt: Date?
    private(set) var lastReviewAt: Date?
    private(set) var lastPremiumAt: Date?
    private(set) var premiumCompletionCount = 0

    mutating func recordCompletion(id: String, at date: Date, calendar: Calendar) {
        guard lastSessionID != id else { return }
        lastSessionID = id
        completions += 1
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        trainingDays.insert("\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)")
    }
    func nextPrompt(at date: Date, isPremium: Bool) -> Prompt? {
        let day: TimeInterval = 86_400
        guard lastPromptAt.map({ date.timeIntervalSince($0) >= 7 * day }) ?? true else { return nil }
        if completions >= 5, trainingDays.count >= 3,
           lastReviewAt.map({ date.timeIntervalSince($0) >= 180 * day }) ?? true { return .review }
        if !isPremium, completions - premiumCompletionCount >= 10, trainingDays.count >= 3,
           lastPremiumAt.map({ date.timeIntervalSince($0) >= 30 * day }) ?? true { return .premium }
        return nil
    }
    mutating func markPresented(_ prompt: Prompt, at date: Date) {
        lastPromptAt = date
        switch prompt {
        case .review: lastReviewAt = date
        case .premium: lastPremiumAt = date; premiumCompletionCount = completions
        }
    }
}
