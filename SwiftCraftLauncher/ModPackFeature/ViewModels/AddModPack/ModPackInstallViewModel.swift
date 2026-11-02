//
//  ModPackInstallViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Drives every modpack installation entry: local import, direct URL download,
/// and online project installation.
///
/// The source only determines how the archive is obtained. Once an archive is
/// available, all paths run the same `ModPackInstallCoordinator` pipeline.
@MainActor
@Observable
final class ModPackInstallViewModel: BaseGameFormViewModel {
    let source: ModPackInstallSource

    var projectDetail: ModrinthProjectDetail?
    var availableGameVersions: [String] = []
    private(set) var filteredModPackVersions: [ModrinthProjectDetailVersion] = []
    private(set) var isLoadingModPackVersions = false {
        didSet { updateParentState() }
    }

    var isLoadingProjectDetails = false {
        didSet { updateParentState() }
    }

    var selectedGameVersion = "" {
        didSet { updateParentState() }
    }

    var selectedModPackVersion: ModrinthProjectDetailVersion? {
        didSet { updateParentState() }
    }

    var urlString = "" {
        didSet {
            didFailPreparation = false
            updateParentState()
        }
    }

    private(set) var isDownloadingArchive = false {
        didSet { updateParentState() }
    }

    private(set) var isPreparingArchive = false {
        didSet { updateParentState() }
    }

    private(set) var prepared: ModPackInstallCoordinator.PreparedModPack? {
        didSet { updateParentState() }
    }

    private(set) var resolvedArchiveURL: URL?
    private(set) var didFailPreparation = false

    var lastParsedIndexInfo: ModrinthIndexInfo?
    var modPackInstallState = ModPackInstallState()
    var modPackDownloadProgress: Int64 = 0
    var modPackTotalSize: Int64 = 0

    var failedResources: [FailedModPackResource] = []
    var failedResourcesContinuation: ((Bool) -> Void)?

    private let downloadService: ModPackDownloadService
    private let installCoordinator: ModPackInstallCoordinator
    private var setupTask: Task<Void, Never>?
    private var versionsTask: Task<Void, Never>?
    private var didSetup = false

    init(source: ModPackInstallSource, configuration: GameFormConfiguration) {
        self.source = source

        let downloadService = ModPackDownloadService()
        self.downloadService = downloadService
        installCoordinator = ModPackInstallCoordinator(downloadService: downloadService)

        super.init(configuration: configuration)

        downloadService.progressHandler = { [weak self] downloaded, total in
            Task { @MainActor in
                self?.modPackDownloadProgress = downloaded
                if total > 0 {
                    self?.modPackTotalSize = total
                }
            }
        }
        downloadService.onError = { [weak self] message, i18nKey in
            Task { @MainActor in
                self?.handleDownloadError(message, i18nKey)
            }
        }
    }

    // MARK: - Lifecycle

    func setup(gameRepository: GameRepository) {
        self.gameRepository = gameRepository

        guard !didSetup else {
            updateParentState()
            return
        }
        didSetup = true

        switch source {
        case let .local(archiveURL):
            resolvedArchiveURL = archiveURL
            setupTask = Task { await self.prepare(archiveURL) }
        case .remoteURL:
            break
        case let .project(projectId, preloadedDetail):
            if let preloadedDetail {
                applyPreloadedDetail(preloadedDetail)
            } else {
                setupTask = Task { await self.loadProjectDetails(projectId: projectId) }
            }
        }

        updateParentState()
    }

    func cleanupPreviewState() {
        setupTask?.cancel()
        versionsTask?.cancel()
        modPackInstallState.reset()
        abortFailedResources()
        removeTemporaryArtifacts()
    }

    private func removeTemporaryArtifacts() {
        let archiveURL = resolvedArchiveURL
        let extractedPath = prepared?.extractedPath

        prepared = nil
        resolvedArchiveURL = nil
        lastParsedIndexInfo = nil

        Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            if let extractedPath {
                try? fileManager.removeItem(at: extractedPath)
            }

            if let archiveURL, TemporaryFile.isTemporary(archiveURL) {
                try? fileManager.removeItem(at: archiveURL.deletingLastPathComponent())
            }
        }
    }

    override func performCancelCleanup() async {
        cleanupPreviewState()
        await super.performCancelCleanup()
    }

    // MARK: - Installation

    override func performInstallation() async {
        switch source {
        case .local:
            await installPreparedArchive()
        case .remoteURL:
            if prepared == nil {
                await downloadRemoteArchive()
            } else {
                await installPreparedArchive()
            }
        case .project:
            await downloadProjectAndInstall()
        }
    }

    private func installPreparedArchive() async {
        guard let archive = resolvedArchiveURL, let prepared else { return }
        await install(archive: archive, prepared: prepared, projectDetail: nil)
    }

    private func downloadRemoteArchive() async {
        guard let url = URL(string: urlString), isURLValid else { return }

        isDownloadingArchive = true
        let archive = await downloadService.downloadModPackArchive(from: url)
        isDownloadingArchive = false

        guard let archive else { return }
        resolvedArchiveURL = archive
        await prepare(archive)
    }

    private func downloadProjectAndInstall() async {
        guard let projectDetail, let selectedModPackVersion else { return }

        let file =
            selectedModPackVersion.files.first { $0.primary }
                ?? selectedModPackVersion.files.first
        guard let file else {
            DIContainer.shared.core.errorHandler.handle(
                GlobalError.resource(
                    i18nKey: "error.resource.no_downloadable_file",
                    level: .notification,
                ),
            )
            return
        }

        isDownloadingArchive = true
        let archive = await downloadService.downloadModPackFile(
            file: file,
            projectDetail: projectDetail,
        )
        isDownloadingArchive = false

        guard let archive else { return }
        resolvedArchiveURL = archive
        await install(archive: archive, prepared: nil, projectDetail: projectDetail)
    }

    /// Runs the shared installation pipeline for every entry point.
    private func install(
        archive: URL,
        prepared: ModPackInstallCoordinator.PreparedModPack?,
        projectDetail: ModrinthProjectDetail?,
    ) async {
        guard let gameRepository else { return }

        let onShowFailedResources: ([FailedModPackResource], @escaping (Bool) -> Void) -> Void = { [weak self] resources, continuation in
            self?.handleFailedResources(resources, continuation: continuation)
        }

        let input = ModPackInstallCoordinator.RunInput(
            archivePath: archive,
            projectDetailForIcon: projectDetail,
            gameName: gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedGameVersion: prepared?.indexInfo.gameVersion ?? selectedGameVersion,
            gameInstaller: gameInstaller,
            gameRepository: gameRepository,
            modPackInstallState: modPackInstallState,
            setProcessing: { [weak self] processing in
                guard let self, self.prepared == nil else { return }
                isPreparingArchive = processing
            },
            setLastParsedIndexInfo: { [weak self] info in
                self?.lastParsedIndexInfo = info
            },
            prepared: prepared,
            onShowFailedResources: onShowFailedResources,
        )

        _ = await installCoordinator.run(input)

        if !Task.isCancelled {
            completeInstallation()
        }
    }

    private func prepare(_ archiveURL: URL) async {
        didFailPreparation = false
        isPreparingArchive = true
        defer { isPreparingArchive = false }

        guard let prepared = await installCoordinator.prepare(archivePath: archiveURL) else {
            didFailPreparation = true
            return
        }
        guard !Task.isCancelled else { return }

        self.prepared = prepared
        lastParsedIndexInfo = prepared.indexInfo
        gameNameValidator.setDefaultName(
            GameNameGenerator.generateImportName(
                modPackName: prepared.indexInfo.modPackName,
                modPackVersion: prepared.indexInfo.modPackVersion,
                includeTimestamp: true,
            ),
        )
    }

    // MARK: - Online project

    func applyPreloadedDetail(_ detail: ModrinthProjectDetail) {
        projectDetail = detail
        availableGameVersions = detail.gameVersions
        isLoadingProjectDetails = false
    }

    func loadProjectDetails(projectId: String) async {
        isLoadingProjectDetails = true

        defer { isLoadingProjectDetails = false }

        do {
            let detail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId)
            applyPreloadedDetail(detail)
        } catch {
            DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
        }
    }

    func loadModPackVersions(for gameVersion: String) {
        versionsTask?.cancel()

        guard let projectDetail else { return }

        isLoadingModPackVersions = true
        filteredModPackVersions = []

        versionsTask = Task {
            defer { isLoadingModPackVersions = false }

            do {
                let versions = try await ModrinthService.fetchProjectVersionsThrowing(
                    id: projectDetail.id,
                )
                guard !Task.isCancelled else { return }
                filteredModPackVersions = versions
                    .filter { $0.gameVersions.contains(gameVersion) }
                    .sorted { $0.datePublished > $1.datePublished }
            } catch {
                guard !Task.isCancelled else { return }
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }

    func handleGameVersionChange(_ newValue: String) {
        guard !newValue.isEmpty else { return }
        loadModPackVersions(for: newValue)
        updateOnlineGameName()
    }

    func selectFirstModPackVersion() {
        guard selectedModPackVersion == nil, let first = filteredModPackVersions.first else { return }
        selectedModPackVersion = first
    }

    private func updateOnlineGameName() {
        gameNameValidator.gameName = GameNameGenerator.generateModPackName(
            projectTitle: projectDetail?.title,
            gameVersion: selectedGameVersion,
            includeTimestamp: true,
        )
    }

    // MARK: - Form state

    override func computeIsDownloading() -> Bool {
        gameInstaller.progress.isDownloading
            || modPackInstallState.isInstalling
            || isDownloadingArchive
            || isPreparingArchive
    }

    override func computeIsLoadingLoaderVersions() -> Bool {
        isLoadingProjectDetails || isLoadingModPackVersions
    }

    override func computeIsFormValid() -> Bool {
        switch source {
        case .local:
            return prepared != nil && isPreparedGameVersionSupported && gameNameValidator.isFormValid
        case .remoteURL:
            if prepared != nil {
                return isPreparedGameVersionSupported && gameNameValidator.isFormValid
            }
            return isURLValid
        case .project:
            return !selectedGameVersion.isEmpty
                && selectedModPackVersion != nil
                && gameNameValidator.isFormValid
        }
    }

    var isURLValid: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    var shouldShowProgress: Bool {
        gameInstaller.progress.isDownloading || modPackInstallState.isInstalling
    }

    var isPreparedGameVersionSupported: Bool {
        guard let version = prepared?.indexInfo.gameVersion, !version.isEmpty else { return true }
        return CommonUtil.isVersionAtLeast(version)
    }

    var modPackName: String {
        prepared?.indexInfo.modPackName ?? ""
    }

    var modPackVersion: String {
        prepared?.indexInfo.modPackVersion ?? ""
    }

    var gameVersion: String {
        prepared?.indexInfo.gameVersion ?? ""
    }

    var loaderInfo: String {
        guard let indexInfo = prepared?.indexInfo else { return "" }
        return indexInfo.loaderVersion.isEmpty
            ? indexInfo.loaderType
            : "\(indexInfo.loaderType)-\(indexInfo.loaderVersion)"
    }

    var processingSubtitleKey: String {
        switch source {
        case .local:
            return "modpack.processing.subtitle.local"
        case .remoteURL, .project:
            return "modpack.processing.subtitle.remote"
        }
    }

    private func handleDownloadError(_: String, _ i18nKey: String) {
        DIContainer.shared.core.errorHandler.handle(
            GlobalError.resource(
                i18nKey: i18nKey,
                level: .notification,
            ),
        )
    }
}

extension ModPackInstallViewModel: FailedResourcesPresenting { }
