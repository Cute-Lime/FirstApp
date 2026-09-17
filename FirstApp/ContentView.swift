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
            // Medieval Dark Fortress Background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.22, green: 0.11, blue: 0.09),
                    Color(red: 0.05, green: 0.06, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle Golden Glow Halo
            Circle()
                .fill(Color(red: 0.95, green: 0.70, blue: 0.25).opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .offset(y: -40)

            VStack(spacing: 24) {
                Spacer()

                // Medieval Castle Crest Emblem
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.12, blue: 0.10))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0.95, green: 0.82, blue: 0.45), Color(red: 0.65, green: 0.48, blue: 0.20)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 12)

                    VStack(spacing: -6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(red: 0.98, green: 0.84, blue: 0.38))
                        Image(systemName: "shield.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.75, green: 0.20, blue: 0.15), Color(red: 0.45, green: 0.10, blue: 0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }

                VStack(spacing: 6) {
                    Text("TOWER DEFENCE")
                        .font(GameFont.title(44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.88, blue: 0.55), Color(red: 0.82, green: 0.65, blue: 0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 3)

                    Text("中世紀城堡爭霸戰")
                        .font(GameFont.display(22))
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))

                    Text("領兵築防 • 決戰魔王")
                        .font(GameFont.body(15))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.top, 2)
                }

                Button(action: {
                    AudioManager.shared.play(.buttonTap)
                    startGame()
                }) {
                    HStack(spacing: 10) {
                        Text("🗡️")
                            .font(.title2)
                        Text("開始遠征")
                            .font(GameFont.display(20))
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.70))
                    .frame(minWidth: 220)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.68, green: 0.22, blue: 0.15), Color(red: 0.45, green: 0.12, blue: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.82, blue: 0.45), Color(red: 0.65, green: 0.48, blue: 0.20)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.orange.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
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
                PauseOverlay(
                    resume: {
                        AudioManager.shared.play(.buttonTap)
                        togglePause()
                    },
                    returnHome: {
                        AudioManager.shared.play(.buttonTap)
                        returnHome()
                    }
                )
            }

            if let result = gameState.result {
                ResultOverlay(
                    result: result,
                    restart: {
                        AudioManager.shared.play(.buttonTap)
                        restart()
                    },
                    returnHome: {
                        AudioManager.shared.play(.buttonTap)
                        returnHome()
                    }
                )
            }
        }
    }
}

private struct BattleHeader: View {
    let money: Int
    let isPaused: Bool
    let togglePause: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MoneyBadge(money: money)

            Button(action: {
                AudioManager.shared.play(.buttonTap)
                togglePause()
            }) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.55))
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.18, blue: 0.15), Color(red: 0.12, green: 0.10, blue: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.75, green: 0.60, blue: 0.32), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "繼續遊戲" : "暫停遊戲")
        }
    }
}

private struct MoneyBadge: View {
    let money: Int

    var body: some View {
        Label("\(money)", systemImage: "centsign.circle.fill")
            .font(GameFont.number(20))
            .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.40))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.16, blue: 0.12), Color(red: 0.10, green: 0.08, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.75, green: 0.60, blue: 0.32), lineWidth: 1.5)
            )
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
                    AudioManager.shared.play(.buttonTap)
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
        .background(
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.14, blue: 0.12), Color(red: 0.08, green: 0.07, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.65, green: 0.50, blue: 0.28), lineWidth: 1.5)
        )
    }
}

private struct SummonButtonLabel: View {
    let type: UnitType
    let isAffordable: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(type.iconText)
                .font(.title2)
            Text(type.name)
                .font(GameFont.display(14))
            Label("\(type.cost)", systemImage: "centsign.circle.fill")
                .font(GameFont.number(13))
        }
        .foregroundStyle(isAffordable ? Color(red: 0.98, green: 0.92, blue: 0.75) : Color.white.opacity(0.35))
        .frame(minWidth: 108)
        .padding(.vertical, 8)
        .background(
            isAffordable ?
            LinearGradient(
                colors: [Color(red: 0.22, green: 0.38, blue: 0.62), Color(red: 0.12, green: 0.24, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            ) :
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.20, blue: 0.20), Color(red: 0.12, green: 0.12, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isAffordable ? Color(red: 0.85, green: 0.72, blue: 0.42) : Color.gray.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

private struct PauseOverlay: View {
    let resume: () -> Void
    let returnHome: () -> Void

    var body: some View {
        Color.black.opacity(0.65)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    Text("遊戲暫停")
                        .font(GameFont.title(36))
                        .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.55))

                    Button(action: resume) {
                        Text("繼續戰鬥")
                            .font(GameFont.display(18))
                            .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.70))
                            .frame(minWidth: 160)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.68, green: 0.22, blue: 0.15), Color(red: 0.45, green: 0.12, blue: 0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.85, green: 0.72, blue: 0.42), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: returnHome) {
                        Text("返回主頁")
                            .font(GameFont.display(18))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(minWidth: 160)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(36)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.13, blue: 0.11), Color(red: 0.09, green: 0.07, blue: 0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(red: 0.75, green: 0.60, blue: 0.32), lineWidth: 2))
            }
    }
}

private struct ResultOverlay: View {
    let result: MatchResult
    let restart: () -> Void
    let returnHome: () -> Void

    var body: some View {
        Color.black.opacity(0.70)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 18) {
                    Image(systemName: result == .victory ? "crown.fill" : "shield.slash.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(result == .victory ? Color(red: 0.98, green: 0.84, blue: 0.38) : Color.red)
                    Text(result.title)
                        .font(GameFont.title(46))
                        .foregroundStyle(result == .victory ? Color(red: 0.98, green: 0.88, blue: 0.55) : Color(red: 0.90, green: 0.35, blue: 0.35))
                    Text(result.detail)
                        .font(GameFont.body(16))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 16) {
                        Button(action: restart) {
                            Text("再玩一次")
                                .font(GameFont.display(18))
                                .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.70))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.68, green: 0.22, blue: 0.15), Color(red: 0.45, green: 0.12, blue: 0.08)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.85, green: 0.72, blue: 0.42), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: returnHome) {
                            Text("返回主頁")
                                .font(GameFont.display(18))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(36)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.13, blue: 0.11), Color(red: 0.09, green: 0.07, blue: 0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(red: 0.75, green: 0.60, blue: 0.32), lineWidth: 2))
                .accessibilityElement(children: .contain)
            }
    }
}

#Preview {
    ContentView()
}
