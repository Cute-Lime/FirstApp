import SpriteKit

final class BattleUnitNode: SKNode {
    let id = UUID()
    let type: UnitType
    let faction: Faction
    var hitPoints: CGFloat
    var attackCooldown: TimeInterval = 0
    var isDying = false

    private let healthFill: SKShapeNode
    private let body: SKShapeNode

    init(type: UnitType, faction: Faction) {
        self.type = type
        self.faction = faction
        hitPoints = type.hitPoints

        let bodyColor: SKColor
        switch (faction, type) {
        case (.player, .knight): bodyColor = .systemBlue
        case (.player, .archer): bodyColor = .systemTeal
        case (.player, .guardian): bodyColor = .systemIndigo
        case (.enemy, .knight): bodyColor = .systemRed
        case (.enemy, .archer): bodyColor = .systemOrange
        case (.enemy, .guardian): bodyColor = .systemPurple
        }

        body = SKShapeNode(circleOfRadius: 23)
        healthFill = SKShapeNode(rectOf: CGSize(width: 40, height: 5), cornerRadius: 2.5)
        super.init()

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 46, height: 11))
        shadow.fillColor = .black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position.y = -23
        addChild(shadow)

        body.fillColor = bodyColor
        body.strokeColor = .white.withAlphaComponent(0.75)
        body.lineWidth = 2
        addChild(body)

        let emblem = SKLabelNode(text: type == .archer ? "✦" : type == .guardian ? "◆" : "⚔")
        emblem.fontName = "AvenirNext-Bold"
        emblem.fontSize = 21
        emblem.verticalAlignmentMode = .center
        emblem.fontColor = .white
        body.addChild(emblem)

        let healthBackground = SKShapeNode(rectOf: CGSize(width: 44, height: 8), cornerRadius: 4)
        healthBackground.fillColor = .black.withAlphaComponent(0.55)
        healthBackground.strokeColor = .clear
        healthBackground.position.y = 35
        addChild(healthBackground)

        healthFill.fillColor = .systemGreen
        healthFill.strokeColor = .clear
        healthFill.position.y = 35
        addChild(healthFill)

        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 4, duration: 0.55),
            .moveBy(x: 0, y: -4, duration: 0.55)
        ])
        run(.repeatForever(bob), withKey: "idle")
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
            removeAction(forKey: "idle")
            let disappear = SKAction.group([
                .fadeOut(withDuration: 0.22),
                .scale(to: 0.15, duration: 0.22)
            ])
            run(.sequence([disappear, .removeFromParent()]))
        }
    }

    func playAttack() {
        let pulse = SKAction.sequence([
            .scale(to: 1.16, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ])
        run(pulse, withKey: "attack")
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

    private let playerCastleX: CGFloat = 88
    private let enemyCastleInset: CGFloat = 88
    private let laneY: CGFloat = 330

    init(size: CGSize, gameState: GameState) {
        self.gameState = gameState
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = SKColor(red: 0.10, green: 0.25, blue: 0.30, alpha: 1)
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
            enemySpawnCountdown = Double.random(in: 2.5...4.0)
        }

        updateUnits(delta: delta)
    }

    private func buildBattlefield() {
        let sky = SKShapeNode(rectOf: size)
        sky.fillColor = SKColor(red: 0.20, green: 0.47, blue: 0.62, alpha: 1)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -10
        addChild(sky)

        let hills = SKShapeNode(rectOf: CGSize(width: size.width, height: 170))
        hills.fillColor = SKColor(red: 0.20, green: 0.47, blue: 0.27, alpha: 1)
        hills.strokeColor = .clear
        hills.position = CGPoint(x: size.width / 2, y: 120)
        hills.zPosition = -9
        addChild(hills)

        let lane = SKShapeNode(rectOf: CGSize(width: size.width, height: 108), cornerRadius: 54)
        lane.fillColor = SKColor(red: 0.72, green: 0.61, blue: 0.40, alpha: 1)
        lane.strokeColor = .white.withAlphaComponent(0.25)
        lane.lineWidth = 3
        lane.position = CGPoint(x: size.width / 2, y: laneY)
        lane.zPosition = -8
        addChild(lane)

        addCastle(faction: .player, x: playerCastleX)
        addCastle(faction: .enemy, x: size.width - enemyCastleInset)
    }

    private func addCastle(faction: Faction, x: CGFloat) {
        let castle = SKShapeNode(rectOf: CGSize(width: 80, height: 140), cornerRadius: 14)
        castle.fillColor = faction == .player ? .systemBlue : .systemRed
        castle.strokeColor = .white.withAlphaComponent(0.8)
        castle.lineWidth = 4
        castle.position = CGPoint(x: x, y: laneY + 55)
        addChild(castle)

        let crown = SKLabelNode(text: faction == .player ? "♜" : "♛")
        crown.fontName = "AvenirNext-Bold"
        crown.fontSize = 46
        crown.verticalAlignmentMode = .center
        crown.position = CGPoint(x: x, y: laneY + 58)
        crown.zPosition = 1
        addChild(crown)
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
        let playerUnits = unitNodes(for: .player)
        let enemyUnits = unitNodes(for: .enemy)
        let preferred: UnitType

        if playerUnits.count > enemyUnits.count + 1 {
            preferred = .guardian
        } else {
            preferred = Bool.random() ? .knight : .archer
        }

        let choices = [preferred, UnitType.knight, UnitType.guardian, UnitType.archer]
        guard let chosen = choices.first(where: { gameState.spend(for: $0, faction: .enemy) }) else {
            return
        }
        addUnit(chosen, faction: .enemy)
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
        unit.xScale = unit.faction == .player ? walkingScale : -walkingScale
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
