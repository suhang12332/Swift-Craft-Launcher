//
//  LauncherImportViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// 启动器导入 ViewModel
@MainActor
class LauncherImportViewModel: BaseGameFormViewModel {
    
    // MARK: - Published Properties
    
    @Published var selectedLauncherType: ImportLauncherType = .multiMC
    @Published var selectedInstancePath: URL?  // 直接选择的实例路径（所有启动器都使用此方式）
    @Published var isImporting = false
    @Published var importProgress: (fileName: String, completed: Int, total: Int)?
    
    // MARK: - Private Properties
    
    private var gameRepository: GameRepository?
    private var playerListViewModel: PlayerListViewModel?
    
    // MARK: - Initialization
    
    override init(configuration: GameFormConfiguration) {
        super.init(configuration: configuration)
    }
    
    // MARK: - Setup Methods
    
    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
        updateParentState()
    }
    
    // MARK: - Override Methods
    
    override func performConfirmAction() async {
        // 所有启动器都直接使用 selectedInstancePath
        if let instancePath = selectedInstancePath {
            startDownloadTask {
                await self.importSelectedInstancePath(instancePath)
            }
        }
    }
    
    override func handleCancel() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }
    
    override func performCancelCleanup() async {
        // 清理已创建的游戏文件夹
        if let instancePath = selectedInstancePath {
            // 从实例路径推断启动器基础路径
            let basePath = inferBasePath(from: instancePath)
            
            let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
            if let info = try? parser.parseInstance(at: instancePath, basePath: basePath) {
                do {
                    let fileManager = MinecraftFileManager()
                    try fileManager.cleanupGameDirectories(gameName: info.gameName)
                } catch {
                    Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }
    
    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading || isImporting
    }
    
    override func computeIsFormValid() -> Bool {
        // 所有启动器都检查 selectedInstancePath
        guard selectedInstancePath != nil && gameNameValidator.isFormValid else {
            return false
        }
        
        // 检查 Mod Loader 是否支持
        return isModLoaderSupported
    }
    
    // MARK: - Instance Validation
    
    /// 自动填充游戏名到输入框（如果输入框为空）
    func autoFillGameNameIfNeeded() {
        guard let instancePath = selectedInstancePath else { return }
        
        // 如果游戏名已经填写，不自动填充
        guard gameNameValidator.gameName.isEmpty else { return }
        
        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        
        // 解析实例信息并填充游戏名
        if let info = try? parser.parseInstance(at: instancePath, basePath: basePath) {
            gameNameValidator.gameName = info.gameName
        }
    }
    
    /// 检查 Mod Loader 是否支持，如果不支持则显示通知
    func checkAndNotifyUnsupportedModLoader() {
        guard let info = currentInstanceInfo else { return }
        
        // 检查 Mod Loader 是否支持
        guard !AppConstants.modLoaders.contains(info.modLoader.lowercased()) else { return }
        
        // 如果不支持，显示通知
        let supportedModLoadersList = AppConstants.modLoaders.joined(separator: "、")
        let instanceName = selectedInstancePath?.lastPathComponent ?? "Unknown"
        let chineseMessage = "实例 \(instanceName) 使用了不支持的 Mod Loader (\(info.modLoader))，仅支持 \(supportedModLoadersList)"
        
        GlobalErrorHandler.shared.handle(
            GlobalError.fileSystem(
                chineseMessage: chineseMessage,
                i18nKey: "error.filesystem.unsupported_mod_loader",
                level: .notification
            )
        )
    }
    
    /// 验证选择的实例文件夹是否有效
    /// 所有启动器都需要直接选择实例文件夹
    func validateInstance(at instancePath: URL) -> Bool {
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        let fileManager = FileManager.default
        
        // 检查路径是否存在且为目录
        guard fileManager.fileExists(atPath: instancePath.path) else {
            return false
        }
        
        let resourceValues = try? instancePath.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues?.isDirectory == true else {
            return false
        }
        
        // 验证是否为有效实例
        return parser.isValidInstance(at: instancePath)
    }
    
    // MARK: - Import Methods
    
    /// 直接从路径导入实例（所有启动器都使用此方法）
    private func importSelectedInstancePath(_ instancePath: URL) async {
        guard let gameRepository = gameRepository else { return }
        
        isImporting = true
        defer { isImporting = false }
        
        let instanceName = instancePath.lastPathComponent
        
        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)
        
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        
        // 解析实例信息
        let instanceInfo: ImportInstanceInfo
        do {
            guard let parsedInfo = try parser.parseInstance(at: instancePath, basePath: basePath) else {
                Logger.shared.error("解析实例失败: \(instanceName) - 返回 nil")
                GlobalErrorHandler.shared.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "解析实例 \(instanceName) 失败：无法获取实例信息",
                        i18nKey: "error.filesystem.parse_instance_failed",
                        level: .notification
                    )
                )
                return
            }
            instanceInfo = parsedInfo
        } catch {
            Logger.shared.error("解析实例失败: \(instanceName) - \(error.localizedDescription)")
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "解析实例 \(instanceName) 失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.parse_instance_failed",
                    level: .notification
                )
            )
            return
        }
        
        // 验证实例必须有版本
        guard !instanceInfo.gameVersion.isEmpty else {
            Logger.shared.error("实例 \(instanceName) 没有游戏版本")
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "实例 \(instanceName) 没有游戏版本，无法导入",
                    i18nKey: "error.filesystem.instance_no_version",
                    level: .notification
                )
            )
            return
        }
        
        // 验证 Mod Loader 是否支持（错误已在 checkAndNotifyUnsupportedModLoader 中显示，这里只记录日志）
        guard AppConstants.modLoaders.contains(instanceInfo.modLoader.lowercased()) else {
            Logger.shared.error("实例 \(instanceName) 使用了不支持的 Mod Loader: \(instanceInfo.modLoader)")
            return
        }
        
        // 生成游戏名称（如果用户没有自定义）
        let finalGameName = gameNameValidator.gameName.isEmpty
            ? instanceInfo.gameName
            : gameNameValidator.gameName
        
        // 1. 调用下载逻辑
        let downloadSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: finalGameName,
                    gameIcon: AppConstants.defaultGameIcon,
                    selectedGameVersion: instanceInfo.gameVersion,
                    selectedModLoader: instanceInfo.modLoader,
                    specifiedLoaderVersion: instanceInfo.modLoaderVersion,
                    pendingIconData: nil,  // 从启动器导入时不导入图标
                    playerListViewModel: playerListViewModel,
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Logger.shared.error("游戏下载失败: \(message)")
                        GlobalErrorHandler.shared.handle(error)
                        continuation.resume(returning: false)
                    }
                )
            }
        }
        
        if !downloadSuccess {
            Logger.shared.error("导入实例失败: \(instanceName)")
            return
        }
        
        // 2. 复制游戏目录
        let targetDirectory = AppPaths.profileDirectory(gameName: finalGameName)
        
        do {
            try await InstanceFileCopier.copyGameDirectory(
                from: instanceInfo.sourceGameDirectory,
                to: targetDirectory,
                launcherType: instanceInfo.launcherType,
                onProgress: { fileName, completed, total in
                    Task { @MainActor in
                        self.importProgress = (fileName, completed, total)
                    }
                }
            )
            
            Logger.shared.info("成功导入实例: \(instanceName) -> \(finalGameName)")
            

        } catch {
            Logger.shared.error("复制游戏目录失败: \(error.localizedDescription)")
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "复制游戏目录失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.copy_game_directory_failed",
                    level: .notification
                )
            )
        }
        
        // 导入完成
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 从实例路径推断启动器基础路径
    /// 向上查找包含 icons 文件夹的目录，如果找不到则使用实例路径的父目录的父目录
    private func inferBasePath(from instancePath: URL) -> URL {
        let fileManager = FileManager.default
        var currentPath = instancePath
        
        // 向上查找，最多查找5层
        for _ in 0..<5 {
            let iconsPath = currentPath.appendingPathComponent("icons")
            if fileManager.fileExists(atPath: iconsPath.path) {
                return currentPath
            }
            let parentPath = currentPath.deletingLastPathComponent()
            if parentPath.path == currentPath.path {
                // 已经到达根目录
                break
            }
            currentPath = parentPath
        }
        
        // 如果找不到 icons 文件夹，使用实例路径的父目录的父目录作为 fallback
        return instancePath.deletingLastPathComponent().deletingLastPathComponent()
    }
    
    /// 下载图标
    private func downloadIcon(from urlString: String, instanceName: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 缓存图标
            let cacheDir = AppPaths.appCache.appendingPathComponent("imported_icons")
            try FileManager.default.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
            let cachedPath = cacheDir.appendingPathComponent("\(instanceName).png")
            try data.write(to: cachedPath)
            
            return data
        } catch {
            Logger.shared.warning("下载图标失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Computed Properties
    
    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading || isImporting
    }
    
    var hasSelectedInstance: Bool {
        selectedInstancePath != nil
    }
    
    /// 获取当前选中实例的信息
    var currentInstanceInfo: ImportInstanceInfo? {
        guard let instancePath = selectedInstancePath else { return nil }
        
        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)
        
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        do {
            if let info = try parser.parseInstance(at: instancePath, basePath: basePath) {
                // 验证必须有版本（只记录日志，不显示错误，错误会在导入时显示）
                guard !info.gameVersion.isEmpty else {
                    Logger.shared.warning("选中的实例没有游戏版本")
                    return nil
                }
                
                return info
            } else {
                Logger.shared.warning("解析实例返回 nil")
                return nil
            }
        } catch {
            Logger.shared.error("解析实例失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 检查当前选中的实例是否使用了支持的 Mod Loader
    var isModLoaderSupported: Bool {
        guard let info = currentInstanceInfo else { return false }
        return AppConstants.modLoaders.contains(info.modLoader.lowercased())
    }
}

