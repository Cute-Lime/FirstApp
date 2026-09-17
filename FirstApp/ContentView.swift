import SpriteKit
import SwiftUI

struct ContentView: View {
    private enum Screen {
        case home
        case battle
    }

    @State private var screen: Screen = .home
    @State private var gameState = GameState()
    @State private var battleScene: BattleScene?
    @State private var roundID = UUID()

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(startGame: startGame)
            case .battle:
                BattleView(
                    gameState: gameState,
                    scene: battleScene,
                    roundID: roundID,
                    summon: summon,
                    togglePause: togglePause,
                    restart: startGame,
                    returnHome: returnHome
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startGame() {
        battleScene?.tearDown()
        gameState.reset()
        battleScene = BattleScene(size: CGSize(width: 1_280, height: 720), gameState: gameState)
        roundID = UUID()
        screen = .battle
        AudioManager.shared.play(.buttonTap)
        AudioManager.shared.startBattleMusic()
    }

    private func summon(_ type: UnitType) {
        battleScene?.summonPlayer(type)
    }

    private func togglePause() {
        gameState.isPaused.toggle()
        if gameState.isPaused {
            AudioManager.shared.pauseBattleMusic()
        } else {
            AudioManager.shared.resumeBattleMusic()
        }
    }

    private func returnHome() {
        battleScene?.tearDown()
        battleScene = nil
        AudioManager.shared.stopBattleMusic()
        screen = .home
    }
}

private struct HomeView: View {
    let startGame: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.17, blue: 0.29), Color(red: 0.18, green: 0.43, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                    .font(.system(size: 76))
                    .foregroundStyle(.yellow, .white)
                    .symbolEffect(.pulse.byLayer, options: .repeating)

                VStack(spacing: 8) {
                    Text("Tower Defence")
                        .font(GameFont.title(46))
                        .multilineTextAlignment(.center)
                    Text("騎士大戰魔物")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.yellow)
                }

                Text("召喚勇士、守住城堡，擊敗魔物軍團！")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))

                Button(action: startGame) {
                    Label("開始遊戲", systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(minWidth: 210)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityHint("開始一場新的塔防戰鬥")

                Spacer()
            }
            .padding()
        }
    }
}

private struct BattleView: View {
    let gameState: GameState
    let scene: BattleScene?
    let roundID: UUID
    let summon: (UnitType) -> Void
    let togglePause: () -> Void
    let restart: () -> Void
    let returnHome: () -> Void

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
                    .id(roundID)
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                BattleHeader(
                    playerHealth: gameState.playerCastleHealth,
                    enemyHealth: gameState.enemyCastleHealth,
                    money: gameState.playerMoney,
                    isPaused: gameState.isPaused,
                    togglePause: togglePause
                )

                Spacer()

                SummonBar(
                    availableMoney: gameState.playerMoney,
                    isPaused: gameState.isPaused,
                    isFinished: gameState.isFinished,
                    summon: summon
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 4)

            if gameState.isPaused && !gameState.isFinished {
                PauseOverlay(resume: { gameState.isPaused = false }, returnHome: returnHome)
            }

            if let result = gameState.result {
                ResultOverlay(result: result, restart: restart, returnHome: returnHome)
            }
        }
    }
}

private struct BattleHeader: View {
    let playerHealth: CGFloat
    let enemyHealth: CGFloat
    let money: Int
    let isPaused: Bool
    let togglePause: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            CastleHealthView(title: "我方城堡", health: playerHealth, tint: .blue)
            MoneyBadge(money: money)
            CastleHealthView(title: "魔物城堡", health: enemyHealth, tint: .red)

            Button(action: togglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.55))
            .accessibilityLabel(isPaused ? "繼續遊戲" : "暫停遊戲")
        }
    }
}

private struct CastleHealthView: View {
    let title: String
    let health: CGFloat
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
            ProgressView(value: health, total: 1_500)
                .tint(tint)
                .frame(minWidth: 120)
            Text("\(Int(health)) / 1500")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(9)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MoneyBadge: View {
    let money: Int

    var body: some View {
        Label("\(money)", systemImage: "centsign.circle.fill")
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityLabel("金錢 \(money)")
    }
}

private struct SummonBar: View {
    let availableMoney: Int
    let isPaused: Bool
    let isFinished: Bool
    let summon: (UnitType) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(UnitType.allCases) { type in
                Button {
                    summon(type)
                } label: {
                    SummonButtonLabel(type: type, isAffordable: availableMoney >= type.cost)
                }
                .buttonStyle(.plain)
                .disabled(availableMoney < type.cost || isPaused || isFinished)
                .accessibilityLabel("召喚\(type.name)，花費 \(type.cost) 金錢")
            }
        }
        .padding(10)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SummonButtonLabel: View {
    let type: UnitType
    let isAffordable: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: type.symbolName)
                .font(.title2)
            Text(type.name)
                .font(.caption.bold())
            Label("\(type.cost)", systemImage: "centsign.circle.fill")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(isAffordable ? .white : .white.opacity(0.38))
        .frame(minWidth: 108)
        .padding(.vertical, 8)
        .background(isAffordable ? Color.blue.opacity(0.7) : Color.gray.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct PauseOverlay: View {
    let resume: () -> Void
    let returnHome: () -> Void

    var body: some View {
        Color.black.opacity(0.56)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 18) {
                    Text("遊戲暫停")
                        .font(.largeTitle.bold())
                    Button("繼續") { resume() }
                        .buttonStyle(.borderedProminent)
                    Button("返回主頁") { returnHome() }
                        .buttonStyle(.bordered)
                }
                .padding(34)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
    }
}

private struct ResultOverlay: View {
    let result: MatchResult
    let restart: () -> Void
    let returnHome: () -> Void

    var body: some View {
        Color.black.opacity(0.62)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: result == .victory ? "crown.fill" : "shield.slash.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(result == .victory ? .yellow : .red)
                    Text(result.title)
                        .font(GameFont.title(48))
                    Text(result.detail)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("再玩一次") { restart() }
                            .buttonStyle(.borderedProminent)
                        Button("返回主頁") { returnHome() }
                            .buttonStyle(.bordered)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(34)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .contain)
            }
    }
}

#Preview {
    ContentView()
}
