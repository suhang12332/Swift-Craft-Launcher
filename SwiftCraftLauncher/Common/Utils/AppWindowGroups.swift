//
//  AppWindowGroups.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI

/// 应用窗口组定义
extension SwiftCraftLauncherApp {
    /// 创建所有应用窗口组
    @SceneBuilder
    func appWindowGroups() -> some Scene {
        // 贡献者窗口
        Window("about.contributors".localized(), id: WindowID.contributors.rawValue) {
            AboutView(showingAcknowledgements: false)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .contributors)
                .windowCleanup(for: .contributors)
        }
        .defaultSize(width: 280, height: 600)

        // 致谢窗口
        Window("about.acknowledgements".localized(), id: WindowID.acknowledgements.rawValue) {
            AboutView(showingAcknowledgements: true)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .acknowledgements)
                .windowCleanup(for: .acknowledgements)
        }
        .defaultSize(width: 280, height: 600)

        // AI 聊天窗口
        Window("ai.assistant.title".localized(), id: WindowID.aiChat.rawValue) {
            AIChatWindowContent()
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(generalSettingsManager)
                .windowStyleConfig(for: .aiChat)
                .windowCleanup(for: .aiChat)
        }
        .defaultSize(width: 500, height: 600)

//        // 创建房间窗口
//        Window("easytier.create.room.window.title".localized(), id: WindowID.createRoom.rawValue) {
//            CreateRoomWindowView()
//                .environmentObject(generalSettingsManager)
//                .preferredColorScheme(generalSettingsManager.currentColorScheme)
//                .windowStyleConfig(for: .createRoom)
//                .windowCleanup(for: .createRoom)
//        }
//        .defaultSize(width: 440, height: 200)
//
//        // 加入房间窗口
//        Window("easytier.join.room.window.title".localized(), id: WindowID.joinRoom.rawValue) {
//            JoinRoomWindowView()
//                .environmentObject(generalSettingsManager)
//                .preferredColorScheme(generalSettingsManager.currentColorScheme)
//                .windowStyleConfig(for: .joinRoom)
//                .windowCleanup(for: .joinRoom)
//        }
//        .defaultSize(width: 440, height: 200)

//        // 对等节点列表窗口
//        Window("menubar.room.member_list".localized(), id: WindowID.peerList.rawValue) {
//            PeerListView()
//                .environmentObject(generalSettingsManager)
//                .preferredColorScheme(generalSettingsManager.currentColorScheme)
//                .windowStyleConfig(for: .peerList)
//                .windowCleanup(for: .peerList)
//        }
//        .defaultSize(width: 1200, height: 500)

        // Java 下载窗口
        Window("global_resource.download".localized(), id: WindowID.javaDownload.rawValue) {
            JavaDownloadProgressWindow(downloadState: JavaDownloadManager.shared.downloadState)
                .windowStyleConfig(for: .javaDownload)
                .windowCleanup(for: .javaDownload)
        }
        .defaultSize(width: 400, height: 100)

//        // EasyTier 下载窗口
//        Window("global_resource.download".localized(), id: WindowID.easyTierDownload.rawValue) {
//            EasyTierDownloadProgressWindow(downloadState: EasyTierDownloadManager.shared.downloadState)
//                .windowStyleConfig(for: .easyTierDownload)
//                .windowCleanup(for: .easyTierDownload)
//        }
//        .windowStyle(.titleBar)
//        .defaultSize(width: 400, height: 100)
//        .windowResizability(.contentSize)

        // 皮肤预览窗口
        Window("skin.preview".localized(), id: WindowID.skinPreview.rawValue) {
            SkinPreviewWindowContent()
                .windowStyleConfig(for: .skinPreview)
                .windowCleanup(for: .skinPreview)
        }
        .defaultSize(width: 1200, height: 800)
    }
}

// MARK: - 窗口内容视图

/// AI 聊天窗口内容视图（用于观察 WindowDataStore 变化）
private struct AIChatWindowContent: View {
    @ObservedObject private var windowDataStore = WindowDataStore.shared
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var generalSettingsManager: GeneralSettingsManager

    var body: some View {
        Group {
            if let chatState = windowDataStore.aiChatState {
                AIChatWindowView(chatState: chatState)
                    .preferredColorScheme(generalSettingsManager.currentColorScheme)
            } else {
                EmptyView()
            }
        }
    }
}

/// 皮肤预览窗口内容视图（用于观察 WindowDataStore 变化）
private struct SkinPreviewWindowContent: View {
    @ObservedObject private var windowDataStore = WindowDataStore.shared

    var body: some View {
        Group {
            if let data = windowDataStore.skinPreviewData {
                SkinPreviewWindowView(
                    skinImage: data.skinImage,
                    skinPath: data.skinPath,
                    capeImage: data.capeImage,
                    playerModel: data.playerModel
                )
            } else {
                EmptyView()
            }
        }
    }
}
