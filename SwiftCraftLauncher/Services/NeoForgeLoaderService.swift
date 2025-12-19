import Foundation

enum NeoForgeLoaderService {
    /// 获取所有可用NeoForge版本的version字符串集合
    static func fetchAllNeoForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        guard let result = await CommonService.fetchAllLoaderVersions(type: "neo", minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                chineseMessage: "未找到 Minecraft \(minecraftVersion) 的 NeoForge 加载器版本",
                i18nKey: "error.resource.neoforge_loader_version_not_found",
                level: .notification
            )
        }
        return result
    }

    /// 获取指定版本的 NeoForge profile
    /// - Parameters:
    ///   - minecraftVersion: Minecraft 版本
    ///   - loaderVersion: 指定的加载器版本
    /// - Returns: 指定版本的 NeoForge profile
    /// - Throws: GlobalError 当操作失败时
    static func fetchSpecificNeoForgeProfile(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "neoforge", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        // 2. 直接下载指定版本的 version.json
        // 使用统一的 API 客户端
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "neo", version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        // 3. 存入缓存
        result.version = loaderVersion
        AppCacheManager.shared.setSilently(namespace: "neoforge", key: cacheKey, value: result)

        return result
    }

    /// 设置指定版本的 NeoForge 加载器（静默版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - loaderVersion: 指定的加载器版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果，失败时返回 nil
    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        do {
            return try await setupWithSpecificVersionThrowing(
                for: gameVersion,
                loaderVersion: loaderVersion,
                gameInfo: gameInfo,
                onProgressUpdate: onProgressUpdate
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("NeoForge 指定版本设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 设置指定版本的 NeoForge 加载器（抛出异常版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - loaderVersion: 指定的加载器版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果
    /// - Throws: GlobalError 当操作失败时
    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        Logger.shared.info("开始设置指定版本的 NeoForge 加载器: \(loaderVersion)")

        let neoForgeProfile = try await fetchSpecificNeoForgeProfile(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        // 第一步：下载所有downloadable=true的库文件
        let downloadableLibraries = neoForgeProfile.libraries.filter { $0.downloads != nil }
        let totalDownloads = downloadableLibraries.count
        await fileManager.downloadForgeJars(libraries: neoForgeProfile.libraries)

        // 第二步：执行processors（如果存在）
        if let processors = neoForgeProfile.processors, !processors.isEmpty {
            try await fileManager.executeProcessors(
                processors: processors,
                librariesDir: librariesDirectory,
                gameVersion: gameVersion,
                data: neoForgeProfile.data,
                gameName: gameInfo.gameName
            ) { message, currentProcessor, totalProcessors in
                // 将处理器进度消息转换为下载进度格式
                // 总任务数 = 下载数 + 处理器数
                let totalTasks = totalDownloads + totalProcessors
                let completedTasks = totalDownloads + currentProcessor
                onProgressUpdate(message, completedTasks, totalTasks)
            }
        }

        let classpathString = CommonService.generateClasspath(from: neoForgeProfile, librariesDir: librariesDirectory)
        let mainClass = neoForgeProfile.mainClass

        guard let version = neoForgeProfile.version else {
            throw GlobalError.resource(
                chineseMessage: "NeoForge profile 缺少版本信息",
                i18nKey: "error.resource.neoforge_missing_version",
                level: .notification
            )
        }

        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension NeoForgeLoaderService: ModLoaderHandler {}
