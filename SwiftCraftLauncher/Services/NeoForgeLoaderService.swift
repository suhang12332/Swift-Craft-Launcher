import Foundation


class NeoForgeLoaderService {
  
    /// 获取最新的可用 NeoForge 版本
    static func fetchLatestNeoForgeVersion(for minecraftVersion: String) async throws -> LoaderInfo {
        guard let result = await CommonService.fetchAllLoaderVersions(type: "neo", minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                chineseMessage: "未找到 Minecraft \(minecraftVersion) 的 NeoForge 加载器版本",
                i18nKey: "error.resource.neoforge_loader_version_not_found",
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


    
    /// 获取最新的 NeoForge profile（version.json）不拼接的client
    static func fetchLatestNeoForgeProfile(for minecraftVersion: String) async throws -> ModrinthLoader {
        let result = try await fetchLatestNeoForgeVersion(for: minecraftVersion)
        let neoForgeVersion = result.id
        let cacheKey = "\(minecraftVersion)-\(neoForgeVersion)"
        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "neoforge", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: URL(string: result.url)!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 NeoForge profile 失败: HTTP \(response)",
                i18nKey: "error.download.neoforge_profile_fetch_failed",
                level: .notification
            )
        }
        
        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        // 替换指定library的artifact.url
        if let dataJsonString = String(data: data, encoding: .utf8) {
            CommonService.parseDataFieldAndAddLibraries(to: &loader, dataJsonString: dataJsonString,url: URLConfig.API.NeoForge.gitReleasesBase
                .appendingPathComponent(neoForgeVersion))
        }
        loader.version = neoForgeVersion
        AppCacheManager.shared.setSilently(namespace: "neoforge", key: cacheKey, value: loader)
        return loader
    }

    /// 安装并准备 NeoForge，返回 (loaderVersion, classpath, mainClass)
    static func setupNeoForge(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        let neoForgeProfile = try await fetchLatestNeoForgeProfile(for: gameVersion)
        guard let librariesDirectory = AppPaths.librariesDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取库目录路径",
                i18nKey: "error.configuration.libraries_directory_not_found",
                level: .notification
            )
        }
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate
        await fileManager.downloadForgeJars(libraries: neoForgeProfile.libraries)
        
        let classpathString = CommonService.generateClasspath(from: neoForgeProfile, librariesDir: librariesDirectory)
        let mainClass = neoForgeProfile.mainClass
        return (loaderVersion: neoForgeProfile.version!, classpath: classpathString, mainClass: mainClass)
    }
    
    /// 设置 NeoForge 加载器（静默版本）
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
            Logger.shared.error("NeoForge 设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 设置 NeoForge 加载器（抛出异常版本）
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
        return try await setupNeoForge(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
    }
}

extension NeoForgeLoaderService: ModLoaderHandler {}
