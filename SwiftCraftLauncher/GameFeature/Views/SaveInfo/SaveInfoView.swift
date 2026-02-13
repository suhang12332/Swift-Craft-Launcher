import SwiftUI

// MARK: - 存档信息主视图
struct SaveInfoView: View {
    let gameId: String
    let gameName: String
    @StateObject private var manager: SaveInfoManager

    init(gameId: String, gameName: String) {
        self.gameId = gameId
        self.gameName = gameName
        _manager = StateObject(wrappedValue: SaveInfoManager(gameName: gameName))
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
            if manager.hasServersType {
                ServerAddressSectionView(
                    servers: manager.servers,
                    isLoading: manager.isLoadingServers,
                    gameName: gameName
                ) {
                    Task {
                        await manager.loadData()
                    }
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

            // 当没有任何可用信息类型时显示空状态
            if !manager.isLoading && !manager.hasWorldsType && !manager.hasScreenshotsType && !manager.hasServersType && !manager.hasLitematicaType && !manager.hasLogsType {
                Text("saveinfo.no_available_info".localized())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
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
        .onDisappear {
            manager.clearCache()
        }
    }
}
