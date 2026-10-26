import Foundation
let day: TimeInterval = 86400
let now = Date(timeIntervalSince1970: 1_700_000_000)
var policy = WorkoutPromptPolicy()
precondition(policy.nextPrompt(at: now, isPremium: false) == nil)
for i in 0..<5 { policy.recordCompletion(id: "\(i)", at: now.addingTimeInterval(Double(i) * day), calendar: .current) }
precondition(policy.nextPrompt(at: now + 5 * day, isPremium: false) == .review)
precondition(policy.nextPrompt(at: now + 5 * day, isPremium: true) == .review)
policy.recordCompletion(id: "4", at: now, calendar: .current)
precondition(policy.completions == 5)
policy.markPresented(.review, at: now + 5 * day)
for i in 5..<10 { policy.recordCompletion(id: "\(i)", at: now + 6 * day, calendar: .current) }
precondition(policy.nextPrompt(at: now + 6 * day, isPremium: false) == nil)
precondition(policy.nextPrompt(at: now + 12 * day, isPremium: false) == .premium)
precondition(policy.nextPrompt(at: now + 12 * day, isPremium: true) == nil)
policy.markPresented(.premium, at: now + 12 * day)
for i in 10..<20 { policy.recordCompletion(id: "\(i)", at: now + 13 * day, calendar: .current) }
precondition(policy.nextPrompt(at: now + 41 * day, isPremium: false) == nil)
precondition(policy.nextPrompt(at: now + 42 * day, isPremium: false) == .premium)
let restored = try JSONDecoder().decode(WorkoutPromptPolicy.self, from: JSONEncoder().encode(policy))
precondition(restored.nextPrompt(at: now + 42 * day, isPremium: false) == .premium)
var oneDay = WorkoutPromptPolicy()
for i in 0..<50 { oneDay.recordCompletion(id: "\(i)", at: now, calendar: .current) }
precondition(oneDay.nextPrompt(at: now, isPremium: false) == nil)
print("PASS: first-use suppression, repeat saves, review/premium spacing, 30-day premium cooldown, premium exclusion and persistence")
