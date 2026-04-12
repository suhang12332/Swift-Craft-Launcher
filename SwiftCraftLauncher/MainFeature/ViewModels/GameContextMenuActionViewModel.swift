import Foundation

@MainActor
final class GameContextMenuActionViewModel: ObservableObject {
    private let gameStatusManager: GameStatusManager

    init(gameStatusManager: GameStatusManager = .shared) {
        self.gameStatusManager = gameStatusManager
    }

    func toggleGameState(
        isRunning: Bool,
        player: Player?,
        game: GameVersionInfo,
        gameLaunchUseCase: GameLaunchUseCase
    ) {
        Task {
            let userId = player?.id ?? ""
            if isRunning {
                await gameLaunchUseCase.stopGame(player: player, game: game)
            } else {
                gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                defer { gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                await gameLaunchUseCase.launchGame(player: player, game: game)
            }
        }
    }
}
