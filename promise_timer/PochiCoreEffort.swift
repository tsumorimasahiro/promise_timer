import Foundation

/// Absolute offsets keep repeated effort from moving Pochi across the room.
struct PochiCoreEffort {
    let x: Double
    let y: Double
    let bracing: Bool

    static func sample(elapsed: TimeInterval, reduceMotion: Bool) -> Self {
        let phase = max(0, elapsed).truncatingRemainder(dividingBy: 3.2)
        let bracing = (0.4..<1.25).contains(phase) || (1.8..<2.6).contains(phase)
        guard bracing, !reduceMotion else { return Self(x: 0, y: 0, bracing: bracing) }
        let steps: [(Double, Double)] = [(0,0), (2,1), (-2,-1), (3,0), (-3,1), (1,-1), (-2,0), (0,0)]
        let offset = phase < 1.25 ? phase-0.4 : phase-1.8
        let step = steps[Int(offset / 0.075) % steps.count]
        return Self(x: step.0, y: step.1, bracing: true)
    }
}
