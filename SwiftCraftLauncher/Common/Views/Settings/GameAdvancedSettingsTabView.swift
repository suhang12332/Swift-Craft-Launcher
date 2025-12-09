import SwiftUI
import Foundation

/// 游戏高级设置标签页
/// 显示在设置窗口中，允许用户为选中的游戏配置高级设置
/// 当在主视图中选中游戏时，会自动显示该游戏的设置
/// 如果没有选中游戏，则显示为空
public struct GameAdvancedSettingsTabView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @State private var error: GlobalError?

    public init() {}

    public var body: some View {
        VStack {
            // 只使用主视图中选中的游戏
            if let gameId = selectedGameManager.selectedGameId,
               let game = gameRepository.getGame(by: gameId) {
                GameAdvancedSettingsView(game: game)
            } else {
                // 没有选中游戏时显示为空
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(error != nil)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("settings.game.advanced.no_selected_game".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GameAdvancedSettingsTabView()
        .environmentObject(GameRepository())
}
