import SwiftUI

// MARK: - 存档信息主视图
struct SaveInfoView: View {
    let gameName: String
    @StateObject private var manager: SaveInfoManager
    
    init(gameName: String) {
        self.gameName = gameName
        _manager = StateObject(wrappedValue: SaveInfoManager(gameName: gameName))
    }
    
    var body: some View {
        VStack {
            // 世界信息区域
            if !manager.worlds.isEmpty || manager.isLoading {
                WorldInfoSectionView(
                    worlds: manager.worlds,
                    isLoading: manager.isLoading,
                    gameName: gameName
                )
            }
            
            // 截图信息区域
            if !manager.screenshots.isEmpty || manager.isLoading {
                ScreenshotSectionView(
                    screenshots: manager.screenshots,
                    isLoading: manager.isLoading,
                    gameName: gameName
                )
            }
            
            // 服务器地址区域（始终显示，即使没有检测到服务器）
            ServerAddressSectionView(
                servers: manager.servers,
                isLoading: manager.isLoading,
                gameName: gameName,
                onRefresh: {
                    Task {
                        await manager.loadData()
                    }
                }
            )
            
            // Litematica 投影文件区域
            if !manager.litematicaFiles.isEmpty || manager.isLoading {
                LitematicaSectionView(
                    litematicaFiles: manager.litematicaFiles,
                    isLoading: manager.isLoading,
                    gameName: gameName
                )
            }
            
            // 日志信息区域
            if !manager.logs.isEmpty || manager.isLoading {
                LogSectionView(
                    logs: manager.logs,
                    isLoading: manager.isLoading
                )
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

