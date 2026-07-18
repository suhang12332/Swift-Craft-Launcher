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
class ModPackDownloadSheetViewModel: ObservableObject {
    @Published var projectDetail: ModrinthProjectDetail?
    @Published var availableGameVersions: [String] = []
    @Published var filteredModPackVersions: [ModrinthProjectDetailVersion] = []
    @Published var isLoadingModPackVersions = false
    @Published var isLoadingProjectDetails = true
    @Published var lastParsedIndexInfo: ModrinthIndexInfo?
    @Published var modPackInstallState = ModPackInstallState()
    @Published var modPackDownloadProgress: Int64 = 0
    @Published var modPackTotalSize: Int64 = 0

    @Published var isProcessing = false

    private var downloadTask: Task<Void, Never>?
    private let downloadService = ModPackDownloadService()
    private lazy var installCoordinator = ModPackInstallCoordinator(downloadService: downloadService)

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
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            guard let self else { return }
            let success = await performModPackDownloadAndInstall(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail,
                gameName: gameName,
                selectedGameVersion: selectedGameVersion,
                gameSetupService: gameSetupService,
            )
            onFinished(success)
        }
    }

    func cancelDownloadAndResetStates(gameSetupService: GameSetupUtil? = nil) {
        downloadTask?.cancel()
        downloadTask = nil
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
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            AppLog.modPack.error("Failed to clean up game directories: \(error.localizedDescription)")
        }
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

        let success = await installCoordinator.run(
            .init(
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
            ),
        )

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
