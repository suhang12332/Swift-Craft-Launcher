import SwiftUI
import UniformTypeIdentifiers

// MARK: - ModPackImportView
struct ModPackImportView: View {
    @Binding var isDownloading: Bool
    @Binding var isFormValid: Bool
    @Binding var triggerConfirm: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // MARK: - State
    @StateObject private var gameSetupService = GameSetupUtil()
    @StateObject private var modPackViewModel = ModPackDownloadSheetViewModel()
    @StateObject private var gameNameValidator: GameNameValidator

    // MARK: - Initializer
    init(
        isDownloading: Binding<Bool>,
        isFormValid: Binding<Bool>,
        triggerConfirm: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self._isDownloading = isDownloading
        self._isFormValid = isFormValid
        self._triggerConfirm = triggerConfirm
        self.onCancel = onCancel
        self.onConfirm = onConfirm

        // Initialize gameNameValidator with a temporary GameSetupUtil
        // The actual gameSetupService will be set in onAppear
        let tempGameSetupService = GameSetupUtil()
        self._gameNameValidator = StateObject(wrappedValue: GameNameValidator(gameSetupService: tempGameSetupService))
    }

    @State private var selectedModPackFile: URL?
    @State private var showModPackFilePicker = false
    @State private var extractedModPackPath: URL?
    @State private var modPackIndexInfo: ModrinthIndexInfo?
    @State private var isProcessingModPack = false
    @State private var modPackDownloadTask: Task<Void, Error>?

    // MARK: - Body
    var body: some View {
        formContentView
        .fileImporter(
            isPresented: $showModPackFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "mrpack") ?? UTType.data,
                .zip,
                UTType(filenameExtension: "zip") ?? UTType.zip,
            ],
            allowsMultipleSelection: false
        ) { result in
            handleModPackFileSelection(result)
        }
        .onAppear {
            modPackViewModel.setGameRepository(gameRepository)
            updateParentState()
        }
        .onChange(of: gameNameValidator.gameName) {
            updateParentState()
        }
        .onChange(of: gameNameValidator.isGameNameDuplicate) {
            updateParentState()
        }
        .onChange(of: selectedModPackFile) {
            updateParentState()
        }
        .onChange(of: modPackIndexInfo?.modPackName) {
            updateParentState()
        }
        .onChange(of: gameSetupService.downloadState.isDownloading) {
            updateParentState()
        }
        .onChange(of: modPackViewModel.modPackInstallState.isInstalling) {
            updateParentState()
        }
        .onChange(of: isProcessingModPack) {
            updateParentState()
        }
        .onChange(of: triggerConfirm) {
            if triggerConfirm {
                handleConfirm()
                triggerConfirm = false
            }
        }
    }

    // MARK: - View Components

    private var formContentView: some View {
        VStack {
            modPackImportContentView
            if hasSelectedModPack {
                modPackGameNameInputSection
            }

            if shouldShowProgress {
                downloadProgressSection
            }
        }
    }

    private var modPackImportContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isProcessingModPack {
                modPackProcessingView
            } else {
                modPackFileSelectionSection
            }
        }
    }

    private var modPackProcessingView: some View {
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

    private var modPackFileSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if hasSelectedModPack {
                        selectedModPackView
                        Spacer()
                        changeModPackButton
                    } else {
                        unselectedModPackView
                        Spacer()
                        selectModPackButton
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - ModPack Selection Computed Properties

    private var hasSelectedModPack: Bool {
        selectedModPackFile != nil && modPackIndexInfo != nil
    }

    private var modPackName: String {
        modPackIndexInfo?.modPackName ?? ""
    }

    private var gameVersion: String {
        modPackIndexInfo?.gameVersion ?? ""
    }

    private var modPackVersion: String {
        modPackIndexInfo?.modPackVersion ?? ""
    }

    private var loaderInfo: String {
        guard let indexInfo = modPackIndexInfo else { return "" }
        return indexInfo.loaderVersion.isEmpty
            ? indexInfo.loaderType
            : "\(indexInfo.loaderType)-\(indexInfo.loaderVersion)"
    }

    // MARK: - ModPack Selection View Components

    private var selectedModPackView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(modPackName)
                .font(.headline)
                .bold()
            selectedModPackInfoRow
        }
    }

    private var selectedModPackInfoRow: some View {
        HStack(spacing: 8) {
            Label(
                modPackVersion,
                systemImage: "text.document.fill"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(gameVersion, systemImage: "gamecontroller.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(loaderInfo, systemImage: "puzzlepiece.extension.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var unselectedModPackView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("modpack.import.file.placeholder".localized())
                .font(.body)
                .foregroundColor(.secondary)

            Text("modpack.import.file.description".localized())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var changeModPackButton: some View {
        Button("common.change".localized()) {
            showModPackFilePicker = true
        }
        .buttonStyle(.bordered)
        .disabled(isProcessingModPack || isDownloading)
    }

    private var selectModPackButton: some View {
        Button("modpack.import.file.select".localized()) {
            showModPackFilePicker = true
        }
        .buttonStyle(.borderedProminent)
    }

    private var modPackGameNameInputSection: some View {
        FormSection {
            GameNameInputView(
                gameName: $gameNameValidator.gameName,
                isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                isDisabled: isProcessingModPack || isDownloading,
                gameSetupService: gameSetupService
            )
        }
    }

    private var downloadProgressSection: some View {
        VStack(spacing: 24) {
            modPackInstallProgressView
        }
    }

    private var modPackInstallProgressView: some View {
        VStack(spacing: 24) {
            // 游戏核心下载进度
            FormSection {
                DownloadProgressRow(
                    title: "download.core.title".localized(),
                    progress: gameSetupService.downloadState.coreProgress,
                    currentFile: gameSetupService.downloadState.currentCoreFile,
                    completed: gameSetupService.downloadState.coreCompletedFiles,
                    total: gameSetupService.downloadState.coreTotalFiles,
                    version: nil
                )
            }
            FormSection {
                DownloadProgressRow(
                    title: "download.resources.title".localized(),
                    progress: gameSetupService.downloadState.resourcesProgress,
                    currentFile: gameSetupService.downloadState.currentResourceFile,
                    completed: gameSetupService.downloadState.resourcesCompletedFiles,
                    total: gameSetupService.downloadState.resourcesTotalFiles,
                    version: nil
                )
            }

            // 模组加载器下载进度
            if let indexInfo = modPackIndexInfo {
                let loaderState = getLoaderDownloadState(for: indexInfo.loaderType)
                let title = getLoaderTitle(for: indexInfo.loaderType)

                if let state = loaderState {
                    FormSection {
                        DownloadProgressRow(
                            title: title,
                            progress: state.coreProgress,
                            currentFile: state.currentCoreFile,
                            completed: state.coreCompletedFiles,
                            total: state.coreTotalFiles,
                            version: indexInfo.loaderVersion
                        )
                    }
                }
            }

            // 整合包安装进度
            if modPackViewModel.modPackInstallState.isInstalling {
                FormSection {
                    DownloadProgressRow(
                        title: "modpack.files.title".localized(),
                        progress: modPackViewModel.modPackInstallState.filesProgress,
                        currentFile: modPackViewModel.modPackInstallState.currentFile,
                        completed: modPackViewModel.modPackInstallState.filesCompleted,
                        total: modPackViewModel.modPackInstallState.filesTotal,
                        version: nil
                    )
                }

                if modPackViewModel.modPackInstallState.dependenciesTotal > 0 {
                    FormSection {
                        DownloadProgressRow(
                            title: "modpack.dependencies.title".localized(),
                            progress: modPackViewModel.modPackInstallState.dependenciesProgress,
                            currentFile: modPackViewModel.modPackInstallState.currentDependency,
                            completed: modPackViewModel.modPackInstallState.dependenciesCompleted,
                            total: modPackViewModel.modPackInstallState.dependenciesTotal,
                            version: nil
                        )
                    }
                }
            }
        }
    }

    private func getLoaderDownloadState(for loaderType: String) -> DownloadState? {
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

    // MARK: - Computed Properties

    private var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
    }

    // MARK: - Helper Methods

    private func handleNonCriticalError(_ error: GlobalError, message: String) {
        Logger.shared.error("\(message): \(error.chineseMessage)")
        GlobalErrorHandler.shared.handle(error)
    }

    private func handleModPackFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "无法访问所选文件",
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification
                )
                GlobalErrorHandler.shared.handle(globalError)
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            // 复制文件到临时目录以便后续使用
            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("modpack_import")
                    .appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(
                    at: tempDir,
                    withIntermediateDirectories: true
                )

                let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: tempFile)

                selectedModPackFile = tempFile

                // 立即解析整合包
                Task {
                    await parseSelectedModPack()
                }
            } catch {
                let globalError = GlobalError.from(error)
                GlobalErrorHandler.shared.handle(globalError)
            }

        case .failure(let error):
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    private func parseSelectedModPack() async {
        guard let selectedFile = selectedModPackFile else { return }

        // 解压整合包
        guard let extracted = await modPackViewModel.extractModPack(modPackPath: selectedFile) else {
            return
        }

        extractedModPackPath = extracted

        // 解析索引信息
        if let parsed = await modPackViewModel.parseModrinthIndex(extractedPath: extracted) {
            await MainActor.run {
                modPackIndexInfo = parsed
                let defaultName = GameNameGenerator.generateImportName(
                    modPackName: parsed.modPackName,
                    modPackVersion: parsed.modPackVersion
                )
                gameNameValidator.setDefaultName(defaultName)
            }
        }
    }

    @MainActor
    private func importModPack() async {
        guard selectedModPackFile != nil,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo else { return }

        isProcessingModPack = true

        // 1. 创建 profile 文件夹
        let profileCreated = await createProfileDirectories(for: gameNameValidator.gameName)

        if !profileCreated {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 2. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameNameValidator.gameName,
            gameIcon: AppConstants.defaultGameIcon,
            gameVersion: indexInfo.gameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType,
            isUserAdded: true
        )

        let (filesToDownload, requiredDependencies) =
            calculateInstallationCounts(from: indexInfo)

        modPackViewModel.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count
        )

        isProcessingModPack = false

        // 3. 安装依赖
        let dependencySuccess =
            await ModPackDependencyInstaller.installVersionDependencies(
                indexInfo: indexInfo,
                gameInfo: tempGameInfo,
                extractedPath: extractedPath
            ) { fileName, completed, total, type in
                Task { @MainActor in
                    modPackViewModel.objectWillChange.send()
                    updateModPackInstallProgress(
                        fileName: fileName,
                        completed: completed,
                        total: total,
                        type: type
                    )
                }
            }

        if !dependencySuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 4. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: gameNameValidator.gameName,
                    gameIcon: AppConstants.defaultGameIcon,
                    selectedGameVersion: indexInfo.gameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    specifiedLoaderVersion: indexInfo.loaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: playerListViewModel,
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

        handleModPackInstallationResult(success: gameSuccess, gameName: gameNameValidator.gameName)
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

    private func updateModPackInstallProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType
    ) {
        switch type {
        case .files:
            modPackViewModel.modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total
            )
        case .dependencies:
            modPackViewModel.modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total
            )
        case .overrides:
            break
        }
    }

    private func handleModPackInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("本地整合包导入完成: \(gameName)")
            dismiss()
        } else {
            Logger.shared.error("本地整合包导入失败: \(gameName)")
            // 清理已创建的游戏文件夹
            Task {
                await cleanupGameDirectories(gameName: gameName)
            }
            let globalError = GlobalError.resource(
                chineseMessage: "本地整合包导入失败",
                i18nKey: "error.resource.local_modpack_import_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            modPackViewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        }
        isProcessingModPack = false
    }

    /// 清理游戏文件夹
    /// - Parameter gameName: 游戏名称
    private func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
            // 不抛出错误，因为这是清理操作，不应该影响主流程
        }
    }

    // MARK: - Public Methods for Parent View

    func handleCancel() {
        if gameSetupService.downloadState.isDownloading {
            modPackDownloadTask?.cancel()
            modPackDownloadTask = nil
        } else {
            dismiss()
        }
    }

    func handleConfirm() {
        modPackDownloadTask?.cancel()
        modPackDownloadTask = Task {
            await importModPack()
        }
    }

    private func updateParentState() {
        isDownloading = gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
            || isProcessingModPack
        isFormValid = selectedModPackFile != nil && modPackIndexInfo != nil && gameNameValidator.isFormValid
    }
}
