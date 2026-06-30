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
                    generalSettingsManager: generalSettingsManager,
                    themeManager: themeManager,
                    playerListViewModel: playerListViewModel,
                    gameRepository: gameRepository,
                )
            }
        }
    }
}

private struct AuxiliaryWindowScene: View {
    let windowID: AuxiliaryWindowID
    @ObservedObject var generalSettingsManager: GeneralSettingsManager
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var playerListViewModel: PlayerListViewModel
    @ObservedObject var gameRepository: GameRepository

    var body: some View {
        Group {
            switch windowID {
            case .contributors:
                AboutView(showingAcknowledgements: false)
                    .environmentObject(generalSettingsManager)
            case .acknowledgements:
                AboutView(showingAcknowledgements: true)
                    .environmentObject(generalSettingsManager)
            case .aiChat:
                AIChatWindowContent()
                    .environmentObject(playerListViewModel)
                    .environmentObject(gameRepository)
                    .environmentObject(generalSettingsManager)
            case .javaDownload:
                JavaDownloadWindowContent()
            case .skinPreview:
                SkinPreviewWindowContent()
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .frame(
            minWidth: windowID.defaultSize.width,
            idealWidth: windowID.defaultSize.width,
            minHeight: windowID.defaultSize.height,
            idealHeight: windowID.defaultSize.height,
        )
        .windowStyleConfig(for: windowID)
        .windowCleanup(for: windowID)
    }
}

private struct JavaDownloadWindowContent: View {
    @ObservedObject private var javaDownloadManager: JavaDownloadManager

    init(javaDownloadManager: JavaDownloadManager = AppServices.javaDownloadManager) {
        _javaDownloadManager = ObservedObject(wrappedValue: javaDownloadManager)
    }

    var body: some View {
        JavaDownloadProgressWindow(downloadState: javaDownloadManager.downloadState)
    }
}

private struct AIChatWindowContent: View {
    @ObservedObject private var windowDataStore: WindowDataStore
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var generalSettingsManager: GeneralSettingsManager

    init(windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        _windowDataStore = ObservedObject(wrappedValue: windowDataStore)
    }

    var body: some View {
        Group {
            if let chatState = windowDataStore.aiChatState {
                AIChatWindowView(chatState: chatState)
            }
        }
    }
}

private struct SkinPreviewWindowContent: View {
    @ObservedObject private var windowDataStore: WindowDataStore

    init(windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        _windowDataStore = ObservedObject(wrappedValue: windowDataStore)
    }

    var body: some View {
        Group {
            if let data = windowDataStore.skinPreviewData {
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
