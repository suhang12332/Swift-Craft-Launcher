//
//  AppWindowGroups.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
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
                    onDismiss: { $windowID.wrappedValue = nil },
                    gameRepository: gameRepository,
                )
                .environment(container)
            }
        }
    }
}

private struct AuxiliaryWindowScene: View {
    @Environment(DIContainer.self)
    private var container

    let windowID: AuxiliaryWindowID
    var onDismiss: () -> Void
    var gameRepository: GameRepository

    var body: some View {
        Group {
            switch windowID {
            case .contributors:
                AboutView(showingAcknowledgements: false)
            case .acknowledgements:
                AboutView(showingAcknowledgements: true)
            case .javaDownload:
                JavaDownloadWindowContent()
            case .skinPreview:
                SkinPreviewWindowContent()
            case .failedResources:
                ModPackFailedResourcesWindowContent()
                    .environment(gameRepository)
            case .modDependencyGraph:
                ModDependencyGraphWindowContent()
            }
        }
        .navigationTitle(windowID.localizedTitle)
        .preferredColorScheme(container.ui.themeManager.preferredColorScheme)
        .frame(
            minWidth: windowID.defaultSize.width,
            idealWidth: windowID.defaultSize.width,
            minHeight: windowID.defaultSize.height,
            idealHeight: windowID.defaultSize.height,
        )
        .background(
            WindowAccessor { window in
                WindowStyleHelper.configureAuxiliaryWindow(window, for: windowID)
            },
        )
        .onAppear {
            container.ui.windowManager.registerDismissAction(onDismiss, for: windowID)
        }
        .onDisappear {
            container.ui.windowManager.unregisterDismissAction(for: windowID)
            container.ui.windowManager.clearPayload(for: windowID)
        }
    }
}

private struct JavaDownloadWindowContent: View {
    @Environment(DIContainer.self)
    private var container

    var body: some View {
        JavaDownloadProgressWindow(downloadState: container.system.javaDownloadManager.downloadState)
    }
}

private struct SkinPreviewWindowContent: View {
    @Environment(DIContainer.self)
    private var container

    var body: some View {
        if let data = container.ui.windowManager.readPayload(for: .skinPreview, as: SkinPreviewData.self) {
            SkinPreviewWindowView(data: data)
        }
    }
}
