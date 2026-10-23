//
//  ResourceInstallViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Shared state and install actions for the resource install sheets.
///
/// The global resource sheet lets the user choose a game; the game install
/// sheet and the failed-resource retry window provide a fixed game. Version
/// selection, dependency loading, downloading, and cancellation are identical.
@MainActor
@Observable
final class ResourceInstallViewModel {
    /// Behaviour that differs between the entry points.
    struct Configuration {
        /// Update mode replaces a single file without loading dependencies.
        let isUpdateMode: Bool
        /// When false the footer only offers a close button.
        let hasCompatibleGames: Bool
        /// Whether a failed install should close the sheet.
        let dismissOnFailure: Bool
        /// Called after a successful install with the downloaded file name and hash.
        let onSuccess: ((String?, String?) -> Void)?

        init(
            isUpdateMode: Bool = false,
            hasCompatibleGames: Bool = true,
            dismissOnFailure: Bool = false,
            onSuccess: ((String?, String?) -> Void)? = nil,
        ) {
            self.isUpdateMode = isUpdateMode
            self.hasCompatibleGames = hasCompatibleGames
            self.dismissOnFailure = dismissOnFailure
            self.onSuccess = onSuccess
        }
    }

    let project: ModrinthProject
    let resourceType: String
    let fixedGame: GameVersionInfo?
    let configuration: Configuration

    var selectedGame: GameVersionInfo?
    var selectedVersion: ModrinthProjectDetailVersion?
    var availableVersions: [ModrinthProjectDetailVersion] = []
    var dependencyState = DependencyState()
    var isDownloadingAll = false
    var isLoadingVersions = false
    var mainVersionId = ""

    private let installTasks = InstallTaskCoordinator()
    private var dependencyTask: Task<Void, Never>?

    init(
        project: ModrinthProject,
        resourceType: String,
        fixedGame: GameVersionInfo?,
        configuration: Configuration = .init(),
    ) {
        self.project = project
        self.resourceType = resourceType
        self.fixedGame = fixedGame
        self.configuration = configuration
        selectedGame = fixedGame
    }

    /// Whether the install replaces an existing file.
    var isUpdateMode: Bool { configuration.isUpdateMode }

    /// Whether the footer should offer an install action.
    var hasCompatibleGames: Bool { configuration.hasCompatibleGames }

    /// The game to install into, whether fixed or picked by the user.
    var resolvedGame: GameVersionInfo? { fixedGame ?? selectedGame }

    /// Whether the install button should show a loading indicator.
    ///
    /// Covers the download itself, the version list refresh after the game
    /// changes, and the dependency lookup that runs after a version is picked.
    var isInstallLoading: Bool {
        isDownloadingAll || isLoadingVersions || dependencyState.isLoading
    }

    func onVersionChanged(_ version: ModrinthProjectDetailVersion?) {
        selectedVersion = version

        guard resourceType == ResourceType.mod.rawValue,
              !isUpdateMode,
              let version,
              let game = resolvedGame else {
            cancelDependencyLoad()
            dependencyState = DependencyState()
            return
        }

        loadDependencies(for: version, game: game)
    }

    private func loadDependencies(for _: ModrinthProjectDetailVersion, game: GameVersionInfo) {
        dependencyTask?.cancel()
        dependencyState.isLoading = true

        let projectId = project.projectId
        dependencyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let state = try await Self.fetchDependencyState(projectId: projectId, game: game)
                guard !Task.isCancelled else { return }
                dependencyState = state
            } catch is CancellationError {
                dependencyState = DependencyState()
            } catch {
                dependencyState = DependencyState()
                handleError(error, context: "Failed to load dependencies")
            }
        }
    }

    private func cancelDependencyLoad() {
        dependencyTask?.cancel()
        dependencyTask = nil
    }

    private static func fetchDependencyState(
        projectId: String,
        game: GameVersionInfo,
    ) async throws -> DependencyState {
        guard !projectId.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_id_empty",
                level: .notification,
                message: "projectId is empty when loading dependencies",
            )
        }

        let missing = await ModrinthDependencyDownloader.getMissingDependenciesWithVersions(
            for: projectId,
            gameInfo: game,
        )

        var versions: [String: [ModrinthProjectDetailVersion]] = [:]
        var selected: [String: ModrinthProjectDetailVersion?] = [:]
        var dependencies: [ModrinthProjectDetail] = []

        for (detail, detailVersions) in missing {
            dependencies.append(detail)
            versions[detail.id] = detailVersions
            selected[detail.id] = detailVersions.first
        }

        return DependencyState(
            dependencies: dependencies,
            versions: versions,
            selected: selected,
            isLoading: false,
        )
    }

    /// Downloads the selected version together with its manually selected dependencies.
    func installModWithDependencies(dismiss: @escaping () -> Void) {
        guard selectedVersion != nil,
              let game = resolvedGame,
              !dependencyState.isLoading else { return }

        let input = ModrinthDependencyDownloader.ManualDownloadInput(
            dependencies: dependencyState.dependencies,
            selectedVersions: dependencyState.selected.compactMapValues { $0?.id },
            dependencyVersions: dependencyState.versions,
            mainProjectId: project.projectId,
            mainProjectVersionId: mainVersionId.isEmpty ? nil : mainVersionId,
            gameInfo: game,
            resourceType: resourceType,
        )
        let projectId = project.projectId

        startInstall(dismiss: dismiss) {
            let success = await ModrinthDependencyDownloader.downloadManualDependenciesAndMain(
                input: input,
                onDependencyDownloadStart: { @Sendable _ in },
                onDependencyDownloadFinish: { @Sendable _, _ in },
            )
            guard success else {
                throw GlobalError.download(
                    i18nKey: "error.download.manual_dependencies_failed",
                    level: .notification,
                    message: "downloadManualDependenciesAndMain returned false for projectId=\(projectId)",
                )
            }
            return (nil, nil)
        }
    }

    /// Downloads only the selected resource, without dependencies.
    func installSingleResource(dismiss: @escaping () -> Void) {
        guard selectedVersion != nil, let game = resolvedGame else { return }

        let projectId = project.projectId
        let resourceType = resourceType

        startInstall(dismiss: dismiss) {
            let (success, fileName, hash) = await ModrinthDependencyDownloader.downloadMainResourceOnly(
                mainProjectId: projectId,
                gameInfo: game,
                query: resourceType,
                filterLoader: true,
            )
            guard success else {
                throw GlobalError.download(
                    i18nKey: "error.download.resource_download_failed",
                    level: .notification,
                    message: "downloadMainResourceOnly returned false for projectId=\(projectId), resourceType=\(resourceType)",
                )
            }
            return (fileName, hash)
        }
    }

    /// Adds a server address resource to the selected game.
    func addServerResource(
        projectDetail: ModrinthProjectDetail?,
        dismiss: @escaping () -> Void,
    ) {
        guard let game = resolvedGame, let projectDetail else { return }

        startInstall(dismiss: dismiss) {
            try await MinecraftJavaServerResourceUtils.addServerToGameIfNeeded(
                game: game,
                detail: projectDetail,
            )
            return (nil, nil)
        }
    }

    /// Cancels an in-flight install without dismissing the sheet.
    func cancelInstall() {
        installTasks.cancel()
        isDownloadingAll = false
    }

    /// Cancels in-flight work and resets all transient state.
    func cleanup() {
        cancelInstall()
        cancelDependencyLoad()
        selectedGame = fixedGame
        selectedVersion = nil
        availableVersions = []
        dependencyState = DependencyState()
        isLoadingVersions = false
        mainVersionId = ""
    }

    private func startInstall(
        dismiss: @escaping () -> Void,
        operation: @escaping @MainActor () async throws -> (fileName: String?, hash: String?),
    ) {
        isDownloadingAll = true

        installTasks.start(
            onFinish: { [weak self] in
                self?.isDownloadingAll = false
            },
            operation: { [weak self] in
                guard let self else { return }
                do {
                    let result = try await operation()
                    configuration.onSuccess?(result.fileName, result.hash)
                    dismiss()
                } catch is CancellationError {
                    return
                } catch {
                    handleError(error, context: "Resource installation failed")
                    if configuration.dismissOnFailure {
                        dismiss()
                    }
                }
            },
        )
    }

    private func handleError(_ error: Error, context: String) {
        let globalError = GlobalError.from(error)
        AppLog.resource.error("\(context): \(globalError.localizedDescription)")
        DIContainer.shared.core.errorHandler.handle(globalError)
    }
}
