import SwiftUI
import Foundation

/// 游戏高级设置标签页
/// 显示在设置窗口中，允许用户为选中的游戏配置高级设置
/// 当在主视图中选中游戏时，会自动显示该游戏的设置
/// 如果没有选中游戏，则显示为空
public struct GameAdvancedSettingsView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @State private var error: GlobalError?

    public init() {}

    public var body: some View {

        // 只使用主视图中选中的游戏
        if let gameId = selectedGameManager.selectedGameId,
           let game = gameRepository.getGame(by: gameId) {
            GameAdvancedView(game: game)
//            GeneralSettingsView()
        } else {
            // 没有选中游戏时显示为空
            emptyStateView
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        Form {
            Text("settings.game.advanced.no_selected_game".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}
