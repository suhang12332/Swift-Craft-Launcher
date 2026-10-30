//
//  DownloadProgressSection.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays download progress for game core files, mod loaders, and mod packs.
import SwiftUI

struct DownloadProgressSection: View {
    var gameInstaller: GameInstaller
    var modPackViewModel: ModPackDownloadSheetViewModel?
    let modPackIndexInfo: ModrinthIndexInfo?
    let selectedModLoader: String

    init(
        gameInstaller: GameInstaller,
        selectedModLoader: String = GameLoader.vanilla.displayName,
        modPackViewModel: ModPackDownloadSheetViewModel? = nil,
        modPackIndexInfo: ModrinthIndexInfo? = nil,
    ) {
        self.gameInstaller = gameInstaller
        self.selectedModLoader = selectedModLoader
        self.modPackViewModel = modPackViewModel
        self.modPackIndexInfo = modPackIndexInfo
    }

    var body: some View {
        VStack(spacing: 24) {
            gameDownloadProgressView
            modLoaderProgressView
            if let modPackViewModel {
                ModPackProgressView(modPackViewModel: modPackViewModel)
            }
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
        if let loaderProgressInfo {
            progressSection(
                title: loaderProgressInfo.title,
                phase: gameInstaller.progress.loader,
                version: loaderProgressInfo.version,
            )
        }
    }

    private var loaderProgressInfo: (title: String, version: String?)? {
        if let indexInfo = modPackIndexInfo {
            guard let title = Self.loaderTitle(for: indexInfo.loaderType) else { return nil }
            return (title, indexInfo.loaderVersion)
        }
        guard let title = Self.loaderTitle(for: selectedModLoader) else { return nil }
        return (title, nil)
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

/// Displays download progress for mod pack installation components.
private struct ModPackProgressView: View {
    var modPackViewModel: ModPackDownloadSheetViewModel

    var body: some View {
        if modPackViewModel.modPackInstallState.isInstalling {
            VStack(spacing: 24) {
                if modPackViewModel.modPackInstallState.overridesTotal > 0 {
                    modPackProgressSection(
                        title: "modpack.copying_files".localized(),
                        state: modPackViewModel.modPackInstallState,
                        type: .overrides,
                    )
                }

                modPackProgressSection(
                    title: "modpack.files.title".localized(),
                    state: modPackViewModel.modPackInstallState,
                    type: .files,
                )

                if modPackViewModel.modPackInstallState.dependenciesTotal > 0 {
                    modPackProgressSection(
                        title: "modpack.dependencies.title".localized(),
                        state: modPackViewModel.modPackInstallState,
                        type: .dependencies,
                    )
                }
            }
        }
    }

    private enum ModPackProgressType {
        case files
        case dependencies
        case overrides
    }

    private func modPackProgressSection(
        title: String,
        state: ModPackInstallState,
        type: ModPackProgressType,
    ) -> some View {
        FormSection {
            DownloadProgressRow(
                title: title,
                progress: {
                    switch type {
                    case .files:
                        return state.filesProgress
                    case .dependencies:
                        return state.dependenciesProgress
                    case .overrides:
                        return state.overridesProgress
                    }
                }(),
                currentFile: {
                    switch type {
                    case .files:
                        return state.currentFile
                    case .dependencies:
                        return state.currentDependency
                    case .overrides:
                        return state.currentOverride
                    }
                }(),
                completed: {
                    switch type {
                    case .files:
                        return state.filesCompleted
                    case .dependencies:
                        return state.dependenciesCompleted
                    case .overrides:
                        return state.overridesCompleted
                    }
                }(),
                total: {
                    switch type {
                    case .files:
                        return state.filesTotal
                    case .dependencies:
                        return state.dependenciesTotal
                    case .overrides:
                        return state.overridesTotal
                    }
                }(),
                version: nil,
            )
        }
    }
}
