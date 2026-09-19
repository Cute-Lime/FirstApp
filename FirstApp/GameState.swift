import Foundation
import Observation

enum Faction: Equatable {
    case player
    case enemy

    var opponent: Faction {
        self == .player ? .enemy : .player
    }
}

enum GameLevel: Int, CaseIterable, Identifiable, Equatable {
    case frontier = 1
    case highlands
    case citadel

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .frontier: "第一關・綠野前線"
        case .highlands: "第二關・峽谷伏擊"
        case .citadel: "第三關・魔王城門"
        }
    }

    var subtitle: String {
        switch self {
        case .frontier: "熟悉部隊與城堡經濟"
        case .highlands: "敵軍更常派出遠程單位"
        case .citadel: "守住強大且富裕的魔物軍團"
        }
    }

    var enemyIncomeRate: Double {
        switch self {
        case .frontier: 14
        case .highlands: 20
        case .citadel: 28
        }
    }

    var enemySpawnInterval: ClosedRange<TimeInterval> {
        switch self {
        case .frontier: 3.5...5.5
        case .highlands: 2.8...4.2
        case .citadel: 2.2...3.5
        }
    }

    var enemyUnitWeights: [(UnitType, Int)] {
        switch self {
        case .frontier: [(.knight, 50), (.archer, 30), (.guardian, 20)]
        case .highlands: [(.knight, 30), (.archer, 48), (.guardian, 22)]
        case .citadel: [(.knight, 30), (.archer, 28), (.guardian, 42)]
        }
    }

    var tintName: String {
        switch self {
        case .frontier: "leaf.fill"
        case .highlands: "mountain.2.fill"
        case .citadel: "flame.fill"
        }
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
        case .victory: "王國成功守住城堡。"
        case .defeat: "魔物突破防線，再試一次吧！"
        }
    }
}

@MainActor
@Observable
final class GameState {
    // Castle Health cut in half for faster & balanced matches
    static let castleHealth: CGFloat = 800
    static let maximumEconomyLevel = 5

    var selectedLevel: GameLevel = .frontier
    var playerMoney = 150
    var enemyMoney = 150
    var playerCastleHealth: CGFloat = castleHealth
    var enemyCastleHealth: CGFloat = castleHealth
    var economyLevel = 1
    var isPaused = false
    var result: MatchResult?

    private var playerIncomeRemainder = 0.0
    private var enemyIncomeRemainder = 0.0

    var isFinished: Bool { result != nil }

    // Money generation rate doubled!
    var playerIncomeRate: Double {
        switch economyLevel {
        case 1: 16
        case 2: 24
        case 3: 34
        case 4: 46
        default: 60
        }
    }

    var nextEconomyUpgradeCost: Int? {
        guard economyLevel < Self.maximumEconomyLevel else { return nil }
        return [100, 170, 260, 380][economyLevel - 1]
    }

    func reset(for level: GameLevel) {
        selectedLevel = level
        playerMoney = 150
        enemyMoney = 150
        playerCastleHealth = Self.castleHealth
        enemyCastleHealth = Self.castleHealth
        economyLevel = 1
        playerIncomeRemainder = 0
        enemyIncomeRemainder = 0
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

    func upgradeEconomy() -> Bool {
        guard let cost = nextEconomyUpgradeCost, playerMoney >= cost, !isPaused, !isFinished else {
            return false
        }
        playerMoney -= cost
        economyLevel += 1
        return true
    }

    func addIncome(seconds: TimeInterval) {
        guard !isPaused, !isFinished else { return }

        playerIncomeRemainder += seconds * playerIncomeRate
        enemyIncomeRemainder += seconds * selectedLevel.enemyIncomeRate

        let playerIncome = Int(playerIncomeRemainder.rounded(.down))
        let enemyIncome = Int(enemyIncomeRemainder.rounded(.down))
        playerIncomeRemainder -= Double(playerIncome)
        enemyIncomeRemainder -= Double(enemyIncome)

        playerMoney = min(999, playerMoney + playerIncome)
        enemyMoney = min(999, enemyMoney + enemyIncome)
    }

    func damageCastle(of faction: Faction, amount: CGFloat) {
        guard !isFinished else { return }

        switch faction {
        case .player:
            playerCastleHealth = max(0, playerCastleHealth - amount)
            if playerCastleHealth == 0 {
                result = .defeat
                AudioManager.shared.stopBattleMusic()
                AudioManager.shared.play(.defeat)
            }
        case .enemy:
            enemyCastleHealth = max(0, enemyCastleHealth - amount)
            if enemyCastleHealth == 0 {
                result = .victory
                AudioManager.shared.stopBattleMusic()
                AudioManager.shared.play(.victory)
            }
        }
    }
}
