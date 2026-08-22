//
//  ModPackInstallCoordinator.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Orchestrates the full modpack installation flow: extraction, parsing, dependency resolution,
/// override installation, file installation, and game setup.
@MainActor
final class ModPackInstallCoordinator {
    /// A prepared modpack with extracted path and parsed index.
    struct PreparedModPack {
        let extractedPath: URL
        let indexInfo: ModrinthIndexInfo
        let projectDetailForIcon: ModrinthProjectDetail?
    }

    /// Input parameters for the installation run.
    struct RunInput: @unchecked Sendable {
        let archivePath: URL
        let projectDetailForIcon: ModrinthProjectDetail?
        let gameName: String
        let selectedGameVersion: String
        let gameSetupService: GameSetupUtil
        let gameRepository: GameRepository
        let modPackInstallState: ModPackInstallState
        let setProcessing: (Bool) -> Void
        let setLastParsedIndexInfo: (ModrinthIndexInfo?) -> Void
        let prepared: PreparedModPack?
        /// Invoked when resources fail to download, with the failed resources and a
        /// continuation reporting whether all resources were handled.
        var onShowFailedResources: (([FailedModPackResource], @escaping (Bool) -> Void) -> Void)?
    }

    private let downloadService: ModPackDownloadService

    init(downloadService: ModPackDownloadService) { self.downloadService = downloadService }

    /// Prepares the modpack by extracting and parsing the index.
    /// - Parameters:
    ///   - archivePath: The path to the modpack archive.
    ///   - projectDetailForIcon: Optional project detail for downloading the icon.
    /// - Returns: A prepared modpack, or nil on failure.
    func prepare(
        archivePath: URL,
        projectDetailForIcon: ModrinthProjectDetail? = nil,
    ) async -> PreparedModPack? {
        guard let extractedPath = await downloadService.extractModPack(modPackPath: archivePath) else {
            return nil
        }

        guard let indexInfo = await ModPackIndexParser.parseIndex(extractedPath: extractedPath) else {
            DIContainer.shared.core.errorHandler.handle(
                GlobalError.resource(
                    i18nKey: "error.resource.unsupported_modpack_format",
                    level: .notification,
                ),
            )
            return nil
        }

        return .init(
            extractedPath: extractedPath,
            indexInfo: indexInfo,
            projectDetailForIcon: projectDetailForIcon,
        )
    }

    /// Runs the full installation flow.
    /// - Parameter input: The installation input parameters.
    /// - Returns: Whether installation succeeded.
    func run(_ input: RunInput) async -> Bool {
        input.setProcessing(true)
        if Task.isCancelled {
            await handleCancelledInstallation(
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState,
            )
            return false
        }
        guard let preparedPack = await resolvePreparedPack(input) else {
            input.setProcessing(false)
            return false
        }
        let extractedPath = preparedPack.extractedPath
        let indexInfo = preparedPack.indexInfo
        let iconPath = await downloadOptionalIcon(
            projectDetailForIcon: preparedPack.projectDetailForIcon,
            gameName: input.gameName,
        )

        let profileCreated = await createProfileDirectories(for: input.gameName)
        guard profileCreated else {
            await handleInstallationResult(
                success: false,
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState,
            )
            return false
        }

        input.setProcessing(false)

        let resourceDir = AppPaths.profileDirectory(gameName: input.gameName)
        guard await installOverridesStep(
            extractedPath: extractedPath,
            resourceDir: resourceDir,
            input: input,
        ) else {
            return await handleStepFailure(input)
        }

        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: input.gameName,
            gameIcon: iconPath ?? AppConstants.defaultGameIcon,
            gameVersion: input.selectedGameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType,
        )

        let (filesToDownload, requiredDependencies) = calculateInstallationCounts(from: indexInfo)
        input.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count,
        )

        guard await installFilesStep(
            indexInfo: indexInfo,
            resourceDir: resourceDir,
            gameInfo: tempGameInfo,
            input: input,
        ) else {
            return await handleStepFailure(input)
        }

        guard await installDependenciesStep(
            indexInfo: indexInfo,
            resourceDir: resourceDir,
            gameInfo: tempGameInfo,
            input: input,
        ) else {
            return await handleStepFailure(input)
        }

        let gameSuccess = await installGameStep(
            input: input,
            indexInfo: indexInfo,
        )

        await handleInstallationResult(
            success: gameSuccess,
            gameName: input.gameName,
            gameSetupService: input.gameSetupService,
            modPackInstallState: input.modPackInstallState,
        )

        downloadService.cleanupTempFiles()
        return gameSuccess
    }

    private func resolvePreparedPack(_ input: RunInput) async -> PreparedModPack? {
        if let prepared = input.prepared {
            input.setLastParsedIndexInfo(prepared.indexInfo)
            return prepared
        }
        guard let prepared = await prepare(
            archivePath: input.archivePath,
            projectDetailForIcon: input.projectDetailForIcon,
        ) else {
            if Task.isCancelled {
                await handleCancelledInstallation(
                    gameName: input.gameName,
                    gameSetupService: input.gameSetupService,
                    modPackInstallState: input.modPackInstallState,
                )
            }
            return nil
        }
        input.setLastParsedIndexInfo(prepared.indexInfo)
        return prepared
    }

    private func downloadOptionalIcon(
        projectDetailForIcon: ModrinthProjectDetail?,
        gameName: String,
    ) async -> String? {
        guard let projectDetailForIcon else { return nil }
        return await downloadService.downloadGameIcon(
            projectDetail: projectDetailForIcon,
            gameName: gameName,
        )
    }

    private func installOverridesStep(
        extractedPath: URL,
        resourceDir: URL,
        input: RunInput,
    ) async -> Bool {
        let overridesTotal = await calculateOverridesTotal(extractedPath: extractedPath)
        if overridesTotal > 0 {
            input.modPackInstallState.isInstalling = true
            input.modPackInstallState.overridesTotal = overridesTotal
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        return await ModPackDependencyInstaller.installOverrides(
            extractedPath: extractedPath,
            resourceDir: resourceDir,
        ) { fileName, completed, total, type in
            Task { @MainActor in
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type,
                )
            }
        }
    }

    private func installFilesStep(
        indexInfo: ModrinthIndexInfo,
        resourceDir: URL,
        gameInfo: GameVersionInfo,
        input: RunInput,
    ) async -> Bool {
        let failedFiles = await ModPackDependencyInstaller.installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: gameInfo,
        ) { fileName, completed, total, type in
            Task { @MainActor in
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type,
                )
            }
        }

        guard failedFiles.isEmpty else {
            let failedResources = await FailedResourceResolver.makeFailedResources(from: failedFiles, gameInfo: gameInfo)
            return await FailedResourceResolver.presentFailedResources(failedResources, input: input)
        }
        return true
    }

    private func installDependenciesStep(
        indexInfo: ModrinthIndexInfo,
        resourceDir: URL,
        gameInfo: GameVersionInfo,
        input: RunInput,
    ) async -> Bool {
        let failedDependencies = await ModPackDependencyInstaller.installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: gameInfo,
            resourceDir: resourceDir,
        ) { fileName, completed, total, type in
            Task { @MainActor in
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type,
                )
            }
        }

        guard failedDependencies.isEmpty else {
            let failedResources = await FailedResourceResolver.makeFailedResources(from: failedDependencies, gameInfo: gameInfo)
            return await FailedResourceResolver.presentFailedResources(failedResources, input: input)
        }
        return true
    }

    private func installGameStep(
        input: RunInput,
        indexInfo: ModrinthIndexInfo,
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            Task {
                await input.gameSetupService.saveGame(
                    input: .init(
                        gameName: input.gameName,
                        selectedGameVersion: input.selectedGameVersion,
                        selectedModLoader: indexInfo.loaderType,
                        specifiedLoaderVersion: indexInfo.loaderVersion,
                        pendingIconData: nil,
                    ),
                    playerListViewModel: nil,
                    gameRepository: input.gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Task { @MainActor in
                            AppLog.modPack.error("Game setup failed: \(message)")
                            DIContainer.shared.core.errorHandler.handle(error)
                        }
                        continuation.resume(returning: false)
                    },
                )
            }
        }
    }

    private func handleStepFailure(_ input: RunInput) async -> Bool {
        if Task.isCancelled {
            await handleCancelledInstallation(
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState,
            )
            return false
        }
        await handleInstallationResult(
            success: false,
            gameName: input.gameName,
            gameSetupService: input.gameSetupService,
            modPackInstallState: input.modPackInstallState,
        )
        return false
    }

    private func calculateOverridesTotal(extractedPath: URL) async -> Int {
        var overridesPath = extractedPath.appendingPathComponent("overrides")
        if !FileManager.default.fileExists(atPath: overridesPath.path) {
            let possiblePaths = ["overrides", "Override", "override", "minecraft"]
            for pathName in possiblePaths {
                let testPath = extractedPath.appendingPathComponent(pathName)
                if FileManager.default.fileExists(atPath: testPath.path) {
                    overridesPath = testPath
                    break
                }
            }
        }

        guard FileManager.default.fileExists(atPath: overridesPath.path) else {
            return 0
        }

        do {
            let allFiles = try InstanceFileCopier.getAllFiles(in: overridesPath)
            return allFiles.count
        } catch {
            AppLog.modPack.error("Failed to calculate overrides total: \(error.localizedDescription)")
            return 0
        }
    }

    private func createProfileDirectories(for gameName: String) async -> Bool {
        await MinecraftFileManager.createProfileDirectories(for: gameName)
    }

    private func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo,
    ) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        MinecraftFileManager.calculateInstallationCounts(from: indexInfo)
    }

    private func updateInstallProgress(
        modPackInstallState: ModPackInstallState,
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType,
    ) {
        switch type {
        case .files:
            modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total,
            )
        case .dependencies:
            modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total,
            )
        case .overrides:
            modPackInstallState.updateOverridesProgress(
                overrideName: fileName,
                completed: completed,
                total: total,
            )
        }
    }

    private func handleInstallationResult(
        success: Bool,
        gameName: String,
        gameSetupService: GameSetupUtil,
        modPackInstallState: ModPackInstallState,
    ) async {
        if Task.isCancelled {
            await handleCancelledInstallation(
                gameName: gameName,
                gameSetupService: gameSetupService,
                modPackInstallState: modPackInstallState,
            )
            return
        }

        if success {
            AppLog.modPack.info("Modpack dependency installation completed: \(gameName)")
        } else {
            AppLog.modPack.error("Modpack dependency installation failed: \(gameName)")
            await cleanupGameDirectories(gameName: gameName)
            DIContainer.shared.core.errorHandler.handle(
                GlobalError.resource(
                    i18nKey: "error.resource.modpack_dependencies_failed",
                    level: .notification,
                ),
            )
            modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        }
    }

    private func handleCancelledInstallation(
        gameName: String,
        gameSetupService: GameSetupUtil,
        modPackInstallState: ModPackInstallState,
    ) async {
        AppLog.modPack.info("Modpack installation cancelled: \(gameName)")
        await cleanupGameDirectories(gameName: gameName)
        modPackInstallState.reset()
        gameSetupService.downloadState.reset()
    }

    private func cleanupGameDirectories(gameName: String) async {
        await MinecraftFileManager.cleanupGameDirectoriesSafely(gameName: gameName)
    }
}
