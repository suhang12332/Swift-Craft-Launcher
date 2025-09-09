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
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Quilt 加载器列表失败: HTTP \(response)",
                i18nKey: "error.download.quilt_loaders_fetch_failed",
                level: .notification
            )
        }
        let decoder = JSONDecoder()
        let allLoaders = try decoder.decode([QuiltLoaderResponse].self, from: data)
        return allLoaders.filter { !$0.loader.version.lowercased().contains("beta") && !$0.loader.version.lowercased().contains("pre") }
    }

    /// 获取最新的可用 Quilt Loader 版本
    static func fetchLatestStableLoaderVersion(for minecraftVersion: String) async throws -> ModrinthLoader {
        let allLoaders = await fetchAllQuiltLoaders(for: minecraftVersion)
        guard let result = allLoaders.first else {
            throw GlobalError.resource(
                chineseMessage: "未找到任何 Minecraft \(minecraftVersion) 的 Quilt 加载器版本",
                i18nKey: "error.resource.no_quilt_loader_versions",
                level: .notification
            )
        }
        let quiltVersion = result.loader.version
        let cacheKey = "\(minecraftVersion)-\(quiltVersion)"

        if let cached = AppCacheManager.shared.get(namespace: "quilt", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }
        // 2. 直接下载 version.json
        let (data, response) = try await URLSession.shared.data(from: URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: quiltVersion))
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Quilt profile 失败: HTTP \(response)",
                i18nKey: "error.download.quilt_profile_fetch_failed",
                level: .notification
            )
        }

        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        loader.version = quiltVersion

        // 处理 ${modrinth.gameVersion} 占位符
        loader = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: minecraftVersion)

        AppCacheManager.shared.setSilently(namespace: "quilt", key: cacheKey, value: loader)
        return loader
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
        let (data, response) = try await URLSession.shared.data(from: URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: loaderVersion))
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Quilt profile 失败: HTTP \(response)",
                i18nKey: "error.download.quilt_profile_fetch_failed",
                level: .notification
            )
        }
        
        let result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        
        // 3. 存入缓存
        try AppCacheManager.shared.set(namespace: "quilt", key: cacheKey, value: result)
        
        return result
    }

    /// 封装 Quilt 设置流程：获取版本、下载、生成 Classpath（静默版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果，失败时返回 nil
    static func setupQuilt(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        do {
            return try await setupQuiltThrowing(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Quilt 设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 封装 Quilt 设置流程：获取版本、下载、生成 Classpath（抛出异常版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果
    /// - Throws: GlobalError 当操作失败时
    static func setupQuiltThrowing(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        let quiltProfile = try await fetchLatestStableLoaderVersion(for: gameVersion)
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

    /// 设置 Quilt 加载器（静默版本）
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
        return await setupQuilt(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
    }

    /// 设置 Quilt 加载器（抛出异常版本）
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
        return try await setupQuiltThrowing(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
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

        let classpathString = CommonService.generateClasspath(from: quiltProfile, librariesDir: librariesDirectory)
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
