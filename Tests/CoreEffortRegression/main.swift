import Foundation

var offsets = Set<String>()
var bracing = Set<Bool>()
for index in 0..<3_200 {
    let elapsed = Double(index) / 100
    let pose = PochiCoreEffort.sample(elapsed: elapsed, reduceMotion: false)
    precondition(abs(pose.x) <= 3 && abs(pose.y) <= 1, "Shake stays near its ground anchor")
    if !pose.bracing { precondition(pose.x == 0 && pose.y == 0, "Rest returns exactly to the anchor") }
    offsets.insert("\(pose.x),\(pose.y)")
    bracing.insert(pose.bracing)
    let reduced = PochiCoreEffort.sample(elapsed: elapsed, reduceMotion: true)
    precondition(reduced.x == 0 && reduced.y == 0, "Reduce Motion removes shaking")
    precondition(reduced.bracing == pose.bracing, "Reduce Motion still has breathing/effort poses")
}
precondition(offsets.count >= 6 && bracing.count == 2, "Visible varied shake, brace and release phases")
for index in 0..<100 {
    let pose = PochiCoreEffort.sample(elapsed: 3.2 * Double(index) + 0.1, reduceMotion: false)
    precondition(pose.x == 0 && pose.y == 0, "Repeated cycles never drift")
}
print("PASS: varied effort/rest phases, bounded movement, no accumulated drift and motion-reduced breathing")
