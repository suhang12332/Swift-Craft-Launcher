import Foundation

enum QuiltLoaderService {

    /// 获取所有 Loader 版本（静默版本）
    /// - Parameter minecraftVersion: Minecraft 版本
    /// - Returns: 加载器版本列表，失败时返回空数组
    static func fetchAllQuiltLoaders(for minecraftVersion: String) async -> [QuiltLoaderResponse] {
        do {
            return try await fetchAllQuiltLoadersThrowing(for: minecraftVersion)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Fabric 加载器版本失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取所有可用 Quilt Loader 版本
    static func fetchAllQuiltLoadersThrowing(for minecraftVersion: String) async throws -> [QuiltLoaderResponse] {
        let url = URLConfig.API.Quilt.loaderBase.appendingPathComponent(minecraftVersion)
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)
        let decoder = JSONDecoder()
        let allLoaders = try decoder.decode([QuiltLoaderResponse].self, from: data)
        return allLoaders.filter { !$0.loader.version.lowercased().contains("beta") && !$0.loader.version.lowercased().contains("pre") }
    }

    /// 获取指定版本的 Quilt Loader
    /// - Parameters:
    ///   - minecraftVersion: Minecraft 版本
    ///   - loaderVersion: 指定的加载器版本
    /// - Returns: 指定版本的加载器
    /// - Throws: GlobalError 当操作失败时
    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "quilt", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        // 2. 直接下载指定版本的 version.json
        // 使用统一的 API 客户端
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result.version = loaderVersion
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        // 3. 存入缓存
        AppCacheManager.shared.setSilently(namespace: "quilt", key: cacheKey, value: result)

        return result
    }

    /// 设置指定版本的 Quilt 加载器（静默版本）
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
            Logger.shared.error("Quilt 指定版本设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 设置指定版本的 Quilt 加载器（抛出异常版本）
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
        Logger.shared.info("开始设置指定版本的 Quilt 加载器: \(loaderVersion)")

        let quiltProfile = try await fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        await fileManager.downloadFabricJars(libraries: quiltProfile.libraries)

        let classpathString = CommonService.generateFabricClasspath(from: quiltProfile, librariesDir: librariesDirectory)
        let mainClass = quiltProfile.mainClass
        guard let version = quiltProfile.version else {
            throw GlobalError.resource(
                chineseMessage: "Quilt profile 缺少版本信息",
                i18nKey: "error.resource.quilt_missing_version",
                level: .notification
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension QuiltLoaderService: ModLoaderHandler {}
