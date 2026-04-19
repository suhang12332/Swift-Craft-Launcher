import SwiftUI

/// 游戏右键菜单组件，优化内存使用
/// 使用独立的视图组件和缓存的状态，减少内存占用
struct GameContextMenu: View {
    let game: GameVersionInfo
    let onDelete: () -> Void
    let onOpenSettings: () -> Void
    let onExport: () -> Void
    let showsShowInLauncher: Bool

    init(
        game: GameVersionInfo,
        onDelete: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onExport: @escaping () -> Void,
        showsShowInLauncher: Bool = false
    ) {
        self.game = game
        self.onDelete = onDelete
        self.onOpenSettings = onOpenSettings
        self.onExport = onExport
        self.showsShowInLauncher = showsShowInLauncher
    }

    @ObservedObject private var gameStatusManager = GameStatusManager.shared
    @ObservedObject private var gameActionManager = GameActionManager.shared
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase
    @StateObject private var actionViewModel = GameContextMenuActionViewModel()

    /// 使用缓存的游戏状态，避免每次渲染都检查进程
    /// key 为 processKey(gameId, userId)，当前选中的玩家决定 userId
    private var isRunning: Bool {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let key = GameProcessManager.processKey(gameId: game.id, userId: userId)
        return gameStatusManager.allGameStates[key] ?? false
    }

    var body: some View {
        Button(action: {
            toggleGameState()
        }, label: {
            Label(
                isRunning ? "stop.fill".localized() : "play.fill".localized(),
                systemImage: isRunning ? "stop.fill" : "play.fill"
            )
        })

        Button(action: {
            gameActionManager.showInFinder(game: game)
        }, label: {
            Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
        })

        if showsShowInLauncher {
            Button(action: {
                SelectedGameManager.shared.setSelectedGame(game.id)
                WindowManager.shared.showAndActivateWindow(id: .main)
            }, label: {
                Label("sidebar.context_menu.show_in_launcher".localized(), systemImage: "macwindow")
            })
        }

        Button(action: {
            selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
            onOpenSettings()
        }, label: {
            Label("settings.game.advanced".localized(), systemImage: "gearshape")
        })

        Divider()

        if game.modLoader != GameLoader.vanilla.displayName {
            Button(action: {
                if showsShowInLauncher {
                    WindowManager.shared.showAndActivateWindow(id: .main)
                }
                onExport()
            }, label: {
                Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
            })
        }

        Button(action: {
            if showsShowInLauncher {
                WindowManager.shared.showAndActivateWindow(id: .main)
            }
            onDelete()
        }, label: {
            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
        })
    }

    /// 启动或停止游戏
    private func toggleGameState() {
        actionViewModel.toggleGameState(
            isRunning: isRunning,
            player: playerListViewModel.currentPlayer,
            game: game,
            gameLaunchUseCase: gameLaunchUseCase
        )
    }
}
