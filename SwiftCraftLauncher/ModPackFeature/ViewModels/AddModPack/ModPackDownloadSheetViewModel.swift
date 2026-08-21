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
    private(set) var isBackgroundInstallation = false

    private var downloadTaskID: UUID?
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

    func cleanupAllData() {
        cancelDownloadAndResetStates()
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
                InstallationTaskManager.shared.updateProgress(
                    self.downloadTaskID,
                    completed: downloaded,
                    total: total,
                )
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
        gameSetupService: GameSetupUtil,
        onFinished: @escaping @MainActor (_ success: Bool) -> Void,
    ) {
        isBackgroundInstallation = false
        InstallationTaskManager.shared.cancel(downloadTaskID)
        downloadTaskID = InstallationTaskManager.shared.start {
            let success = await self.performModPackDownloadAndInstall(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail,
                gameName: gameName,
                selectedGameVersion: selectedGameVersion,
                gameSetupService: gameSetupService,
            )
            self.isBackgroundInstallation = false
            onFinished(success)
        }
    }

    func hideInstallation() {
        isBackgroundInstallation = true
    }

    func cancelDownloadAndResetStates(gameSetupService: GameSetupUtil? = nil) {
        InstallationTaskManager.shared.cancel(downloadTaskID)
        downloadTaskID = nil
        isProcessing = false
        modPackInstallState.reset()
        if let gameSetupService {
            gameSetupService.downloadState.reset()
        }
    }

    func cleanupGameDirectoriesForCancel(gameName: String) async {
        await cleanupGameDirectories(gameName: gameName)
    }

    private func cleanupGameDirectories(gameName: String) async {
        await MinecraftFileManager.cleanupGameDirectoriesSafely(gameName: gameName)
    }

    private func performModPackDownloadAndInstall(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameName: String,
        selectedGameVersion: String,
        gameSetupService: GameSetupUtil,
    ) async -> Bool {
        guard let gameRepository else {
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

        var input: ModPackInstallCoordinator.RunInput = .init(
            archivePath: archivePath,
            projectDetailForIcon: projectDetail,
            gameName: gameName,
            selectedGameVersion: selectedGameVersion,
            gameSetupService: gameSetupService,
            gameRepository: gameRepository,
            modPackInstallState: modPackInstallState,
            setProcessing: { [weak self] processing in
                self?.isProcessing = processing
            },
            setLastParsedIndexInfo: { [weak self] info in
                self?.lastParsedIndexInfo = info
            },
            prepared: nil,
        )
        input.onShowFailedResources = { [weak self] resources, continuation in
            self?.handleFailedResources(resources, continuation: continuation)
        }
        let success = await installCoordinator.run(input)

        if success {
            clearParsedIndexInfo()
        } else {
            clearParsedIndexInfo()
        }

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

    func downloadModPackFile(
        file: ModrinthVersionFile,
        projectDetail: ModrinthProjectDetail,
    ) async -> URL? {
        modPackDownloadProgress = 0
        modPackTotalSize = 0
        return await downloadService.downloadModPackFile(file: file, projectDetail: projectDetail)
    }

    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String,
    ) async -> String? {
        await downloadService.downloadGameIcon(projectDetail: projectDetail, gameName: gameName)
    }

    func extractModPack(modPackPath: URL) async -> URL? {
        await downloadService.extractModPack(modPackPath: modPackPath)
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
