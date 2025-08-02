import Foundation




class ForgeLoaderService {



    static func fetchLatestForgeProfile(for minecraftVersion: String) async throws -> ModrinthLoader {
        let result = try await fetchLatestForgeVersion(for: minecraftVersion)
        let forgeVersion = result.id
        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "forge", key: forgeVersion, as: ModrinthLoader.self) {
            return cached
        }
        // 2. 直接下载 version.json
        let (data, response) = try await URLSession.shared.data(from: URL(string: result.url)!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Forge profile 失败: HTTP \(response)",
                i18nKey: "error.download.forge_profile_fetch_failed",
                level: .notification
            )
        }
        
        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        // 替换指定library的artifact.url
        if let dataJsonString = String(data: data, encoding: .utf8) {
            CommonService.parseDataFieldAndAddLibraries(to: &loader, dataJsonString: dataJsonString,url: URLConfig.API.Forge.gitReleasesBase
                .appendingPathComponent(forgeVersion))
        }
        loader.version = forgeVersion
        AppCacheManager.shared.setSilently(namespace: "forge", key: forgeVersion, value: loader)
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
        guard let librariesDirectory = AppPaths.librariesDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取库目录路径",
                i18nKey: "error.configuration.libraries_directory_not_found",
                level: .notification
            )
        }
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate
        await fileManager.downloadForgeJars(libraries: forgeProfile.libraries)
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
 
