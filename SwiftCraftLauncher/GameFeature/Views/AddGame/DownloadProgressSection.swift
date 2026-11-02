//
//  DownloadProgressSection.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays download progress for game core files and mod loaders.
import SwiftUI

struct DownloadProgressSection: View {
    var gameInstaller: GameInstaller
    let selectedModLoader: String

    init(
        gameInstaller: GameInstaller,
        selectedModLoader: String = GameLoader.vanilla.displayName,
    ) {
        self.gameInstaller = gameInstaller
        self.selectedModLoader = selectedModLoader
    }

    var body: some View {
        VStack(spacing: 24) {
            gameDownloadProgressView
            modLoaderProgressView
        }
    }

    private var gameDownloadProgressView: some View {
        VStack(spacing: 24) {
            progressSection(
                title: "download.core.title".localized(),
                phase: gameInstaller.progress.core,
            )
            progressSection(
                title: "download.resources.title".localized(),
                phase: gameInstaller.progress.resources,
            )
        }
    }

    @ViewBuilder private var modLoaderProgressView: some View {
        if let title = Self.loaderTitle(for: selectedModLoader) {
            progressSection(
                title: title,
                phase: gameInstaller.progress.loader,
            )
        }
    }

    private func progressSection(
        title: String,
        phase: InstallProgressReporter.PhaseProgress,
        version: String? = nil,
    ) -> some View {
        FormSection {
            DownloadProgressRow(
                title: title,
                progress: phase.progress,
                currentFile: phase.currentFile,
                completed: phase.completed,
                total: phase.total,
                version: version,
            )
        }
    }

    private static func loaderTitle(for loaderType: String) -> String? {
        switch loaderType.lowercased() {
        case GameLoader.fabric.displayName:
            return "fabric.loader.title".localized()
        case GameLoader.quilt.rawValue:
            return "quilt.loader.title".localized()
        case GameLoader.forge.displayName:
            return "forge.loader.title".localized()
        case GameLoader.neoforge.displayName:
            return "neoforge.loader.title".localized()
        default:
            return nil
        }
    }
}
