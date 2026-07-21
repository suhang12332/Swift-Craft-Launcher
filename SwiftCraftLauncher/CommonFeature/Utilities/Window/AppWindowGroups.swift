//
//  AppWindowGroups.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Defines the auxiliary window groups for the application.
extension SwiftCraftLauncherApp {
    @SceneBuilder
    func auxiliaryWindowGroup() -> some Scene {
        WindowGroup(for: AuxiliaryWindowID.self) { $windowID in
            if let windowID {
                AuxiliaryWindowScene(
                    windowID: windowID,
                    playerListViewModel: playerListViewModel,
                    gameRepository: gameRepository,
                )
                .environmentObject(container)
            }
        }
    }
}

private struct AuxiliaryWindowScene: View {
    @EnvironmentObject private var container: DIContainer

    let windowID: AuxiliaryWindowID
    @ObservedObject var playerListViewModel: PlayerListViewModel
    @ObservedObject var gameRepository: GameRepository

    var body: some View {
        Group {
            switch windowID {
            case .contributors:
                AboutView(showingAcknowledgements: false)
            case .acknowledgements:
                AboutView(showingAcknowledgements: true)
            case .aiChat:
                AIChatWindowContent()
                    .environmentObject(playerListViewModel)
                    .environmentObject(gameRepository)
            case .javaDownload:
                JavaDownloadWindowContent()
            case .skinPreview:
                SkinPreviewWindowContent()
            }
        }
        .preferredColorScheme(container.ui.themeManager.preferredColorScheme)
        .frame(
            minWidth: windowID.defaultSize.width,
            idealWidth: windowID.defaultSize.width,
            minHeight: windowID.defaultSize.height,
            idealHeight: windowID.defaultSize.height,
        )
        .windowStyleConfig(for: windowID)
        .windowCleanup(for: windowID, windowDataStore: container.ui.windowDataStore)
    }
}

private struct JavaDownloadWindowContent: View {
    @EnvironmentObject private var container: DIContainer

    var body: some View {
        JavaDownloadProgressWindow(downloadState: container.system.javaDownloadManager.downloadState)
    }
}

private struct AIChatWindowContent: View {
    @EnvironmentObject private var container: DIContainer

    var body: some View {
        Group {
            if let chatState = container.ui.windowDataStore.aiChatState {
                AIChatWindowView(chatState: chatState)
            }
        }
    }
}

private struct SkinPreviewWindowContent: View {
    @EnvironmentObject private var container: DIContainer

    var body: some View {
        Group {
            if let data = container.ui.windowDataStore.skinPreviewData {
                SkinPreviewWindowView(
                    skinImage: data.skinImage,
                    skinPath: data.skinPath,
                    capeImage: data.capeImage,
                    playerModel: data.playerModel,
                )
            }
        }
    }
}
