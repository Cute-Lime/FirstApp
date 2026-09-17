import AVFoundation
import Foundation

enum GameSound: String, CaseIterable {
    case buttonTap = "ui_tap"
    case summon = "summon"
    case attack = "attack"
    case victory = "victory"
    case defeat = "defeat"
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private var backgroundPlayer: AVAudioPlayer?
    private var effectPlayers: [GameSound: AVAudioPlayer] = [:]

    private init() {}

    func startBattleMusic() {
        configureSession()
        guard backgroundPlayer == nil,
              let url = Bundle.main.url(forResource: "battle_theme", withExtension: "mp3") ?? Bundle.main.url(forResource: "battle_theme", withExtension: "mp3", subdirectory: "Audio") else {
            return
        }

        backgroundPlayer = try? AVAudioPlayer(contentsOf: url)
        backgroundPlayer?.numberOfLoops = -1
        backgroundPlayer?.volume = 0.32
        backgroundPlayer?.prepareToPlay()
        backgroundPlayer?.play()
    }

    func pauseBattleMusic() {
        backgroundPlayer?.pause()
    }

    func resumeBattleMusic() {
        backgroundPlayer?.play()
    }

    func stopBattleMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }

    func play(_ sound: GameSound) {
        configureSession()
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Audio") else {
            return
        }

        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.7
        player?.prepareToPlay()
        player?.play()
        effectPlayers[sound] = player
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
