import Foundation

/// Short, original tones; the app does not need downloaded audio assets.
enum WorkoutSoundCue: CaseIterable {
    case start, countdown, timerFinished, saved

    var waveData: Data {
        let sampleRate = 22_050
        let notes: [(frequency: Double, start: Double, duration: Double)]
        switch self {
        case .start: notes = [(880, 0, 0.13)]
        case .countdown: notes = [(660, 0, 0.09)]
        case .timerFinished: notes = [(523.25, 0, 0.36), (659.25, 0.07, 0.36), (783.99, 0.14, 0.42)]
        case .saved: notes = [(783.99, 0, 0.12), (1046.5, 0.10, 0.14), (1318.51, 0.22, 0.24)]
        }
        let count = Int(ceil(notes.map { $0.start + $0.duration }.max()! * Double(sampleRate))) + 1
        var samples = [Double](repeating: 0, count: count)
        for note in notes {
            let start = Int(note.start * Double(sampleRate))
            let length = Int(note.duration * Double(sampleRate))
            for i in 0..<length {
                let time = Double(i) / Double(sampleRate)
                let progress = Double(i) / Double(max(1, length-1))
                // Rounded attack and release avoid clicks at the ends of notes.
                let envelope = pow(sin(.pi * progress), 2) * exp(-2 * progress)
                let phase = 2 * .pi * note.frequency * time
                samples[start+i] += (sin(phase) + 0.12 * sin(2*phase)) * envelope * 0.35
            }
        }
        var data = Data()
        func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
        func u16(_ value: UInt16) {
            data.append(UInt8(value & 255)); data.append(UInt8(value >> 8))
        }
        func u32(_ value: UInt32) {
            for shift in stride(from: 0, through: 24, by: 8) { data.append(UInt8((value >> shift) & 255)) }
        }
        let bytes = UInt32(samples.count * 2)
        ascii("RIFF"); u32(36 + bytes); ascii("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate*2))
        u16(2); u16(16); ascii("data"); u32(bytes)
        for sample in samples {
            u16(UInt16(bitPattern: Int16((max(-1, min(1, sample)) * Double(Int16.max)).rounded())))
        }
        return data
    }
}

/// The 0.25s UI timer may observe the same second repeatedly. Pausing, changing
/// tabs and returning from the background must not replay a countdown beat.
struct WorkoutCountdownCues {
    private var sessionID: String?
    private var lastRemaining: Int?

    mutating func cue(sessionID: String, remaining: Int, isRunning: Bool, isForeground: Bool) -> WorkoutSoundCue? {
        if self.sessionID != sessionID { self.sessionID = sessionID; lastRemaining = nil }
        guard isRunning, isForeground, lastRemaining != remaining else { return nil }
        lastRemaining = remaining
        if remaining == 0 { return .timerFinished }
        return (1...3).contains(remaining) ? .countdown : nil
    }
}
