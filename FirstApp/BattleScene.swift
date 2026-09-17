import SpriteKit
import UIKit

final class BattleUnitNode: SKNode {
    let id = UUID()
    let type: UnitType
    let faction: Faction
    var hitPoints: CGFloat
    var attackCooldown: TimeInterval = 0
    var isDying = false

    private let healthFill: SKShapeNode
    private let bodySprite: SKNode

    init(type: UnitType, faction: Faction) {
        self.type = type
        self.faction = faction
        hitPoints = type.hitPoints

        let healthFillNode = SKShapeNode(rectOf: CGSize(width: 40, height: 5), cornerRadius: 2.5)
        self.healthFill = healthFillNode

        // Load sprite image for unit from Assets.xcassets or Bundle
        let spriteName: String
        switch (faction, type) {
        case (.player, .knight): spriteName = "player_knight"
        case (.player, .archer): spriteName = "player_archer"
        case (.player, .guardian): spriteName = "player_guardian"
        case (.enemy, .knight): spriteName = "enemy_knight"
        case (.enemy, .archer): spriteName = "enemy_archer"
        case (.enemy, .guardian): spriteName = "enemy_guardian"
        }

        let texture = SKTexture(imageNamed: spriteName)
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 58, height: 58))
        // Position sprite so feet touch the ground shadow
        sprite.position.y = -3
        self.bodySprite = sprite

        super.init()

        // Ground shadow under unit
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 12))
        shadow.fillColor = .black.withAlphaComponent(0.24)
        shadow.strokeColor = .clear
        shadow.position.y = -26
        addChild(shadow)

        addChild(bodySprite)

        // Health bar background & fill (adjusted position)
        let healthBackground = SKShapeNode(rectOf: CGSize(width: 44, height: 8), cornerRadius: 4)
        healthBackground.fillColor = .black.withAlphaComponent(0.65)
        healthBackground.strokeColor = .clear
        healthBackground.position.y = 36
        addChild(healthBackground)

        healthFill.fillColor = .systemGreen
        healthFill.strokeColor = .clear
        healthFill.position.y = 36
        addChild(healthFill)

        // Subtle idle animation
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 3, duration: 0.55),
            .moveBy(x: 0, y: -3, duration: 0.55)
        ])
        bodySprite.run(.repeatForever(bob), withKey: "idle")
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func receiveDamage(_ amount: CGFloat) {
        guard !isDying else { return }
        hitPoints = max(0, hitPoints - amount)
        updateHealthBar()

        if hitPoints == 0 {
            isDying = true
            bodySprite.removeAction(forKey: "idle")
            let disappear = SKAction.group([
                .fadeOut(withDuration: 0.22),
                .scale(to: 0.15, duration: 0.22)
            ])
            run(.sequence([disappear, .removeFromParent()]))
        }
    }

    func playAttack() {
        let pulse = SKAction.sequence([
            .scale(to: 1.15, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ])
        bodySprite.run(pulse, withKey: "attack")
    }

    private func updateHealthBar() {
        let percentage = hitPoints / type.hitPoints
        healthFill.xScale = percentage
        healthFill.position.x = -20 * (1 - percentage)
        healthFill.fillColor = percentage < 0.3 ? .systemRed : .systemGreen
    }
}

final class BattleScene: SKScene {
    weak var gameState: GameState?
    private var lastUpdateTime: TimeInterval = 0
    private var enemySpawnCountdown: TimeInterval = 2.8
    private var incomeAccumulator: TimeInterval = 0
    private var enemyTargetUnit: UnitType?

    private let playerCastleX: CGFloat = 88
    private let enemyCastleInset: CGFloat = 88
    private let laneY: CGFloat = 330

    private var playerCastleHealthFill: SKShapeNode?
    private var enemyCastleHealthFill: SKShapeNode?
    private var playerCastleHPText: SKLabelNode?
    private var enemyCastleHPText: SKLabelNode?

    init(size: CGSize, gameState: GameState) {
        self.gameState = gameState
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = SKColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func didMove(to view: SKView) {
        buildBattlefield()
    }

    func summonPlayer(_ type: UnitType) {
        guard let gameState, !gameState.isPaused, !gameState.isFinished,
              gameState.spend(for: type, faction: .player) else { return }
        addUnit(type, faction: .player)
        Task { @MainActor in
            AudioManager.shared.play(.summon)
        }
    }

    func tearDown() {
        removeAllActions()
        removeAllChildren()
        gameState = nil
    }

    override func update(_ currentTime: TimeInterval) {
        guard let gameState, !gameState.isPaused, !gameState.isFinished else {
            lastUpdateTime = currentTime
            return
        }

        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }

        let delta = min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime
        incomeAccumulator += delta
        if incomeAccumulator >= 1 {
            gameState.addIncome(seconds: incomeAccumulator)
            incomeAccumulator = 0
        }

        enemySpawnCountdown -= delta
        if enemySpawnCountdown <= 0 {
            summonEnemy()
            enemySpawnCountdown = Double.random(in: 2.2...3.5)
        }

        updateUnits(delta: delta)
        updateCastleHealthBars()
    }

    private func buildBattlefield() {
        // Sky background
        let sky = SKShapeNode(rectOf: size)
        sky.fillColor = SKColor(red: 0.18, green: 0.28, blue: 0.42, alpha: 1)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -10
        addChild(sky)

        // Distant mountains / horizon accent
        let mountains = SKShapeNode(rectOf: CGSize(width: size.width, height: 160))
        mountains.fillColor = SKColor(red: 0.15, green: 0.22, blue: 0.32, alpha: 1)
        mountains.strokeColor = .clear
        mountains.position = CGPoint(x: size.width / 2, y: 380)
        mountains.zPosition = -9.5
        addChild(mountains)

        // Green grass at the bottom aligned to the bottom edge of the road
        let grassHeight = laneY - 55
        let grass = SKShapeNode(rectOf: CGSize(width: size.width, height: grassHeight))
        grass.fillColor = SKColor(red: 0.18, green: 0.42, blue: 0.24, alpha: 1)
        grass.strokeColor = .clear
        grass.position = CGPoint(x: size.width / 2, y: grassHeight / 2)
        grass.zPosition = -9
        addChild(grass)

        // Straight rectangle road spanning from left edge to right edge (no rounded ellipse)
        let laneHeight: CGFloat = 110
        let lane = SKShapeNode(rectOf: CGSize(width: size.width, height: laneHeight))
        lane.fillColor = SKColor(red: 0.58, green: 0.47, blue: 0.33, alpha: 1)
        lane.strokeColor = .clear
        lane.position = CGPoint(x: size.width / 2, y: laneY)
        lane.zPosition = -8
        addChild(lane)

        // Top border line for road (stone / dark wood trim)
        let topBorder = SKShapeNode(rectOf: CGSize(width: size.width, height: 5))
        topBorder.fillColor = SKColor(red: 0.38, green: 0.28, blue: 0.18, alpha: 1)
        topBorder.strokeColor = .clear
        topBorder.position = CGPoint(x: size.width / 2, y: laneY + (laneHeight / 2) - 2.5)
        topBorder.zPosition = -7.5
        addChild(topBorder)

        // Bottom border line for road
        let bottomBorder = SKShapeNode(rectOf: CGSize(width: size.width, height: 5))
        bottomBorder.fillColor = SKColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1)
        bottomBorder.strokeColor = .clear
        bottomBorder.position = CGPoint(x: size.width / 2, y: laneY - (laneHeight / 2) + 2.5)
        bottomBorder.zPosition = -7.5
        addChild(bottomBorder)

        addCastle(faction: .player, x: playerCastleX)
        addCastle(faction: .enemy, x: size.width - enemyCastleInset)
    }

    private func addCastle(faction: Faction, x: CGFloat) {
        // Main Castle Body
        let castle = SKShapeNode(rectOf: CGSize(width: 80, height: 140), cornerRadius: 10)
        castle.fillColor = faction == .player ? SKColor(red: 0.18, green: 0.35, blue: 0.65, alpha: 1) : SKColor(red: 0.70, green: 0.20, blue: 0.20, alpha: 1)
        castle.strokeColor = SKColor(red: 0.85, green: 0.72, blue: 0.45, alpha: 1)
        castle.lineWidth = 3
        castle.position = CGPoint(x: x, y: laneY + 55)
        addChild(castle)

        // Castle Wall Crenellations (battlements on top)
        for i in -2...2 {
            let battlement = SKShapeNode(rectOf: CGSize(width: 12, height: 14), cornerRadius: 2)
            battlement.fillColor = faction == .player ? SKColor(red: 0.14, green: 0.28, blue: 0.52, alpha: 1) : SKColor(red: 0.55, green: 0.15, blue: 0.15, alpha: 1)
            battlement.strokeColor = SKColor(red: 0.85, green: 0.72, blue: 0.45, alpha: 0.8)
            battlement.lineWidth = 1.5
            battlement.position = CGPoint(x: x + CGFloat(i * 15), y: laneY + 128)
            addChild(battlement)
        }

        // Crown Icon
        let crown = SKLabelNode(text: faction == .player ? "♚" : "♛")
        crown.fontName = "AvenirNext-Bold"
        crown.fontSize = 44
        crown.verticalAlignmentMode = .center
        crown.position = CGPoint(x: x, y: laneY + 58)
        crown.zPosition = 1
        addChild(crown)

        // Castle Health Bar above castle (larger size, only numbers)
        let barWidth: CGFloat = 104
        let barHeight: CGFloat = 12
        let healthBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 6)
        healthBg.fillColor = .black.withAlphaComponent(0.75)
        healthBg.strokeColor = SKColor(red: 0.85, green: 0.72, blue: 0.45, alpha: 0.9)
        healthBg.lineWidth = 1.5
        healthBg.position = CGPoint(x: x, y: laneY + 152)
        healthBg.zPosition = 3
        addChild(healthBg)

        let healthFill = SKShapeNode(rectOf: CGSize(width: barWidth - 4, height: barHeight - 4), cornerRadius: 4)
        healthFill.fillColor = faction == .player ? .systemBlue : .systemRed
        healthFill.strokeColor = .clear
        healthFill.position = CGPoint(x: x, y: laneY + 152)
        healthFill.zPosition = 4
        addChild(healthFill)

        let hpLabel = SKLabelNode(text: "1500 / 1500")
        hpLabel.fontName = "Cinzel-Bold"
        hpLabel.fontSize = 14
        hpLabel.fontColor = .white
        hpLabel.verticalAlignmentMode = .bottom
        hpLabel.position = CGPoint(x: x, y: laneY + 162)
        hpLabel.zPosition = 5
        addChild(hpLabel)

        if faction == .player {
            playerCastleHealthFill = healthFill
            playerCastleHPText = hpLabel
        } else {
            enemyCastleHealthFill = healthFill
            enemyCastleHPText = hpLabel
        }
    }

    private func updateCastleHealthBars() {
        guard let gameState else { return }

        let maxHP: CGFloat = 1500

        let playerHP = max(0, gameState.playerCastleHealth)
        let playerPct = playerHP / maxHP
        playerCastleHealthFill?.xScale = playerPct
        playerCastleHealthFill?.position.x = playerCastleX - (50 * (1 - playerPct))
        playerCastleHPText?.text = "\(Int(playerHP)) / 1500"

        let enemyHP = max(0, gameState.enemyCastleHealth)
        let enemyPct = enemyHP / maxHP
        let enemyCastleX = size.width - enemyCastleInset
        enemyCastleHealthFill?.xScale = enemyPct
        enemyCastleHealthFill?.position.x = enemyCastleX - (50 * (1 - enemyPct))
        enemyCastleHPText?.text = "\(Int(enemyHP)) / 1500"
    }

    private func addUnit(_ type: UnitType, faction: Faction) {
        let unit = BattleUnitNode(type: type, faction: faction)
        unit.position = CGPoint(
            x: faction == .player ? playerCastleX + 55 : size.width - enemyCastleInset - 55,
            y: laneY
        )
        unit.zPosition = 2
        addChild(unit)
    }

    private func summonEnemy() {
        guard let gameState else { return }
        
        if enemyTargetUnit == nil {
            let playerUnits = unitNodes(for: .player)
            let enemyUnits = unitNodes(for: .enemy)
            if playerUnits.count > enemyUnits.count + 1 {
                enemyTargetUnit = .guardian
            } else {
                let roll = Int.random(in: 1...100)
                if roll <= 45 {
                    enemyTargetUnit = .knight
                } else if roll <= 75 {
                    enemyTargetUnit = .archer
                } else {
                    enemyTargetUnit = .guardian
                }
            }
        }

        guard let target = enemyTargetUnit else { return }
        if gameState.spend(for: target, faction: .enemy) {
            addUnit(target, faction: .enemy)
            enemyTargetUnit = nil
        }
    }

    private func updateUnits(delta: TimeInterval) {
        let units = children.compactMap { $0 as? BattleUnitNode }.filter { !$0.isDying }
        for unit in units {
            unit.attackCooldown = max(0, unit.attackCooldown - delta)

            if let target = nearestOpponent(to: unit) {
                let distance = abs(target.position.x - unit.position.x)
                if distance <= unit.type.attackRange + 40 {
                    attack(unit, target: target)
                } else {
                    move(unit, delta: delta)
                }
            } else if canAttackCastle(unit) {
                attackCastle(with: unit)
            } else {
                move(unit, delta: delta)
            }
        }
    }

    private func nearestOpponent(to unit: BattleUnitNode) -> BattleUnitNode? {
        unitNodes(for: unit.faction.opponent)
            .filter { !$0.isDying }
            .min { abs($0.position.x - unit.position.x) < abs($1.position.x - unit.position.x) }
    }

    private func unitNodes(for faction: Faction) -> [BattleUnitNode] {
        children.compactMap { $0 as? BattleUnitNode }
            .filter { $0.faction == faction && !$0.isDying }
    }

    private func move(_ unit: BattleUnitNode, delta: TimeInterval) {
        let direction: CGFloat = unit.faction == .player ? 1 : -1
        unit.position.x += direction * unit.type.movementSpeed * delta
        let walkingScale: CGFloat = Int((lastUpdateTime * 8).rounded()) % 2 == 0 ? 1.03 : 0.98
        unit.xScale = walkingScale
    }

    private func attack(_ attacker: BattleUnitNode, target: BattleUnitNode) {
        guard attacker.attackCooldown == 0, !target.isDying else { return }
        attacker.attackCooldown = attacker.type.attackInterval
        attacker.playAttack()
        target.receiveDamage(attacker.type.damage)
        Task { @MainActor in
            AudioManager.shared.play(.attack)
        }
        showHit(at: target.position)
    }

    private func canAttackCastle(_ unit: BattleUnitNode) -> Bool {
        let castleX = unit.faction == .player ? size.width - enemyCastleInset : playerCastleX
        return abs(unit.position.x - castleX) <= unit.type.attackRange + 42
    }

    private func attackCastle(with unit: BattleUnitNode) {
        guard unit.attackCooldown == 0, let gameState else { return }
        unit.attackCooldown = unit.type.attackInterval
        unit.playAttack()
        gameState.damageCastle(of: unit.faction.opponent, amount: unit.type.damage)
        Task { @MainActor in
            AudioManager.shared.play(.attack)
        }
        let castleX = unit.faction == .player ? size.width - enemyCastleInset : playerCastleX
        showHit(at: CGPoint(x: castleX, y: laneY + 30))
    }

    private func showHit(at position: CGPoint) {
        let hit = SKLabelNode(text: "✦")
        hit.fontName = "AvenirNext-Bold"
        hit.fontSize = 28
        hit.fontColor = .systemYellow
        hit.position = position
        hit.zPosition = 8
        addChild(hit)
        hit.run(.sequence([
            .group([.moveBy(x: 0, y: 22, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
    }
}
