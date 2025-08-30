//
//  ModPackDownloadSheet.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/2.
//

import SwiftUI

struct ModPackDownloadSheet: View {
    let projectId: String
    let gameInfo: GameVersionInfo?
    let query: String
    @EnvironmentObject private var gameRepository: GameRepository
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var viewModel = ModPackDownloadSheetViewModel()
    @State private var selectedGameVersion: String = ""
    @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
    @State private var downloadTask: Task<Void, Error>?
    @State private var isProcessing = false
    @StateObject private var gameSetupService = GameSetupUtil()

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .onAppear {
            viewModel.setGameRepository(gameRepository)
            Task {
                await viewModel.loadProjectDetails(projectId: projectId)
            }
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Text("modpack.download.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isProcessing {
                processingView
            } else if viewModel.isLoadingProjectDetails {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else if let projectDetail = viewModel.projectDetail {
                ModrinthProjectTitleView(projectDetail: projectDetail)
                    .padding(.bottom, 18)
                versionSelectionSection

                if shouldShowProgress {

                    downloadProgressSection.padding(.top, 18)
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            cancelButton
            Spacer()
            confirmButton
        }
    }

    // MARK: - Computed Properties

    private var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var canDownload: Bool {
        !selectedGameVersion.isEmpty && selectedModPackVersion != nil
    }

    private var isDownloading: Bool {
        isProcessing || gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    // MARK: - UI Components

    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.small)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding()
    }

    private var downloadProgressSection: some View {
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
            if let indexInfo = viewModel.lastParsedIndexInfo {
                let loaderState = getLoaderDownloadState(
                    for: indexInfo.loaderType
                )
                let title = getLoaderTitle(for: indexInfo.loaderType)

                if let state = loaderState {
                    progressRow(
                        title: title,
                        state: state,
                        type: .core,
                        version: indexInfo.loaderVersion
                    )
                }
            }
        }
    }

    private var modPackInstallProgress: some View {
        Group {
            if viewModel.modPackInstallState.isInstalling {
                progressRow(
                    title: "modpack.files.title".localized(),
                    installState: viewModel.modPackInstallState,
                    type: .files
                )

                if viewModel.modPackInstallState.dependenciesTotal > 0 {
                    progressRow(
                        title: "modpack.dependencies.title".localized(),
                        installState: viewModel.modPackInstallState,
                        type: .dependencies
                    )
                }
            }
        }
    }

    private var versionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameVersionPicker
            modPackVersionPicker
        }
    }

    private var gameVersionPicker: some View {
        Picker(
            "modpack.game.version".localized(),
            selection: $selectedGameVersion
        ) {
            Text("modpack.game.version.placeholder".localized()).tag("")
            ForEach(viewModel.availableGameVersions, id: \.self) { version in
                Text(version).tag(version)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: selectedGameVersion) { _, newValue in
            handleGameVersionChange(newValue)
        }
    }

    private var modPackVersionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoadingModPackVersions {
                HStack {
                    ProgressView()
                        .controlSize(.small).frame(maxWidth: .infinity)
                }
            } else if !selectedGameVersion.isEmpty {
                Picker(
                    "modpack.version".localized(),
                    selection: $selectedModPackVersion
                ) {
                    ForEach(viewModel.filteredModPackVersions, id: \.id) { version in
                        Text(version.name).tag(
                            version as ModrinthProjectDetailVersion?
                        )
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onAppear {
                    selectFirstModPackVersion()
                }
            }
        }
    }

    private var cancelButton: some View {
        Button("common.cancel".localized()) {
            handleCancel()
        }
        .keyboardShortcut(.cancelAction)
    }

    private var confirmButton: some View {
        Button {
            Task {
                await downloadModPack()
            }
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("modpack.download.button".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canDownload || isDownloading)
    }

    // MARK: - Helper Methods

    private func progressRow(
        title: String,
        state: DownloadState,
        type: ProgressType,
        version: String? = nil
    ) -> some View {
        FormSection {
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

    private func getLoaderDownloadState(
        for loaderType: String
    ) -> DownloadState? {
        switch loaderType.lowercased() {
        case "fabric", "quilt":
            return gameSetupService.fabricDownloadState
        case "forge":
            return gameSetupService.forgeDownloadState
        case "neoforge":
            return gameSetupService.neoForgeDownloadState
        default:
            return nil
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

    private func handleGameVersionChange(_ newValue: String) {
        if !newValue.isEmpty {
            Task {
                await viewModel.loadModPackVersions(for: newValue)
            }
        } else {
            viewModel.filteredModPackVersions = []
        }
    }

    private func selectFirstModPackVersion() {
        if !viewModel.filteredModPackVersions.isEmpty
            && selectedModPackVersion == nil {
            selectedModPackVersion = viewModel.filteredModPackVersions[0]
        }
    }

    private func handleCancel() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
            isProcessing = false
            viewModel.modPackInstallState.reset()
        } else {
            dismiss()
        }
    }

    // MARK: - Download Action

    @MainActor
    private func downloadModPack() async {
        guard let selectedVersion = selectedModPackVersion,
            let projectDetail = viewModel.projectDetail
        else { return }

        downloadTask = Task {
            await performModPackDownload(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail
            )
        }
    }

    @MainActor
    private func performModPackDownload(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail
    ) async {
        isProcessing = true

        // 1. 下载整合包
        guard
            let downloadedPath = await downloadModPackFile(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail
            )
        else {
            isProcessing = false
            return
        }

        // 2. 解压整合包
        guard
            let extractedPath = await viewModel.extractModPack(
                modPackPath: downloadedPath
            )
        else {
            isProcessing = false
            return
        }

        // 3. 解析 modrinth.index.json
        guard
            let indexInfo = await viewModel.parseModrinthIndex(
                extractedPath: extractedPath
            )
        else {
            isProcessing = false
            return
        }

        // 4. 下载游戏图标
        let gameName = "\(projectDetail.title)-\(selectedGameVersion)"
        let iconPath = await viewModel.downloadGameIcon(
            projectDetail: projectDetail,
            gameName: gameName
        )

        // 5. 创建 profile 文件夹
        let profileCreated = await withCheckedContinuation { continuation in
            Task {
                let result = await createProfileDirectories(for: gameName)
                continuation.resume(returning: result)
            }
        }

        if !profileCreated {
            isProcessing = false
            return
        }

        // 6. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameName,
            gameIcon: iconPath ?? "",
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType,
            isUserAdded: true
        )

        let (filesToDownload, requiredDependencies) =
            calculateInstallationCounts(from: indexInfo)

        viewModel.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count
        )

        isProcessing = false

        // 7. 安装依赖
        let dependencySuccess =
            await ModPackDependencyInstaller.installVersionDependencies(
                indexInfo: indexInfo,
                gameInfo: tempGameInfo,
                extractedPath: extractedPath
            ) { fileName, completed, total, type in
                Task { @MainActor in
                    viewModel.objectWillChange.send()
                    updateInstallProgress(
                        fileName: fileName,
                        completed: completed,
                        total: total,
                        type: type
                    )
                }
            }

        if !dependencySuccess {
            handleInstallationResult(success: false, gameName: gameName)
            return
        }

        // 8. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: gameName,
                    gameIcon: iconPath ?? "",
                    selectedGameVersion: selectedGameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    pendingIconData: nil,
                    playerListViewModel: nil,
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Task { @MainActor in
                            Logger.shared.error("游戏设置失败: \(message)")
                            GlobalErrorHandler.shared.handle(error)
                        }
                        continuation.resume(returning: false)
                    }
                )
            }
        }

        handleInstallationResult(success: gameSuccess, gameName: gameName)
    }

    private func downloadModPackFile(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail
    ) async -> URL? {
        let primaryFile =
            selectedVersion.files.first { $0.primary }
            ?? selectedVersion.files.first

        guard let fileToDownload = primaryFile else {
            let globalError = GlobalError.resource(
                chineseMessage: "没有找到可下载的文件",
                i18nKey: "error.resource.no_downloadable_file",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }

        return await viewModel.downloadModPackFile(
            file: fileToDownload,
            projectDetail: projectDetail
        )
    }

    private func createProfileDirectories(for gameName: String) async -> Bool {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)

        let subdirs = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }

        for dir in [profileDirectory] + subdirs {
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                Logger.shared.error(
                    "创建目录失败: \(dir.path), 错误: \(error.localizedDescription)"
                )
                GlobalErrorHandler.shared.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "创建目录失败: \(dir.path)",
                        i18nKey: "error.filesystem.directory_creation_failed",
                        level: .notification
                    )
                )
                return false
            }
        }

        return true
    }

    private func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo
    ) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        let filesToDownload = indexInfo.files.filter { file in
            if let env = file.env, let client = env.client,
                client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
        let requiredDependencies = indexInfo.dependencies.filter {
            $0.dependencyType == "required"
        }

        return (filesToDownload, requiredDependencies)
    }

    private func updateInstallProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType
    ) {
        switch type {
        case .files:
            viewModel.modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total
            )
        case .dependencies:
            viewModel.modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total
            )
        case .overrides:
            break
        }
    }

    private func handleInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("整合包依赖安装完成: \(gameName)")
            dismiss()
        } else {
            Logger.shared.error("整合包依赖安装失败: \(gameName)")
            let globalError = GlobalError.resource(
                chineseMessage: "整合包依赖安装失败",
                i18nKey: "error.resource.modpack_dependencies_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            viewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        }
        isProcessing = false
    }
}

// MARK: - Supporting Types

private enum ProgressType {
    case core, resources
}

private enum InstallProgressType {
    case files, dependencies
}

// MARK: - Preview

#Preview {
    ModPackDownloadSheet(
        projectId: "1KVo5zza",
        gameInfo: nil,
        query: "modpack"
    )
    .environmentObject(GameRepository())
    .frame(height: 600)
}
