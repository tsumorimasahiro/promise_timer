import AVFoundation
import UIKit

/// Ambient playback respects the silent switch and mixes with the user's music.
@MainActor
final class WorkoutSounds: NSObject, AVAudioPlayerDelegate {
    static let shared = WorkoutSounds()
    static let enabledKey = "workoutSoundsEnabled"
    static let defaults = UserDefaults(suiteName: "group.com.tsumori.promise_timer") ?? .standard
    private var player: AVAudioPlayer?
    private let waves = Dictionary(uniqueKeysWithValues: WorkoutSoundCue.allCases.map { ($0, $0.waveData) })

    static var isEnabled: Bool {
        defaults.object(forKey: enabledKey) == nil || defaults.bool(forKey: enabledKey)
    }

    func play(_ cue: WorkoutSoundCue) {
        guard Self.isEnabled, UIApplication.shared.applicationState == .active,
              let data = waves[cue] else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            player?.stop()
            let next = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            next.delegate = self
            next.volume = 0.7
            player = next
            next.play()
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stop()
        }
    }
}
