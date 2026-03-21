import SwiftUI

// MARK: - 存档信息主视图
struct SaveInfoView: View {
    let gameId: String
    let gameName: String
    @StateObject private var manager: SaveInfoManager
    @ObservedObject private var gameStatusManager = GameStatusManager.shared

    @EnvironmentObject private var playerListViewModel: PlayerListViewModel

    init(gameId: String, gameName: String) {
        self.gameId = gameId
        self.gameName = gameName
        _manager = StateObject(wrappedValue: SaveInfoManager(gameName: gameName))
    }
    /// 当前游戏的运行状态
    private var currentGameRunningState: Bool {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        if let isRunning = gameStatusManager.allGameStates[key] {
            return isRunning
        } else {
            return false
        }
    }

    var body: some View {
        VStack {
            // 世界信息区域（只显示存在的类型）
            if manager.hasWorldsType {
                WorldInfoSectionView(
                    worlds: manager.worlds,
                    isLoading: manager.isLoadingWorlds,
                    gameName: gameName
                )
            }

            // 截图信息区域（只显示存在的类型）
            if manager.hasScreenshotsType {
                ScreenshotSectionView(
                    screenshots: manager.screenshots,
                    isLoading: manager.isLoadingScreenshots,
                    gameName: gameName
                )
            }

            // 服务器地址区域（始终显示，即使没有检测到服务器）
            ServerAddressSectionView(
                servers: manager.servers,
                isLoading: manager.isLoadingServers,
                gameName: gameName
            ) {
                Task {
                    await manager.loadData()
                }
            }

            // Litematica 投影文件区域（只显示存在的类型）
            if manager.hasLitematicaType {
                LitematicaSectionView(
                    litematicaFiles: manager.litematicaFiles,
                    isLoading: manager.isLoadingLitematica,
                    gameName: gameName
                )
            }

            // 日志信息区域（只显示存在的类型）
            if manager.hasLogsType {
                LogSectionView(
                    logs: manager.logs,
                    isLoading: manager.isLoadingLogs
                )
            }
        }
        .onChange(of: gameId) { _, _ in
            Task {
                await manager.loadData()
            }
        }
        .task {
            await manager.loadData()
        }
        .onChange(of: currentGameRunningState) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task {
                    await manager.loadData()
                }
            }
        }
        .onDisappear {
            manager.clearCache()
        }
    }
}
