//
//  DownloadProgressView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays download and installation progress for game core files, mod loader, and modpack.
struct DownloadProgressView: View {
    var gameInstaller: GameInstaller
    var modPackInstallState: ModPackInstallState
    let lastParsedIndexInfo: ModrinthIndexInfo?

    var body: some View {
        VStack(spacing: 24) {
            gameDownloadProgress
            modLoaderDownloadProgress
            modPackInstallProgress
        }
    }

    @ViewBuilder private var gameDownloadProgress: some View {
        progressRow(
            title: "download.core.title".localized(),
            phase: gameInstaller.progress.core,
        )
        progressRow(
            title: "download.resources.title".localized(),
            phase: gameInstaller.progress.resources,
        )
    }

    @ViewBuilder private var modLoaderDownloadProgress: some View {
        if let indexInfo = lastParsedIndexInfo,
           let title = loaderTitle(for: indexInfo.loaderType) {
            progressRow(
                title: title,
                phase: gameInstaller.progress.loader,
                version: indexInfo.loaderVersion,
            )
        }
    }

    @ViewBuilder private var modPackInstallProgress: some View {
        if modPackInstallState.isInstalling {
            if modPackInstallState.overridesTotal > 0 {
                progressRow(
                    title: "modpack.copying_files".localized(),
                    installState: modPackInstallState,
                    type: .overrides,
                )
            }

            progressRow(
                title: "modpack.files.title".localized(),
                installState: modPackInstallState,
                type: .files,
            )

            if modPackInstallState.dependenciesTotal > 0 {
                progressRow(
                    title: "modpack.dependencies.title".localized(),
                    installState: modPackInstallState,
                    type: .dependencies,
                )
            }
        }
    }

    private func progressRow(
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

    private func progressRow(
        title: String,
        installState: ModPackInstallState,
        type: InstallProgressType,
    ) -> some View {
        FormSection {
            DownloadProgressRow(
                title: title,
                progress: {
                    switch type {
                    case .files:
                        return installState.filesProgress
                    case .dependencies:
                        return installState.dependenciesProgress
                    case .overrides:
                        return installState.overridesProgress
                    }
                }(),
                currentFile: {
                    switch type {
                    case .files:
                        return installState.currentFile
                    case .dependencies:
                        return installState.currentDependency
                    case .overrides:
                        return installState.currentOverride
                    }
                }(),
                completed: {
                    switch type {
                    case .files:
                        return installState.filesCompleted
                    case .dependencies:
                        return installState.dependenciesCompleted
                    case .overrides:
                        return installState.overridesCompleted
                    }
                }(),
                total: {
                    switch type {
                    case .files:
                        return installState.filesTotal
                    case .dependencies:
                        return installState.dependenciesTotal
                    case .overrides:
                        return installState.overridesTotal
                    }
                }(),
                version: nil,
            )
        }
    }

    private func loaderTitle(for loaderType: String) -> String? {
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

private enum InstallProgressType {
    case files, dependencies, overrides
}
