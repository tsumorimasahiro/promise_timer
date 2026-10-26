import Foundation

var world = PochiWorldState()
let habits = PochiLifeHabits()
var morning = PochiDailyRoutine()
let morningMoves = (0..<8).map { morning.next(phase: .morning, now: Double($0 * 25), world: world, habits: habits).move }
precondition(morningMoves == [.stretch, .look, .walk, .sit, .blink, .cozyRest, .ears, .sit])
var day = PochiDailyRoutine()
let daytimeMoves = (0..<9).map { day.next(phase: .daytime, now: Double($0 * 25), world: world, habits: habits).move }
precondition(daytimeMoves == [.look, .walk, .sit, .blink, .cozyRest, .ears, .walk, .sit, .nap])
precondition(!daytimeMoves.contains(.hop) && !daytimeMoves.contains(.welcome))
precondition(day.next(phase: .evening, now: 500, world: world, habits: habits).move == .look)
let eveningMoves = (0..<5).map { day.next(phase: .evening, now: Double(525 + $0 * 25), world: world, habits: habits).move }
precondition(eveningMoves == [.sit, .yawn, .cozyRest, .blink, .bedtime])
day.didComplete(.exercise)
precondition(day.next(phase: .deepNight, now: 1000, world: world, habits: habits).move == .nap)
precondition(day.next(phase: .morning, now: 2000, world: world, habits: habits).move == .stretch)
day.didComplete(.exercise)
precondition(day.next(phase: .morning, now: 2001, world: world, habits: habits).move == .cozyRest)
day.didComplete(.study)
precondition(day.next(phase: .morning, now: 2002, world: world, habits: habits).move == .sit)

// Even old reading/exercise progress never reintroduces props or training during rest.
world.activeThemes = [.reading, .studying, .exercise]
world.growth = [.reading: 30, .studying: 30, .exercise: 30]
world.totalCompletions = 100
let oldHabits = PochiLifeHabits(sharedDays: 30, daysByActivity: ["study": 30, "exercise": 30])
let propOrTrainingMoves: [PochiIdleMove] = [.readRest, .shelfLook, .deskWatch, .ballPlay,
    .togetherRead, .togetherTidy, .pushups, .squats, .dumbbells]
for phase: PochiLifePhase in [.morning, .daytime, .evening, .deepNight] {
    var routine = PochiDailyRoutine()
    var moves: [PochiIdleMove] = []
    for i in 0..<100 {
        let move = routine.next(phase: phase, now: Double(i * 60), world: world, habits: oldHabits).move
        precondition(!propOrTrainingMoves.contains(move))
        moves.append(move)
    }
    if phase == .daytime { precondition(moves.contains(.nap) && moves.contains(.specialRest)) }
    if phase == .evening { precondition(moves.contains(.yawn) && moves.contains(.bedtime)) }
    if phase == .deepNight { precondition(moves.allSatisfy { $0 == .nap }) }
}
precondition(PochiTogetherRoutine.moves(for: .strength).contains(.pushups))
print("PASS: normal morning/day/evening rest, quiet nights, completion follow-up, no props or workouts during idle even with legacy progress, active training retained")
