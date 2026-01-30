import Foundation

/// 游戏启动/停止用例
/// 解耦 UI 与 Run 模块：View 只依赖本 UseCase，不直接依赖 MinecraftLaunchCommand
final class GameLaunchUseCase: ObservableObject {

    /// 启动游戏
    /// - Parameters:
    ///   - player: 当前玩家（可为 nil，使用默认认证参数）
    ///   - game: 要启动的游戏
    func launchGame(player: Player?, game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.launchGame()
    }

    /// 停止游戏
    /// - Parameter game: 要停止的游戏
    func stopGame(game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: nil, game: game)
        await command.stopGame()
    }
}
