import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Constants
private enum Constants {
    static let formSpacing: CGFloat = 16
    static let iconSize: CGFloat = 80
    static let cornerRadius: CGFloat = 12
    static let maxImageSize: CGFloat = 1024
    static let versionGridColumns = 6
    static let versionPopoverMinWidth: CGFloat = 320
    static let versionPopoverMaxHeight: CGFloat = 360
    static let versionButtonPadding: CGFloat = 6
    static let versionButtonVerticalPadding: CGFloat = 3
}

// MARK: - GameCreationView
struct GameCreationView: View {
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

    @State private var gameIcon = AppConstants.defaultGameIcon
    @State private var iconImage: Image?
    @State private var showImagePicker = false
    @State private var selectedGameVersion = ""
    @State private var versionTime = ""
    @State private var selectedModLoader = "vanilla"
    @State private var selectedLoaderVersion = ""  // 新增：选择的加载器版本
    @State private var availableLoaderVersions: [String] = []  // 新增：可用的加载器版本列表
    @State private var mojangVersions: [MojangVersionInfo] = []
    @State private var availableVersions: [String] = []  // 新增：存储可用版本字符串列表
    @State private var downloadTask: Task<Void, Error>?
    @State private var pendingIconData: Data?
    @State private var pendingIconURL: URL?
    @State private var didInit = false

    // MARK: - Body
    var body: some View {
        formContentView
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleImagePickerResult(result)
        }
        .onAppear {
            if !didInit {
                didInit = true
                Task {
                    await initializeVersionPicker()
                }
            }
            updateParentState()
        }
        .onChange(of: gameNameValidator.gameName) {
            updateParentState()
        }
        .onChange(of: gameNameValidator.isGameNameDuplicate) {
            updateParentState()
        }
        .onChange(of: gameSetupService.downloadState.isDownloading) {
            updateParentState()
        }
        .onChange(of: triggerConfirm) {
            if triggerConfirm {
                handleConfirm()
                triggerConfirm = false
            }
        }
        .onChange(of: selectedLoaderVersion) {
            updateParentState()
        }
    }

    // MARK: - View Components

    private var formContentView: some View {
        VStack {
            gameIconAndVersionSection
            if selectedModLoader != "vanilla" {
                loaderVersionPicker
            }
            gameNameSection

            if shouldShowProgress {
                downloadProgressSection
            }
        }
    }

    private var gameIconAndVersionSection: some View {
        FormSection {
            HStack(alignment: .top, spacing: Constants.formSpacing) {
                gameIconView
                    .padding(.trailing, 6)
                gameVersionAndLoaderView
            }
        }
    }

    private var gameIconView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.icon".localized())
                .font(.subheadline)
                .foregroundColor(.primary)

            iconContainer
                .onTapGesture {
                    if !gameSetupService.downloadState.isDownloading {
                        showImagePicker = true
                    }
                }
                .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
                    if !gameSetupService.downloadState.isDownloading {
                        handleImageDrop(providers)
                    } else {
                        false
                    }
                }
        }
        .disabled(gameSetupService.downloadState.isDownloading)
    }

    private var iconContainer: some View {
        ZStack {
            if let url = pendingIconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                            .frame(
                                width: Constants.iconSize,
                                height: Constants.iconSize
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: Constants.cornerRadius
                                )
                            )
                            .contentShape(Rectangle())
                    case .failure:
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(
                                Color.accentColor.opacity(0.3),
                                lineWidth: 1
                            )
                            .background(Color.gray.opacity(0.08))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.none)
                        .fontWeight(.regular)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(emptyDropBackground())
            }
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
    }

    private var gameVersionAndLoaderView: some View {
        VStack(alignment: .leading, spacing: Constants.formSpacing) {
            modLoaderPicker
            versionPicker
        }
    }

    private var versionPicker: some View {
        CustomVersionPicker(
            selected: $selectedGameVersion,
            availableVersions: availableVersions,
            time: $versionTime
        ) { version in
            await MinecraftService.fetchVersionTime(for: version)
        }
        .disabled(gameSetupService.downloadState.isDownloading)
    }

    private var modLoaderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.modloader".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            Picker("", selection: $selectedModLoader) {
                ForEach(AppConstants.modLoaders, id: \.self) {
                    Text($0).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .disabled(gameSetupService.downloadState.isDownloading)
            .onChange(of: selectedModLoader) { _, new in
                Task {
                    let compatibleVersions =
                        await CommonService.compatibleVersions(for: new)
                    await updateAvailableVersions(compatibleVersions)

                    // 更新加载器版本列表
                    if new != "vanilla" && !selectedGameVersion.isEmpty {
                        await updateLoaderVersions(for: new, gameVersion: selectedGameVersion)
                    } else {
                        await MainActor.run {
                            availableLoaderVersions = []
                            selectedLoaderVersion = ""
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    let compatibleVersions =
                        await CommonService.compatibleVersions(
                            for: selectedModLoader
                        )
                    await updateAvailableVersions(compatibleVersions)
                }
            }
        }
    }

    private var loaderVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.loader.version".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            Picker("", selection: $selectedLoaderVersion) {
                ForEach(availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .disabled(gameSetupService.downloadState.isDownloading || availableLoaderVersions.isEmpty)
            .onChange(of: selectedGameVersion) { _, newGameVersion in
                Task {
                    await updateLoaderVersions(for: selectedModLoader, gameVersion: newGameVersion)
                }
            }
        }
    }

    private var gameNameSection: some View {
        FormSection {
            GameNameInputView(
                gameName: $gameNameValidator.gameName,
                isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                isDisabled: gameSetupService.downloadState.isDownloading,
                gameSetupService: gameSetupService
            )
        }
    }

    private var downloadProgressSection: some View {
        VStack(spacing: 24) {
            gameDownloadProgressView
        }
    }

    private var gameDownloadProgressView: some View {
        VStack(spacing: 24) {
            FormSection {
                DownloadProgressRow(
                    title: "download.core.title".localized(),
                    progress: gameSetupService.downloadState.coreProgress,
                    currentFile: gameSetupService.downloadState.currentCoreFile,
                    completed: gameSetupService.downloadState
                        .coreCompletedFiles,
                    total: gameSetupService.downloadState.coreTotalFiles,
                    version: nil
                )
            }
            FormSection {
                DownloadProgressRow(
                    title: "download.resources.title".localized(),
                    progress: gameSetupService.downloadState.resourcesProgress,
                    currentFile: gameSetupService.downloadState
                        .currentResourceFile,
                    completed: gameSetupService.downloadState
                        .resourcesCompletedFiles,
                    total: gameSetupService.downloadState.resourcesTotalFiles,
                    version: nil
                )
            }

            if selectedModLoader.lowercased() == "fabric" || selectedModLoader.lowercased() == "quilt" {
                FormSection {
                    DownloadProgressRow(
                        title: (selectedModLoader.lowercased() == "fabric"
                            ? "fabric.loader.title" : "quilt.loader.title")
                            .localized(),
                        progress: gameSetupService.fabricDownloadState
                            .coreProgress,
                        currentFile: gameSetupService.fabricDownloadState
                            .currentCoreFile,
                        completed: gameSetupService.fabricDownloadState
                            .coreCompletedFiles,
                        total: gameSetupService.fabricDownloadState
                            .coreTotalFiles,
                        version: nil
                    )
                }
            }
            if selectedModLoader.lowercased() == "forge" {
                FormSection {
                    DownloadProgressRow(
                        title: "forge.loader.title".localized(),
                        progress: gameSetupService.forgeDownloadState
                            .coreProgress,
                        currentFile: gameSetupService.forgeDownloadState
                            .currentCoreFile,
                        completed: gameSetupService.forgeDownloadState
                            .coreCompletedFiles,
                        total: gameSetupService.forgeDownloadState
                            .coreTotalFiles,
                        version: nil
                    )
                }
            }
            if selectedModLoader.lowercased() == "neoforge" {
                FormSection {
                    DownloadProgressRow(
                        title: "neoforge.loader.title".localized(),
                        progress: gameSetupService.neoForgeDownloadState
                            .coreProgress,
                        currentFile: gameSetupService.neoForgeDownloadState
                            .currentCoreFile,
                        completed: gameSetupService.neoForgeDownloadState
                            .coreCompletedFiles,
                        total: gameSetupService.neoForgeDownloadState
                            .coreTotalFiles,
                        version: nil
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
    }

    // MARK: - Helper Methods

    /// 更新可用版本并设置默认选择
    private func updateAvailableVersions(_ versions: [String]) async {
        await MainActor.run {
            self.availableVersions = versions
            // 如果当前选中的版本不在兼容版本列表中，选择第一个兼容版本
            if !versions.contains(self.selectedGameVersion) && !versions.isEmpty {
                self.selectedGameVersion = versions.first ?? ""
            }
        }

        // 获取当前选中版本的时间信息
        if !versions.isEmpty {
            let targetVersion =
                versions.contains(self.selectedGameVersion)
                ? self.selectedGameVersion : (versions.first ?? "")
            let timeString = await MinecraftService.fetchVersionTime(
                for: targetVersion
            )
            await MainActor.run {
                self.versionTime = timeString
            }
        }
    }

    /// 初始化版本选择器
    private func initializeVersionPicker() async {
        let compatibleVersions = await CommonService.compatibleVersions(
            for: selectedModLoader
        )
        await updateAvailableVersions(compatibleVersions)
    }

    /// 更新加载器版本列表
    /// - Parameters:
    ///   - loader: 加载器类型
    ///   - gameVersion: 游戏版本
    private func updateLoaderVersions(for loader: String, gameVersion: String) async {
        guard loader != "vanilla" && !gameVersion.isEmpty else {
            await MainActor.run {
                availableLoaderVersions = []
                selectedLoaderVersion = ""
            }
            return
        }

        var versions: [String] = []

        switch loader.lowercased() {
        case "fabric":
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map { $0.loader.version }
        case "forge":
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 Forge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case "neoforge":
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 NeoForge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case "quilt":
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map { $0.loader.version }
        default:
            versions = []
        }

        await MainActor.run {
            availableLoaderVersions = versions
            // 如果当前选中的版本不在列表中，选择第一个版本
            if !versions.contains(selectedLoaderVersion) && !versions.isEmpty {
                selectedLoaderVersion = versions.first ?? ""
            } else if versions.isEmpty {
                selectedLoaderVersion = ""
            }
        }
    }

    private func handleNonCriticalError(_ error: GlobalError, message: String) {
        Logger.shared.error("\(message): \(error.chineseMessage)")
        GlobalErrorHandler.shared.handle(error)
    }

    private func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                handleNonCriticalError(
                    GlobalError.validation(
                        chineseMessage: "未选择文件",
                        i18nKey: "error.validation.no_file_selected",
                        level: .notification
                    ),
                    message: "error.image.pick.failed".localized()
                )
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                handleNonCriticalError(
                    GlobalError.fileSystem(
                        chineseMessage: "无法访问所选文件",
                        i18nKey: "error.filesystem.file_access_failed",
                        level: .notification
                    ),
                    message: "error.image.access.failed".localized()
                )
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            Task { @MainActor in
                do {
                    let data = try Data(contentsOf: url)
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".png")
                    try data.write(to: tempURL)
                    pendingIconURL = tempURL
                    pendingIconData = data
                    iconImage = nil
                } catch {
                    handleNonCriticalError(
                        GlobalError.fileSystem(
                            chineseMessage: "无法读取图片文件",
                            i18nKey: "error.filesystem.image_read_failed",
                            level: .notification
                        ),
                        message: "error.image.read.failed".localized()
                    )
                }
            }
        case .failure(let error):
            let globalError = GlobalError.from(error)
            handleNonCriticalError(
                globalError,
                message: "error.image.pick.failed".localized()
            )
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            Logger.shared.error("图片拖放失败：没有提供者")
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, error in
                if let error = error {
                    DispatchQueue.main.async {
                        let globalError = GlobalError.from(error)
                        handleNonCriticalError(
                            globalError,
                            message: "error.image.load.drag.failed".localized()
                        )
                    }
                    return
                }

                if let data = data {
                    DispatchQueue.main.async {
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".png")
                        do {
                            try data.write(to: tempURL)
                            pendingIconURL = tempURL
                            pendingIconData = data
                            iconImage = nil
                        } catch {
                            handleNonCriticalError(
                                GlobalError.fileSystem(
                                    chineseMessage: "图片保存失败",
                                    i18nKey:
                                        "error.filesystem.image_save_failed",
                                    level: .notification
                                ),
                                message: "error.image.save.failed".localized()
                            )
                        }
                    }
                }
            }
            return true
        }
        Logger.shared.warning("图片拖放失败：不支持的类型")
        return false
    }

    // MARK: - Game Save Methods
    private func saveGame() async {
        // 对于非vanilla加载器，如果没有选择版本，则不允许保存
        let loaderVersion = selectedModLoader == "vanilla" ? selectedModLoader : selectedLoaderVersion

        await gameSetupService.saveGame(
            gameName: gameNameValidator.gameName,
            gameIcon: gameIcon,
            selectedGameVersion: selectedGameVersion,
            selectedModLoader: selectedModLoader,
            specifiedLoaderVersion: loaderVersion,
            pendingIconData: pendingIconData,
            playerListViewModel: playerListViewModel,
            gameRepository: gameRepository,
            onSuccess: {
                Task { @MainActor in
                    self.dismiss()
                }
            },
            onError: { error, message in
                Task { @MainActor in
                    self.handleNonCriticalError(error, message: message)
                }
            }
        )
    }

    // MARK: - Public Methods for Parent View

    func handleCancel() {
        if gameSetupService.downloadState.isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
        } else {
            dismiss()
        }
    }

    func handleConfirm() {
        downloadTask?.cancel()
        downloadTask = Task {
            await saveGame()
        }
    }

    private func updateParentState() {
        isDownloading = gameSetupService.downloadState.isDownloading

        // 检查表单是否有效：基本验证 + 加载器版本验证
        let isLoaderVersionValid = selectedModLoader == "vanilla" || !selectedLoaderVersion.isEmpty
        isFormValid = gameNameValidator.isFormValid && isLoaderVersionValid
    }
}
