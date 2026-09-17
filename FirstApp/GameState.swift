import Foundation
import Observation

enum Faction: Equatable {
    case player
    case enemy

    var opponent: Faction {
        self == .player ? .enemy : .player
    }
}

enum UnitType: String, CaseIterable, Identifiable {
    case knight
    case archer
    case guardian

    var id: Self { self }

    var name: String {
        switch self {
        case .knight: "近戰騎士"
        case .archer: "遠程弓箭手"
        case .guardian: "盾牌守衛"
        }
    }

    var iconText: String {
        switch self {
        case .knight: "🗡️"
        case .archer: "🏹"
        case .guardian: "🛡️"
        }
    }

    var symbolName: String {
        switch self {
        case .knight: "🗡️"
        case .archer: "scope"
        case .guardian: "shield.fill"
        }
    }

    var cost: Int {
        switch self {
        case .knight: 90
        case .archer: 140
        case .guardian: 120
        }
    }

    var hitPoints: CGFloat {
        switch self {
        case .knight: 280
        case .archer: 140
        case .guardian: 620
        }
    }

    var damage: CGFloat {
        switch self {
        case .knight: 42
        case .archer: 78
        case .guardian: 18
        }
    }

    var attackInterval: TimeInterval {
        switch self {
        case .knight: 1.0
        case .archer: 1.4
        case .guardian: 1.3
        }
    }

    var movementSpeed: CGFloat {
        switch self {
        case .knight: 52
        case .archer: 42
        case .guardian: 27
        }
    }

    var attackRange: CGFloat {
        switch self {
        case .knight: 34
        case .archer: 175
        case .guardian: 30
        }
    }
}

enum MatchResult: Equatable {
    case victory
    case defeat

    var title: String {
        switch self {
        case .victory: "勝利！"
        case .defeat: "失敗…"
        }
    }

    var detail: String {
        switch self {
        case .victory: "王國成功守住了城堡。"
        case .defeat: "魔物突破防線，再試一次吧！"
        }
    }
}

@MainActor
@Observable
final class GameState {
    var playerMoney = 100
    var enemyMoney = 100
    var playerCastleHealth: CGFloat = 1_500
    var enemyCastleHealth: CGFloat = 1_500
    var isPaused = false
    var result: MatchResult?

    var isFinished: Bool { result != nil }

    func reset() {
        playerMoney = 100
        enemyMoney = 100
        playerCastleHealth = 1_500
        enemyCastleHealth = 1_500
        isPaused = false
        result = nil
    }

    func canSummon(_ type: UnitType, for faction: Faction) -> Bool {
        switch faction {
        case .player: playerMoney >= type.cost
        case .enemy: enemyMoney >= type.cost
        }
    }

    func spend(for type: UnitType, faction: Faction) -> Bool {
        guard canSummon(type, for: faction) else { return false }

        switch faction {
        case .player: playerMoney -= type.cost
        case .enemy: enemyMoney -= type.cost
        }
        return true
    }

    func addIncome(seconds: TimeInterval) {
        guard !isPaused, !isFinished else { return }
        let income = Int((seconds * 12).rounded(.down))
        guard income > 0 else { return }
        playerMoney = min(999, playerMoney + income)
        enemyMoney = min(999, enemyMoney + income)
    }

    func damageCastle(of faction: Faction, amount: CGFloat) {
        guard !isFinished else { return }

        switch faction {
        case .player:
            playerCastleHealth = max(0, playerCastleHealth - amount)
            if playerCastleHealth == 0 {
                result = .defeat
                AudioManager.shared.play(.defeat)
            }
        case .enemy:
            enemyCastleHealth = max(0, enemyCastleHealth - amount)
            if enemyCastleHealth == 0 {
                result = .victory
                AudioManager.shared.play(.victory)
            }
        }
    }
}
