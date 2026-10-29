//
//  ModPackDownloadSheetViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages modpack download and installation state, including project details,
/// version filtering, and progress tracking.
@MainActor
@Observable
class ModPackDownloadSheetViewModel {
    var projectDetail: ModrinthProjectDetail?
    var availableGameVersions: [String] = []
    var filteredModPackVersions: [ModrinthProjectDetailVersion] = []
    var isLoadingModPackVersions = false
    var isLoadingProjectDetails = true
    var lastParsedIndexInfo: ModrinthIndexInfo?
    var modPackInstallState = ModPackInstallState()
    var modPackDownloadProgress: Int64 = 0
    var modPackTotalSize: Int64 = 0

    var isProcessing = false
    var failedResources: [FailedModPackResource] = []
    var failedResourcesContinuation: ((Bool) -> Void)?

    private let installTasks = InstallTaskCoordinator()
    private let downloadService = ModPackDownloadService()
    private var _installCoordinator: ModPackInstallCoordinator?
    private var installCoordinator: ModPackInstallCoordinator {
        if let _installCoordinator {
            return _installCoordinator
        }
        let coordinator = ModPackInstallCoordinator(downloadService: downloadService)
        _installCoordinator = coordinator
        return coordinator
    }

    func clearParsedIndexInfo() {
        lastParsedIndexInfo = nil
    }

    func cleanupAllData(gameInstaller: GameInstaller? = nil) {
        cancelDownloadAndResetStates(gameInstaller: gameInstaller)
        clearParsedIndexInfo()
        projectDetail = nil
        availableGameVersions = []
        filteredModPackVersions = []
        allModPackVersions = []
        modPackInstallState.reset()
        modPackDownloadProgress = 0
        modPackTotalSize = 0
        cleanupTempFiles()
    }

    func cleanupTempFiles() {
        downloadService.cleanupTempFiles()
    }

    private var allModPackVersions: [ModrinthProjectDetailVersion] = []
    private var gameRepository: GameRepository?

    func setGameRepository(_ repository: GameRepository) {
        gameRepository = repository
    }

    init() {
        downloadService.progressHandler = { [weak self] downloaded, total in
            guard let self else { return }
            Task { @MainActor in
                self.modPackDownloadProgress = downloaded
                if total > 0 {
                    self.modPackTotalSize = total
                }
            }
        }
        downloadService.onError = { [weak self] message, i18nKey in
            guard let self else { return }
            Task { @MainActor in
                self.handleDownloadError(message, i18nKey)
            }
        }
    }

    func beginDownloadAndInstall(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameName: String,
        selectedGameVersion: String,
        gameInstaller: GameInstaller,
        onFinished: @escaping @MainActor (_ success: Bool) -> Void,
    ) {
        installTasks.start { [weak self] in
            guard let self else { return }
            let success = await performModPackDownloadAndInstall(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail,
                gameName: gameName,
                selectedGameVersion: selectedGameVersion,
                gameInstaller: gameInstaller,
            )
            onFinished(success)
        }
    }

    func cancelDownloadAndResetStates(gameInstaller: GameInstaller? = nil) {
        installTasks.cancel()
        isProcessing = false
        modPackInstallState.reset()
        if let gameInstaller {
            gameInstaller.progress.reset()
        }
    }

    /// Cancels an in-flight installation and removes the partially created instance.
    /// - Parameters:
    ///   - gameName: The name of the game being installed.
    ///   - gameInstaller: The installer whose progress should be reset.
    func cancelInstallation(gameName: String, gameInstaller: GameInstaller) async {
        abortFailedResources()
        cancelDownloadAndResetStates(gameInstaller: gameInstaller)
        clearParsedIndexInfo()
        cleanupTempFiles()

        let trimmedName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        try? MinecraftFileManager.cleanupGameDirectories(gameName: trimmedName)
    }

    /// Prepares an archive for preview without installing it.
    /// - Parameter archivePath: The local modpack archive to extract and parse.
    /// - Returns: The prepared modpack, or `nil` when extraction or parsing fails.
    func prepare(archivePath: URL) async -> ModPackInstallCoordinator.PreparedModPack? {
        await installCoordinator.prepare(archivePath: archivePath)
    }

    /// Runs the shared modpack installation pipeline.
    ///
    /// Local import passes an already prepared pack; online download lets the
    /// coordinator extract and parse the downloaded archive.
    /// - Returns: Whether the installation succeeded.
    func install(
        archivePath: URL,
        projectDetailForIcon: ModrinthProjectDetail? = nil,
        gameName: String,
        selectedGameVersion: String,
        gameInstaller: GameInstaller,
        prepared: ModPackInstallCoordinator.PreparedModPack? = nil,
    ) async -> Bool {
        guard let gameRepository else { return false }

        let onShowFailedResources: ([FailedModPackResource], @escaping (Bool) -> Void) -> Void = { [weak self] resources, continuation in
            self?.handleFailedResources(resources, continuation: continuation)
        }

        let input = ModPackInstallCoordinator.RunInput(
            archivePath: archivePath,
            projectDetailForIcon: projectDetailForIcon,
            gameName: gameName,
            selectedGameVersion: selectedGameVersion,
            gameInstaller: gameInstaller,
            gameRepository: gameRepository,
            modPackInstallState: modPackInstallState,
            setProcessing: { [weak self] processing in
                self?.isProcessing = processing
            },
            setLastParsedIndexInfo: { [weak self] info in
                self?.lastParsedIndexInfo = info
            },
            prepared: prepared,
            onShowFailedResources: onShowFailedResources,
        )

        return await installCoordinator.run(input)
    }

    private func performModPackDownloadAndInstall(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameName: String,
        selectedGameVersion: String,
        gameInstaller: GameInstaller,
    ) async -> Bool {
        guard gameRepository != nil else {
            return false
        }

        isProcessing = true

        let primaryFile =
            selectedVersion.files.first { $0.primary }
                ?? selectedVersion.files.first

        guard let fileToDownload = primaryFile else {
            isProcessing = false
            DIContainer.shared.core.errorHandler.handle(
                GlobalError.resource(
                    i18nKey: "error.resource.no_downloadable_file",
                    level: .notification,
                ),
            )
            return false
        }

        guard let archivePath = await downloadService.downloadModPackFile(
            file: fileToDownload,
            projectDetail: projectDetail,
        ) else {
            isProcessing = false
            return false
        }

        let success = await install(
            archivePath: archivePath,
            projectDetailForIcon: projectDetail,
            gameName: gameName,
            selectedGameVersion: selectedGameVersion,
            gameInstaller: gameInstaller,
        )

        clearParsedIndexInfo()

        return success
    }

    func applyPreloadedDetail(_ detail: ModrinthProjectDetail) {
        projectDetail = detail
        availableGameVersions = detail.gameVersions
        isLoadingProjectDetails = false
    }

    func loadProjectDetails(projectId: String) async {
        isLoadingProjectDetails = true

        do {
            projectDetail =
                try await ModrinthService.fetchProjectDetailsThrowing(
                    id: projectId,
                )
            availableGameVersions = projectDetail?.gameVersions ?? []
        } catch {
            let globalError = GlobalError.from(error)
            DIContainer.shared.core.errorHandler.handle(globalError)
        }

        isLoadingProjectDetails = false
    }

    func loadModPackVersions(for gameVersion: String) async {
        guard let projectDetail else { return }

        isLoadingModPackVersions = true

        do {
            allModPackVersions =
                try await ModrinthService.fetchProjectVersionsThrowing(
                    id: projectDetail.id,
                )
            filteredModPackVersions = allModPackVersions
                .filter { version in
                    version.gameVersions.contains(gameVersion)
                }
                .sorted { version1, version2 in
                    version1.datePublished > version2.datePublished
                }
        } catch {
            let globalError = GlobalError.from(error)
            DIContainer.shared.core.errorHandler.handle(globalError)
        }

        isLoadingModPackVersions = false
    }

    private func handleDownloadError(_: String, _ i18nKey: String) {
        let globalError = GlobalError.resource(
            i18nKey: i18nKey,
            level: .notification,
        )
        DIContainer.shared.core.errorHandler.handle(globalError)
    }
}

extension ModPackDownloadSheetViewModel: FailedResourcesPresenting { }
