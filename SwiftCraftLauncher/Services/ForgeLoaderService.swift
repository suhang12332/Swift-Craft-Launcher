import Foundation

class ForgeLoaderService {

    static func fetchLatestForgeProfile(for minecraftVersion: String) async throws -> ModrinthLoader {
        let result = try await fetchLatestForgeVersion(for: minecraftVersion)
        let forgeVersion = result.id
        let cacheKey = "\(minecraftVersion)-\(forgeVersion)"
        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "forge", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }
        // 2. 直接下载 version.json
        let (data, response) = try await NetworkManager.shared.data(from: URL(string: result.url)!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Forge profile 失败: HTTP \(response)",
                i18nKey: "error.download.forge_profile_fetch_failed",
                level: .notification
            )
        }

        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        loader.version = forgeVersion
        AppCacheManager.shared.setSilently(namespace: "forge", key: cacheKey, value: loader)
        return loader
    }

    /// 通过Modrinth API获取所有可用Forge版本详细信息
    static func fetchAllForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        guard let result = await CommonService.fetchAllLoaderVersions(type: "forge", minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                chineseMessage: "未找到 Minecraft \(minecraftVersion) 的 Forge 加载器版本",
                i18nKey: "error.resource.forge_loader_version_not_found",
                level: .notification
            )
        }
        return result
    }

    static func fetchLatestForgeVersion(for minecraftVersion: String) async throws -> LoaderInfo {
        guard let result = await CommonService.fetchAllLoaderVersions(type: "forge", minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                chineseMessage: "未找到 Minecraft \(minecraftVersion) 的 Forge 加载器版本",
                i18nKey: "error.resource.forge_loader_version_not_found",
                level: .notification
            )
        }

        // 先过滤出 stable 为 true 的加载器
        let stableLoaders = result.loaders.filter { $0.stable }

        // 如果过滤结果不为空，则返回第一个稳定版本，否则直接返回第一个
        if !stableLoaders.isEmpty {
            return stableLoaders.first!
        } else {
            return result.loaders.first!
        }
    }

    static func setupForge(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        let forgeProfile = try await fetchLatestForgeProfile(for: gameVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        // 第一步：下载所有downloadable=true的库文件
        let downloadableLibraries = forgeProfile.libraries.filter { $0.downloads != nil }
        let totalDownloads = downloadableLibraries.count
        await fileManager.downloadForgeJars(libraries: forgeProfile.libraries)

        // 第二步：执行processors（如果存在）
        if let processors = forgeProfile.processors, !processors.isEmpty {
            // 使用version.json中的原始data字段
            try await fileManager.executeProcessors(
                processors: processors,
                librariesDir: librariesDirectory,
                gameVersion: gameVersion,
                data: forgeProfile.data,
                gameName: gameInfo.gameName,
                onProgressUpdate: { message, currentProcessor, totalProcessors in
                    // 将处理器进度消息转换为下载进度格式
                    // 总任务数 = 下载数 + 处理器数
                    let totalTasks = totalDownloads + totalProcessors
                    let completedTasks = totalDownloads + currentProcessor
                    onProgressUpdate(message, completedTasks, totalTasks)
                }
            )
        }

        let classpathString = CommonService.generateClasspath(from: forgeProfile, librariesDir: librariesDirectory)
        let mainClass = forgeProfile.mainClass
        return (loaderVersion: forgeProfile.version!, classpath: classpathString, mainClass: mainClass)
    }

    /// 设置 Forge 加载器（静默版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果，失败时返回 nil
    static func setup(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        do {
            return try await setupThrowing(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Forge 设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 设置 Forge 加载器（抛出异常版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果
    /// - Throws: GlobalError 当操作失败时
    static func setupThrowing(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        return try await setupForge(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
    }
}

extension ForgeLoaderService: ModLoaderHandler {}
