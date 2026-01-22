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
        .windowStyle(.titleBar)
        .defaultSize(width: 280, height: 600)
        .windowResizability(.contentSize)

        // 致谢窗口
        Window("about.acknowledgements".localized(), id: WindowID.acknowledgements.rawValue) {
            AboutView(showingAcknowledgements: true)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .acknowledgements)
                .windowCleanup(for: .acknowledgements)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 280, height: 600)
        .windowResizability(.contentSize)

        // AI 聊天窗口
        Window("ai.assistant.title".localized(), id: WindowID.aiChat.rawValue) {
            Group {
                if let chatState = WindowDataStore.shared.aiChatState {
                    AIChatWindowView(chatState: chatState)
                        .environmentObject(playerListViewModel)
                        .environmentObject(gameRepository)
                        .environmentObject(generalSettingsManager)
                        .preferredColorScheme(generalSettingsManager.currentColorScheme)
                } else {
                    EmptyView()
                }
            }
            .windowStyleConfig(for: .aiChat)
            .windowCleanup(for: .aiChat)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 500, height: 600)
        .windowResizability(.contentSize)

        // 创建房间窗口
        Window("easytier.create.room.window.title".localized(), id: WindowID.createRoom.rawValue) {
            CreateRoomWindowView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .createRoom)
                .windowCleanup(for: .createRoom)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 440, height: 200)
        .windowResizability(.contentSize)

        // 加入房间窗口
        Window("easytier.join.room.window.title".localized(), id: WindowID.joinRoom.rawValue) {
            JoinRoomWindowView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .joinRoom)
                .windowCleanup(for: .joinRoom)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 440, height: 200)
        .windowResizability(.contentSize)

        // 对等节点列表窗口
        Window("menubar.room.member_list".localized(), id: WindowID.peerList.rawValue) {
            PeerListView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .windowStyleConfig(for: .peerList)
                .windowCleanup(for: .peerList)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 500)
        .windowResizability(.contentSize)

        // Java 下载窗口
        Window("global_resource.download".localized(), id: WindowID.javaDownload.rawValue) {
            JavaDownloadProgressWindow(downloadState: JavaDownloadManager.shared.downloadState)
                .windowStyleConfig(for: .javaDownload)
                .windowCleanup(for: .javaDownload)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 400, height: 100)
        .windowResizability(.contentSize)

        // EasyTier 下载窗口
        Window("global_resource.download".localized(), id: WindowID.easyTierDownload.rawValue) {
            EasyTierDownloadProgressWindow(downloadState: EasyTierDownloadManager.shared.downloadState)
                .windowStyleConfig(for: .easyTierDownload)
                .windowCleanup(for: .easyTierDownload)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 400, height: 100)
        .windowResizability(.contentSize)

        // 皮肤预览窗口
        Window("skin.preview".localized(), id: WindowID.skinPreview.rawValue) {
            Group {
                if let data = WindowDataStore.shared.skinPreviewData {
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
            .windowStyleConfig(for: .skinPreview)
            .windowCleanup(for: .skinPreview)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
    }
}
