import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var gameSetupService: GameSetupUtil
    @ObservedObject var modPackInstallState: ModPackInstallState
    let lastParsedIndexInfo: ModrinthIndexInfo?

    var body: some View {
        VStack(spacing: 24) {
            gameDownloadProgress
            modLoaderDownloadProgress
            modPackInstallProgress
        }
    }

    private var gameDownloadProgress: some View {
        Group {
            progressRow(
                title: "download.core.title".localized(),
                state: gameSetupService.downloadState,
                type: .core
            )
            progressRow(
                title: "download.resources.title".localized(),
                state: gameSetupService.downloadState,
                type: .resources
            )
        }
    }

    private var modLoaderDownloadProgress: some View {
        Group {
            if let indexInfo = lastParsedIndexInfo {
                let loaderType = indexInfo.loaderType.lowercased()
                let title = getLoaderTitle(for: indexInfo.loaderType)

                if loaderType == "fabric" || loaderType == "quilt" {
                    progressRow(
                        title: title,
                        state: gameSetupService.fabricDownloadState,
                        type: .core,
                        version: indexInfo.loaderVersion
                    )
                } else if loaderType == "forge" {
                    progressRow(
                        title: title,
                        state: gameSetupService.forgeDownloadState,
                        type: .core,
                        version: indexInfo.loaderVersion
                    )
                } else if loaderType == "neoforge" {
                    progressRow(
                        title: title,
                        state: gameSetupService.neoForgeDownloadState,
                        type: .core,
                        version: indexInfo.loaderVersion
                    )
                }
            }
        }
    }

    private var modPackInstallProgress: some View {
        Group {
            if modPackInstallState.isInstalling {
                progressRow(
                    title: "modpack.files.title".localized(),
                    installState: modPackInstallState,
                    type: .files
                )

                if modPackInstallState.dependenciesTotal > 0 {
                    progressRow(
                        title: "modpack.dependencies.title".localized(),
                        installState: modPackInstallState,
                        type: .dependencies
                    )
                }
            }
        }
    }

    private func progressRow(
        title: String,
        state: DownloadState,
        type: ProgressType,
        version: String? = nil
    ) -> some View {
        FormSection {
            ProgressRowWrapper(
                title: title,
                state: state,
                type: type,
                version: version
            )
        }
    }

    private func progressRow(
        title: String,
        installState: ModPackInstallState,
        type: InstallProgressType
    ) -> some View {
        FormSection {
            DownloadProgressRow(
                title: title,
                progress: type == .files
                    ? installState.filesProgress
                    : installState.dependenciesProgress,
                currentFile: type == .files
                    ? installState.currentFile : installState.currentDependency,
                completed: type == .files
                    ? installState.filesCompleted
                    : installState.dependenciesCompleted,
                total: type == .files
                    ? installState.filesTotal : installState.dependenciesTotal,
                version: nil
            )
        }
    }

    private func getLoaderTitle(for loaderType: String) -> String {
        switch loaderType.lowercased() {
        case "fabric":
            return "fabric.loader.title".localized()
        case "quilt":
            return "quilt.loader.title".localized()
        case "forge":
            return "forge.loader.title".localized()
        case "neoforge":
            return "neoforge.loader.title".localized()
        default:
            return ""
        }
    }
}

// MARK: - Supporting Types
private enum ProgressType {
    case core, resources
}

private enum InstallProgressType {
    case files, dependencies
}

// MARK: - Progress Row Wrapper
private struct ProgressRowWrapper: View {
    let title: String
    @ObservedObject var state: DownloadState
    let type: ProgressType
    let version: String?

    var body: some View {
        DownloadProgressRow(
            title: title,
            progress: type == .core
                ? state.coreProgress : state.resourcesProgress,
            currentFile: type == .core
                ? state.currentCoreFile : state.currentResourceFile,
            completed: type == .core
                ? state.coreCompletedFiles : state.resourcesCompletedFiles,
            total: type == .core
                ? state.coreTotalFiles : state.resourcesTotalFiles,
            version: version
        )
    }
}
