//
//  GameSetupUtil.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import Foundation
import SwiftUI

/// 游戏设置服务
/// 负责处理游戏下载、配置和保存的完整流程
@MainActor
class GameSetupUtil: ObservableObject {

    // MARK: - Properties
    @Published var downloadState = DownloadState()
    @Published var fabricDownloadState = DownloadState()
    @Published var forgeDownloadState = DownloadState()
    @Published var neoForgeDownloadState = DownloadState()

    private var downloadTask: Task<Void, Never>?

    // MARK: - Public Methods    

    /// 内部游戏保存方法
    /// - Parameters:
    ///   - gameName: 游戏名称
    ///   - gameIcon: 游戏图标
    ///   - selectedGameVersion: 选择的游戏版本
    ///   - selectedModLoader: 选择的模组加载器
    ///   - specifiedLoaderVersion: 指定的加载器版本（可选）
    ///   - pendingIconData: 待保存的图标数据
    ///   - playerListViewModel: 玩家列表视图模型（可选，为 nil 时跳过玩家校验）
    ///   - gameRepository: 游戏仓库
    ///   - onSuccess: 成功回调
    ///   - onError: 错误回调
    func saveGame( // swiftlint:disable:this function_parameter_count
        gameName: String,
        gameIcon: String,
        selectedGameVersion: String,
        selectedModLoader: String,
        specifiedLoaderVersion: String,
        pendingIconData: Data?,
        playerListViewModel: PlayerListViewModel?,
        gameRepository: GameRepository,
        onSuccess: @escaping () -> Void,
        onError: @escaping (GlobalError, String) -> Void
    ) async {
        // 验证当前玩家（仅在提供了 playerListViewModel 时）
        if let playerListViewModel = playerListViewModel {
            guard playerListViewModel.currentPlayer != nil else {
                Logger.shared.error("无法保存游戏，因为没有选择当前玩家。")
                onError(
                    GlobalError.configuration(
                        chineseMessage: "没有选择当前玩家",
                        i18nKey: "error.configuration.no_current_player",
                        level: .popup
                    ),
                    "error.no.current.player.title".localized()
                )
                return
            }
        }

        // 设置下载状态
        await MainActor.run {
            self.objectWillChange.send()
            downloadState.reset()
            downloadState.isDownloading = true
        }

        defer {
            Task { @MainActor in
                self.objectWillChange.send()
                downloadState.isDownloading = false
                downloadTask = nil
            }
        }

        // 保存游戏图标
        await saveGameIcon(
            gameName: gameName,
            pendingIconData: pendingIconData,
            onError: onError
        )

        // 创建初始游戏信息
        var gameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameName,
            gameIcon: gameIcon,
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: selectedModLoader
        )

        Logger.shared.info("开始为游戏下载文件: \(gameInfo.gameName)")

        do {
            // 下载 Mojang manifest
            let downloadedManifest = try await ModrinthService.fetchVersionInfo(from: selectedGameVersion)

            await JavaManager.shared.ensureJavaExists(version: downloadedManifest.javaVersion.component)

            // 设置文件管理器
            let fileManager = try await setupFileManager(manifest: downloadedManifest, modLoader: gameInfo.modLoader)

            // 开始下载过程
            try await startDownloadProcess(
                fileManager: fileManager,
                manifest: downloadedManifest,
                gameName: gameName
            )
            // 设置模组加载器
            let modLoaderResult = try await setupModLoaderIfNeeded(
                selectedModLoader: selectedModLoader,
                selectedGameVersion: selectedGameVersion,
                gameName: gameName,
                gameIcon: gameIcon,
                specifiedLoaderVersion: specifiedLoaderVersion
            )
            // 完善游戏信息
            gameInfo = await finalizeGameInfo(
                gameInfo: gameInfo,
                manifest: downloadedManifest,
                selectedModLoader: selectedModLoader,
                selectedGameVersion: selectedGameVersion,
                specifiedLoaderVersion: specifiedLoaderVersion,
                fabricResult: selectedModLoader.lowercased() == "fabric" ? modLoaderResult : nil,
                forgeResult: selectedModLoader.lowercased() == "forge" ? modLoaderResult : nil,
                neoForgeResult: selectedModLoader.lowercased() == "neoforge" ? modLoaderResult : nil,
                quiltResult: selectedModLoader.lowercased() == "quilt" ? modLoaderResult : nil
            )
            gameInfo.javaPath = JavaManager.shared.findJavaExecutable(version: downloadedManifest.javaVersion.component)
            // 保存游戏配置
            gameRepository.addGameSilently(gameInfo)

            // 发送通知
            NotificationManager.sendSilently(
                title: "notification.download.complete.title".localized(),
                body: String(format: "notification.download.complete.body".localized(), gameInfo.gameName, gameInfo.gameVersion, gameInfo.modLoader)
            )

            Logger.shared.info("游戏保存成功: \(gameInfo.gameName)")
            onSuccess()
        } catch is CancellationError {
            Logger.shared.info("游戏下载任务已取消")
            // 清理已创建的游戏文件夹
            await cleanupGameDirectories(gameName: gameName)
            await MainActor.run {
                self.objectWillChange.send()
                downloadState.reset()
            }
        } catch {
            // 清理已创建的游戏文件夹
            await cleanupGameDirectories(gameName: gameName)
            GlobalErrorHandler.shared.handle(error)
        }
        return
    }

    // MARK: - Private Methods

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

    private func saveGameIcon(
        gameName: String,
        pendingIconData: Data?,
        onError: @escaping (GlobalError, String) -> Void
    ) async {
        guard let data = pendingIconData, !gameName.isEmpty else {
            return
        }
        let profileDir = AppPaths.profileDirectory(gameName: gameName)
        let iconURL = profileDir.appendingPathComponent(AppConstants.defaultGameIcon)

        do {
            try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
            try data.write(to: iconURL)
        } catch {
            onError(
                GlobalError.fileSystem(
                    chineseMessage: "图片保存失败",
                    i18nKey: "error.filesystem.image_save_failed",
                    level: .notification
                ),
                "error.image.save.failed".localized()
            )
        }
    }

    private func setupFileManager(manifest: MinecraftVersionManifest, modLoader: String) async throws -> MinecraftFileManager {
        let nativesDir = AppPaths.nativesDirectory
        try FileManager.default.createDirectory(at: nativesDir, withIntermediateDirectories: true)
        Logger.shared.info("创建目录：\(nativesDir.path)")
        return MinecraftFileManager()
    }

    private func startDownloadProcess(
        fileManager: MinecraftFileManager,
        manifest: MinecraftVersionManifest,
        gameName: String
    ) async throws {
        // 先下载资源索引来获取资源文件总数
        let assetIndex = try await downloadAssetIndex(manifest: manifest)
        let resourceTotalFiles = assetIndex.objects.count

        downloadState.startDownload(
            coreTotalFiles: 1 + manifest.libraries.count + 1,
            resourcesTotalFiles: resourceTotalFiles
        )

        fileManager.onProgressUpdate = { fileName, completed, total, type in
            Task { @MainActor in
                self.objectWillChange.send()
                self.downloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: type)
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

    private func downloadAssetIndex(manifest: MinecraftVersionManifest) async throws -> DownloadedAssetIndex {

        let destinationURL = AppPaths.metaDirectory.appendingPathComponent("assets/indexes").appendingPathComponent("\(manifest.assetIndex.id).json")

        do {
            _ = try await DownloadManager.downloadFile(urlString: manifest.assetIndex.url.absoluteString, destinationURL: destinationURL, expectedSha1: manifest.assetIndex.sha1)
            let data = try Data(contentsOf: destinationURL)
            let assetIndexData = try JSONDecoder().decode(AssetIndexData.self, from: data)
            var totalSize = 0
            for object in assetIndexData.objects.values {
                totalSize += object.size
            }
            return DownloadedAssetIndex(
                id: manifest.assetIndex.id,
                url: manifest.assetIndex.url,
                sha1: manifest.assetIndex.sha1,
                totalSize: totalSize,
                objects: assetIndexData.objects
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载资源索引失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.asset_index_failed",
                level: .notification
            )
        }
    }

    private func setupModLoaderIfNeeded(
        selectedModLoader: String,
        selectedGameVersion: String,
        gameName: String,
        gameIcon: String,
        specifiedLoaderVersion: String
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String)? {
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
            modLoader: selectedModLoader
        )

        // 根据是否指定了加载器版本来选择不同的方法
        let progressCallback: (String, Int, Int) -> Void = { [weak self] fileName, completed, total in
            Task { @MainActor in
                guard let self = self else { return }
                self.objectWillChange.send()
                switch loaderType {
                case "fabric":
                    self.fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case "forge":
                    self.forgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case "neoforge":
                    self.neoForgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case "quilt":
                    self.fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                default:
                    break
                }
            }
        }

        return await handler.setupWithSpecificVersion(
            for: selectedGameVersion,
            loaderVersion: specifiedLoaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: progressCallback
        )
    }

    private func finalizeGameInfo(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest,
        selectedModLoader: String,
        selectedGameVersion: String,
        specifiedLoaderVersion: String,
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
                    if let fabricLoader = try? await FabricLoaderService.fetchSpecificLoaderVersion(for: selectedGameVersion, loaderVersion: specifiedLoaderVersion) {
                        let jvmArgs = fabricLoader.arguments.jvm ?? []
                        updatedGameInfo.modJvm = jvmArgs
                        let gameArgs = fabricLoader.arguments.game ?? []
                        updatedGameInfo.gameArguments = gameArgs
                    }
                } else {
                    if let quiltLoader = try? await QuiltLoaderService.fetchSpecificLoaderVersion(for: selectedGameVersion, loaderVersion: specifiedLoaderVersion) {
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

                if let forgeLoader = try? await ForgeLoaderService.fetchSpecificForgeProfile(for: selectedGameVersion, loaderVersion: specifiedLoaderVersion) {
                    let gameArgs = forgeLoader.arguments.game ?? []
                    updatedGameInfo.gameArguments = gameArgs
                    let jvmArgs = forgeLoader.arguments.jvm ?? []
                    updatedGameInfo.modJvm = jvmArgs.map { arg in
                        arg.replacingOccurrences(of: "${version_name}", with: selectedGameVersion)
                            .replacingOccurrences(of: "${classpath_separator}", with: ":")
                            .replacingOccurrences(of: "${library_directory}", with: AppPaths.librariesDirectory.path)
                    }
                }
            }

        case "neoforge":
            if let result = neoForgeResult {
                updatedGameInfo.modVersion = result.loaderVersion
                updatedGameInfo.modClassPath = result.classpath
                updatedGameInfo.mainClass = result.mainClass

                if let neoForgeLoader = try? await NeoForgeLoaderService.fetchSpecificNeoForgeProfile(for: selectedGameVersion, loaderVersion: specifiedLoaderVersion) {
                    let gameArgs = neoForgeLoader.arguments.game ?? []
                    updatedGameInfo.gameArguments = gameArgs

                    let jvmArgs = neoForgeLoader.arguments.jvm ?? []
                    // 使用 NSMutableString 避免链式调用创建多个临时字符串
                    updatedGameInfo.modJvm = jvmArgs.map { arg -> String in
                        let mutableArg = NSMutableString(string: arg)
                        mutableArg.replaceOccurrences(
                            of: "${version_name}",
                            with: selectedGameVersion,
                            options: [],
                            range: NSRange(location: 0, length: mutableArg.length)
                        )
                        mutableArg.replaceOccurrences(
                            of: "${classpath_separator}",
                            with: ":",
                            options: [],
                            range: NSRange(location: 0, length: mutableArg.length)
                        )
                        mutableArg.replaceOccurrences(
                            of: "${library_directory}",
                            with: AppPaths.librariesDirectory.path,
                            options: [],
                            range: NSRange(location: 0, length: mutableArg.length)
                        )
                        return mutableArg as String
                    }
                }
            }

        default:
            updatedGameInfo.mainClass = manifest.mainClass
        }

        // 构建启动命令
        let launcherBrand = Bundle.main.appName
        let launcherVersion = Bundle.main.fullVersion

        updatedGameInfo.launchCommand = MinecraftLaunchCommandBuilder.build(
            manifest: manifest,
            gameInfo: updatedGameInfo,
            launcherBrand: launcherBrand,
            launcherVersion: launcherVersion
        )

        return updatedGameInfo
    }

    /// 检查游戏名称是否重复
    /// - Parameter name: 游戏名称
    /// - Returns: 是否重复
    func checkGameNameDuplicate(_ name: String) async -> Bool {
        guard !name.isEmpty else { return false }

        let fileManager = FileManager.default
        let gameDir = AppPaths.profileRootDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: gameDir.path)
    }
}
