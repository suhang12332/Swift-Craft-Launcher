import SwiftUI
import UniformTypeIdentifiers
import UserNotifications



// MARK: - Constants
private enum Constants {
    static let formSpacing: CGFloat = 16
    static let iconSize: CGFloat = 64
    static let cornerRadius: CGFloat = 8
    static let maxImageSize: CGFloat = 1024
    static let versionGridColumns = 6
    static let versionPopoverMinWidth: CGFloat = 320
    static let versionPopoverMaxHeight: CGFloat = 360
    static let versionButtonPadding: CGFloat = 6
    static let versionButtonVerticalPadding: CGFloat = 3
}

// MARK: - GameFormView
struct GameFormView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @StateObject private var downloadState = DownloadState()
    @StateObject private var fabricDownloadState = DownloadState()
    @StateObject private var forgeDownloadState = DownloadState()
    @StateObject private var neoForgeDownloadState = DownloadState()
    @State private var gameName = ""
    @State private var gameIcon = AppConstants.defaultGameIcon
    @State private var iconImage: Image?
    @State private var showImagePicker = false
    @State private var selectedGameVersion = ""
    @State private var versionTime = ""
    @State private var selectedModLoader = "vanilla"
    @State private var mojangVersions: [MojangVersionInfo] = []
    @State private var availableVersions: [String] = []  // 新增：存储可用版本字符串列表
    @State private var fabricLoaderVersion: String = ""
    @State private var downloadTask: Task<Void, Error>? = nil
    @FocusState private var isGameNameFocused: Bool
    @State private var isGameNameDuplicate: Bool = false
    @State private var pendingIconData: Data? = nil
    @State private var pendingIconURL: URL? = nil
    @State private var didInit = false

    // MARK: - Body
    var body: some View {
        CommonSheetView(header: {headerView}, body: {formContentView}, footer: {footerView})
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
            }
        }
    }

    // MARK: - View Components
    private var headerView: some View {
        HStack {
            Text("game.form.title".localized())
                .font(.headline)
            Spacer()
            Image(systemName: "link.badge.plus")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var formContentView: some View {
        VStack {
            gameIconAndVersionSection
            gameNameSection
            if downloadState.isDownloading {
                downloadProgressSection
            }
        }
    }

    private var gameIconAndVersionSection: some View {
        FormSection {
            HStack(alignment: .top, spacing: Constants.formSpacing) {
                gameIconView
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
                    if !downloadState.isDownloading {
                        showImagePicker = true
                    }
                }
                .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
                    if !downloadState.isDownloading {
                        handleImageDrop(providers)
                    } else {
                        false
                    }
                }

            Text("game.form.icon.description".localized())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .disabled(downloadState.isDownloading)
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
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                            .contentShape(Rectangle())
                    case .failure:
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            .background(Color.gray.opacity(0.08))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if let iconURL = AppPaths.profileDirectory(gameName: gameName)?.appendingPathComponent(AppConstants.defaultGameIcon),
                      FileManager.default.fileExists(atPath: iconURL.path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                            .contentShape(Rectangle())
                    case .failure:
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            .background(Color.gray.opacity(0.08))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    .background(Color.gray.opacity(0.08))
            }
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
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
           time: $versionTime,
           onVersionSelected: { version in
               await MinecraftService.fetchVersionTime(for: version)
           }
       )
       .disabled(downloadState.isDownloading)
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
            .disabled(downloadState.isDownloading)
            .onChange(of: selectedModLoader) { _, new in
                Task {
                    let compatibleVersions = await CommonService.compatibleVersions(for: new)
                    await updateAvailableVersions(compatibleVersions)
                }
            }
            .onAppear {
                Task {
                    let compatibleVersions = await CommonService.compatibleVersions(for: selectedModLoader)
                    await updateAvailableVersions(compatibleVersions)
                }
            }
        }
    }

    private var gameNameSection: some View {
        
        FormSection {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("game.form.name".localized())
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        if isGameNameDuplicate {
                            Spacer()
                            Text("game.form.name.duplicate".localized())
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.trailing, 4)
                        }
                    }
                    TextField("game.form.name.placeholder".localized(), text: $gameName)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.primary)
                        .focused($isGameNameFocused)
                        .disabled(downloadState.isDownloading)
                }
                .disabled(downloadState.isDownloading)
                
                
            }
        }
        .onChange(of: gameName) { old,newName in
            Task {
                let isDuplicate = await checkGameNameDuplicate(newName)
                if isDuplicate != isGameNameDuplicate {
                    isGameNameDuplicate = isDuplicate
                }
            }
        }
    }

    private var downloadProgressSection: some View {
        VStack(spacing: 24) {
            FormSection {
                DownloadProgressRow(
                    title: "download.core.title".localized(),
                    progress: downloadState.coreProgress,
                    currentFile: downloadState.currentCoreFile,
                    completed: downloadState.coreCompletedFiles,
                    total: downloadState.coreTotalFiles,
                    version: nil
                )
            }
            FormSection {
                DownloadProgressRow(
                    title: "download.resources.title".localized(),
                    progress: downloadState.resourcesProgress,
                    currentFile: downloadState.currentResourceFile,
                    completed: downloadState.resourcesCompletedFiles,
                    total: downloadState.resourcesTotalFiles,
                    version: nil
                )
            }
            if selectedModLoader.lowercased() == "fabric" || selectedModLoader.lowercased() == "quilt" {
                FormSection {
                    DownloadProgressRow(
                        title: (selectedModLoader.lowercased() == "fabric" ? "fabric.loader.title" : "quilt.loader.title").localized(),
                        progress: fabricDownloadState.coreProgress,
                        currentFile: fabricDownloadState.currentCoreFile,
                        completed: fabricDownloadState.coreCompletedFiles,
                        total: fabricDownloadState.coreTotalFiles,
                        version: fabricLoaderVersion
                    )
                }
            }
            if selectedModLoader.lowercased() == "forge" {
                FormSection {
                    DownloadProgressRow(
                        title: "forge.loader.title".localized(),
                        progress: forgeDownloadState.coreProgress,
                        currentFile: forgeDownloadState.currentCoreFile,
                        completed: forgeDownloadState.coreCompletedFiles,
                        total: forgeDownloadState.coreTotalFiles,
                        version: nil
                    )
                }
            }
            if selectedModLoader.lowercased() == "neoforge" {
                FormSection {
                    DownloadProgressRow(
                        title: "neoforge.loader.title".localized(),
                        progress: neoForgeDownloadState.coreProgress,
                        currentFile: neoForgeDownloadState.currentCoreFile,
                        completed: neoForgeDownloadState.coreCompletedFiles,
                        total: neoForgeDownloadState.coreTotalFiles,
                        version: nil
                    )
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
    
    private var cancelButton: some View {
        Button("common.cancel".localized()) {
            if downloadState.isDownloading, let task = downloadTask {
                task.cancel()
            } else {
                dismiss()
            }
        }
        .keyboardShortcut(.cancelAction)
    }
    
    private var confirmButton: some View {
        Button {
            downloadTask = Task {
                await saveGame()
            }
        } label: {
            HStack {
                if downloadState.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("common.confirm".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isFormValid || downloadState.isDownloading)
    }

    // MARK: - Helper Methods
    
    /// 更新可用版本并设置默认选择
    private func updateAvailableVersions(_ versions: [String]) async {
        await MainActor.run {
            self.availableVersions = versions
            // 如果当前选中的版本不在兼容版本列表中，选择第一个兼容版本
             if !versions.contains(self.selectedGameVersion) && !versions.isEmpty {
                 self.selectedGameVersion = versions.first!
             }
        }
        
        // 获取当前选中版本的时间信息
        if !versions.isEmpty {
            let targetVersion = versions.contains(self.selectedGameVersion) ? self.selectedGameVersion : versions.first!
            let timeString = await MinecraftService.fetchVersionTime(for: targetVersion)
            await MainActor.run {
                self.versionTime = timeString
            }
        }
    }
    
    /// 初始化版本选择器
    private func initializeVersionPicker() async {
        let compatibleVersions = await CommonService.compatibleVersions(for: selectedModLoader)
        await updateAvailableVersions(compatibleVersions)
    }

    private var isFormValid: Bool {
        !gameName.isEmpty && !isGameNameDuplicate
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
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
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
            handleNonCriticalError(globalError, message: "error.image.pick.failed".localized())
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            Logger.shared.error("图片拖放失败：没有提供者")
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error = error {
                    DispatchQueue.main.async {
                        let globalError = GlobalError.from(error)
                        handleNonCriticalError(globalError, message: "error.image.load.drag.failed".localized())
                    }
                    return
                }

                if let data = data {
                    DispatchQueue.main.async {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
                        do {
                            try data.write(to: tempURL)
                            pendingIconURL = tempURL
                            pendingIconData = data
                            iconImage = nil
                        } catch {
                            handleNonCriticalError(
                                GlobalError.fileSystem(
                                    chineseMessage: "图片保存失败",
                                    i18nKey: "error.filesystem.image_save_failed",
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
        guard playerListViewModel.currentPlayer != nil else {
            Logger.shared.error("无法保存游戏，因为没有选择当前玩家。")
            handleNonCriticalError(
                GlobalError.configuration(
                    chineseMessage: "没有选择当前玩家",
                    i18nKey: "error.configuration.no_current_player",
                    level: .popup
                ),
                message: "error.no.current.player.title".localized()
            )
            return
        }
        await MainActor.run { 
            isGameNameFocused = false 
            downloadState.reset() 
            downloadState.isDownloading = true // 立即进入 loading
        }
        defer { Task { @MainActor in downloadState.isDownloading = false } } // 所有分支最后都恢复
        
        // --- 新增图片写入逻辑 ---
        if let data = pendingIconData, !gameName.isEmpty,
           let profileDir = AppPaths.profileDirectory(gameName: gameName) {
            let iconURL = profileDir.appendingPathComponent(AppConstants.defaultGameIcon)
            do {
                try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
                try data.write(to: iconURL)
            } catch {
                handleNonCriticalError(
                    GlobalError.fileSystem(
                        chineseMessage: "图片保存失败",
                        i18nKey: "error.filesystem.image_save_failed",
                        level: .notification
                    ),
                    message: "error.image.save.failed".localized()
                )
            }
        }
        
        var gameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameName,
            gameIcon: gameIcon,
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: selectedModLoader,
            isUserAdded: true
        )
        Logger.shared.info("开始为游戏下载文件: \(gameInfo.gameName)")
        do {
            guard let mojangVersion = await MinecraftService.getCurrentVersion(currentVersion: selectedGameVersion) else {
                handleNonCriticalError(
                    GlobalError.resource(
                        chineseMessage: "版本未找到: \(selectedGameVersion)",
                        i18nKey: "error.resource.version_not_found",
                        level: .notification
                    ),
                    message: "error.version.not.found".localized()
                )
                return
            }
            let modLoaderResult = try await setupModLoaderIfNeeded()
            let downloadedManifest = try await fetchMojangManifest(from: mojangVersion.url)
            let fileManager = try await setupFileManager(manifest: downloadedManifest, modLoader: gameInfo.modLoader)
            try await startDownloadProcess(fileManager: fileManager, manifest: downloadedManifest)
            // 传递 modLoaderResult 给 finalizeGameInfo
            gameInfo = await finalizeGameInfo(
                gameInfo: gameInfo,
                manifest: downloadedManifest,
                fabricResult: selectedModLoader.lowercased() == "fabric"
                    ? modLoaderResult : nil,
                forgeResult: selectedModLoader.lowercased() == "forge"
                    ? modLoaderResult : nil,
                neoForgeResult: selectedModLoader.lowercased() == "neoforge"
                    ? modLoaderResult : nil,
                quiltResult: selectedModLoader.lowercased() == "quilt"
                    ? modLoaderResult : nil
            )
            gameRepository.addGameSilently(gameInfo)
            NotificationManager.sendSilently(
                title: "notification.download.complete.title".localized(),
                body: String(format: "notification.download.complete.body".localized(), gameInfo.gameName, gameInfo.gameVersion, gameInfo.modLoader)
            )
            await MainActor.run { fabricLoaderVersion = "" }
            await handleDownloadSuccess()
        } catch is CancellationError {
            await handleDownloadCancellation()
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
        await MainActor.run { downloadTask = nil }
    }

    private func fetchMojangManifest(from url: URL) async throws -> MinecraftVersionManifest {
        return try await MinecraftService.fetchMojangManifestThrowing(from: url)
    }

    private func setupFileManager(manifest: MinecraftVersionManifest, modLoader: String) async throws -> MinecraftFileManager {
        let nativesDir = AppPaths.nativesDirectory
        try FileManager.default.createDirectory(at: nativesDir!, withIntermediateDirectories: true)
        Logger.shared.info("创建目录：\(nativesDir!.path)")
        return MinecraftFileManager()
    }

    private func startDownloadProcess(fileManager: MinecraftFileManager, manifest: MinecraftVersionManifest) async throws {
        await MainActor.run {
            downloadState.startDownload(
                coreTotalFiles: 1 + manifest.libraries.count + 1,
                resourcesTotalFiles: 0
            )
        }

        fileManager.onProgressUpdate = { fileName, completed, total, type in
            Task { @MainActor in
                downloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: type)
            }
        }

        // 使用静默版本的 API，避免抛出异常
        let success = await fileManager.downloadVersionFiles(manifest: manifest, gameName: gameName)
        if !success {
            throw GlobalError.download(
                chineseMessage: "下载 Minecraft 版本文件失败",
                i18nKey: "error.download.minecraft_version_failed",
                level: .notification
            )
        }
    }
    
    private func setupModLoaderIfNeeded() async throws -> (loaderVersion: String, classpath: String, mainClass: String)? {
        let loaderType = selectedModLoader.lowercased()
        let handler: (any ModLoaderHandler.Type)?
        switch loaderType {
        case "fabric":
            handler = FabricLoaderService.self
        case "forge":
            handler = ForgeLoaderService.self
        case "neoforge":
            handler = NeoForgeLoaderService.self
        case "quilt":
            handler = QuiltLoaderService.self
        default:
            handler = nil
        }
        guard let handler else { return nil }
        
        // 直接创建 GameVersionInfo，不依赖 mojangVersions
        let gameInfo = GameVersionInfo(
            gameName: gameName,
            gameIcon: gameIcon,
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: selectedModLoader,
            isUserAdded: true
        )
        
        return await handler.setup(
            for: selectedGameVersion,
            gameInfo: gameInfo,
            onProgressUpdate: { fileName, completed, total in
                Task { @MainActor in
                    if loaderType == "fabric" {
                        fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                    } else if loaderType == "forge" {
                        forgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                    } else if loaderType == "neoforge" {
                        neoForgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                    } else if loaderType == "quilt" {
                        fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                    }
                }
            }
        )
    }
    
    private func finalizeGameInfo(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest,
        fabricResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        forgeResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        neoForgeResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        quiltResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil
    ) async -> GameVersionInfo {
        var updatedGameInfo = gameInfo
        updatedGameInfo.assetIndex = manifest.assetIndex.id
        updatedGameInfo.javaVersion = manifest.javaVersion.majorVersion
        switch selectedModLoader.lowercased() {
        case "fabric", "quilt":
            if let result = selectedModLoader.lowercased() == "fabric" ? fabricResult : quiltResult {
                updatedGameInfo.modVersion = result.loaderVersion
                updatedGameInfo.modClassPath = result.classpath
                updatedGameInfo.mainClass = result.mainClass
                if selectedModLoader.lowercased() == "fabric" {
                    if let fabricLoader = try? await FabricLoaderService.fetchLatestStableLoaderVersion(for: selectedGameVersion) {
                        let jvmArgs = fabricLoader.arguments.jvm ?? []
                        updatedGameInfo.modJvm = jvmArgs
                        let gameArgs = fabricLoader.arguments.game ?? []
                        updatedGameInfo.gameArguments = gameArgs
                    }
                }else{
                    if let quiltLoader = try? await QuiltLoaderService.fetchLatestStableLoaderVersion(for: selectedGameVersion) {
                        let jvmArgs = quiltLoader.arguments.jvm ?? []
                        updatedGameInfo.modJvm = jvmArgs
                        let gameArgs = quiltLoader.arguments.game ?? []
                        updatedGameInfo.gameArguments = gameArgs
                    }
                }
                
                
            }
        case "forge":
            if let result = forgeResult {
                updatedGameInfo.modVersion = result.loaderVersion
                updatedGameInfo.modClassPath = result.classpath
                updatedGameInfo.mainClass = result.mainClass
                // 自动补充
  
                if let forgeLoader = try? await ForgeLoaderService.fetchLatestForgeProfile(for: selectedGameVersion) {
                    let gameArgs = forgeLoader.arguments.game ?? []
                    updatedGameInfo.gameArguments = gameArgs
                    let jvmArgs = forgeLoader.arguments.jvm ?? []
                    updatedGameInfo.modJvm = jvmArgs.map { arg in
                        arg.replacingOccurrences(of: "${version_name}", with: selectedGameVersion)
                            .replacingOccurrences(of: "${classpath_separator}", with: ":")
                            .replacingOccurrences(of: "${library_directory}", with: AppPaths.librariesDirectory!.path)
                    }
                }
            }
        case "neoforge":
            if let result = neoForgeResult {
                updatedGameInfo.modVersion = result.loaderVersion
                updatedGameInfo.modClassPath = result.classpath
                updatedGameInfo.mainClass = result.mainClass
                // 自动补充 
  
                if let neoForgeLoader = try? await NeoForgeLoaderService.fetchLatestNeoForgeProfile(for: selectedGameVersion) {
                    let gameArgs = neoForgeLoader.arguments.game ?? []
                    updatedGameInfo.gameArguments = gameArgs
                    
                    let jvmArgs = neoForgeLoader.arguments.jvm ?? []
                    updatedGameInfo.modJvm = jvmArgs.map { arg in
                        arg.replacingOccurrences(of: "${version_name}", with: selectedGameVersion)
                            .replacingOccurrences(of: "${classpath_separator}", with: ":")
                            .replacingOccurrences(of: "${library_directory}", with: AppPaths.librariesDirectory!.path)
                    }
                }
            }
        default:
            updatedGameInfo.mainClass = manifest.mainClass
        }
        let username = playerListViewModel.currentPlayer?.name ?? "Player"
        let uuid = gameInfo.id
        let launcherBrand = Bundle.main.appName
        let launcherVersion = Bundle.main.fullVersion
        updatedGameInfo.launchCommand = MinecraftLaunchCommandBuilder.build(
            manifest: manifest,
            gameInfo: updatedGameInfo,
            username: username,
            uuid: uuid,
            launcherBrand: launcherBrand,
            launcherVersion: launcherVersion
        )
        return updatedGameInfo
    }

    private func handleDownloadSuccess() async {
        Logger.shared.info("下载和保存成功")
        await MainActor.run { dismiss() }
    }

    private func handleDownloadCancellation() async {
        Logger.shared.info("游戏下载任务已取消")
        await MainActor.run {
            downloadState.reset()
            dismiss()
        }
    }

    private func handleDownloadFailure(error: GlobalError,message: String) async {
        Logger.shared.error("保存游戏或下载文件时出错：\(error.chineseMessage)")
        GlobalErrorHandler.shared.handle(error)
        await MainActor.run { downloadState.reset() }
    }

    private func checkGameNameDuplicate(_ name: String) async -> Bool {
        guard !name.isEmpty,
              let profilesDir = AppPaths.profileRootDirectory else { return false }
        let fileManager = FileManager.default
        let gameDir = profilesDir.appendingPathComponent(name)
        if fileManager.fileExists(atPath: gameDir.path) {
            return true
        }
        return false
    }
}


