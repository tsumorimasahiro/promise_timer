import Foundation

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
var cues = WorkoutCountdownCues()
func tick(_ remaining: Int, running: Bool = true, foreground: Bool = true, id: String = "one") -> WorkoutSoundCue? {
    cues.cue(sessionID: id, remaining: remaining, isRunning: running, isForeground: foreground)
}
require(tick(10) == nil, "No continuous workout beeps")
for remaining in [3, 2, 1] {
    require(tick(remaining) == .countdown, "One beep for each final second")
    for _ in 0..<4 { require(tick(remaining) == nil, "Repeated timer ticks do not repeat the beep") }
    require(tick(remaining, running: false) == nil, "Pause is silent")
    require(tick(remaining) == nil, "Resume does not repeat a beat")
}
require(tick(0) == .timerFinished, "Timer ends with a distinct cue")
require(tick(0) == nil, "Timer completion plays once")
require(tick(2, id: "short") == .countdown, "A short timer starts with the correct remaining cue")
require(tick(1, foreground: false, id: "short") == nil, "Background is silent")
require(tick(0, id: "short") == .timerFinished, "Returning to zero does not play missed countdown beats")
require(tick(3, running: false, id: "paused") == nil, "Paused timer cannot start countdown audio")
require(tick(3, id: "paused") == .countdown, "Resuming an unheard second can play its cue")

func uint32(_ data: Data, _ index: Int) -> UInt32 {
    (0..<4).reduce(0) { $0 | UInt32(data[index+$1]) << ($1*8) }
}
var rendered = Set<Data>()
for cue in WorkoutSoundCue.allCases {
    let data = cue.waveData
    require(String(data: data[0..<4], encoding: .ascii) == "RIFF", "Valid RIFF header")
    require(String(data: data[8..<12], encoding: .ascii) == "WAVE", "Valid WAV format")
    require(uint32(data, 24) == 22_050, "Expected sample rate")
    require(Int(uint32(data, 40)) == data.count-44, "PCM size matches the header")
    require(data.count > 2_000 && data.count < 30_000, "Cues are brief")
    require(data[44] == 0 && data[45] == 0 && data[data.count-1] == 0 && data[data.count-2] == 0, "No start/end clicks")
    var peak = 0
    for index in stride(from: 44, to: data.count, by: 2) {
        let value = Int(Int16(bitPattern: UInt16(data[index]) | UInt16(data[index+1]) << 8))
        peak = max(peak, abs(value))
    }
    require(peak > 1_000 && peak < 30_000, "Audible signal with headroom")
    rendered.insert(data)
}
require(rendered.count == 4, "Four distinct cues")
print("PASS: final-three-second timing, pause/resume, duplicate suppression, background silence, short timers and four valid unclipped WAV cues")
