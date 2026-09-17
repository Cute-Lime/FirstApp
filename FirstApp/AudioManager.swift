import AVFoundation
import Foundation

enum GameSound: String, CaseIterable {
    case buttonTap = "ui_tap"
    case summon = "summon"
    case attack = "attack"
    case swordAttack = "sword_attack"
    case bowAttack = "bow_attack"
    case shieldAttack = "shield_attack"
    case victory = "victory"
    case defeat = "defeat"
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private var backgroundPlayer: AVAudioPlayer?
    private var activeEffectPlayers: [AVAudioPlayer] = []

    private init() {}

    func startBattleMusic() {
        configureSession()
        if let player = backgroundPlayer {
            player.currentTime = 0
            if !player.isPlaying {
                player.play()
            }
            return
        }

        guard let url = Bundle.main.url(forResource: "battle_theme", withExtension: "mp3") ??
                        Bundle.main.url(forResource: "battle_theme", withExtension: "mp3", subdirectory: "Audio") else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.35
            player.prepareToPlay()
            player.play()
            backgroundPlayer = player
        } catch {
            print("Failed to start battle music: \(error)")
        }
    }

    func pauseBattleMusic() {
        backgroundPlayer?.pause()
    }

    func resumeBattleMusic() {
        configureSession()
        backgroundPlayer?.play()
    }

    func stopBattleMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }

    func play(_ sound: GameSound) {
        configureSession()
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") ??
                        Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Audio") else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sound == .buttonTap ? 0.6 : 0.85
            player.prepareToPlay()
            player.play()
            
            // Retain player until playback finishes
            activeEffectPlayers.append(player)
            // Clean up finished players
            activeEffectPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("Failed to play sound \(sound.rawValue): \(error)")
        }
    }

    private func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }
}
