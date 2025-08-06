import Foundation

class FabricLoaderService {

    /// 获取所有 Loader 版本（静默版本）
    /// - Parameter minecraftVersion: Minecraft 版本
    /// - Returns: 加载器版本列表，失败时返回空数组
    static func fetchAllLoaderVersions(for minecraftVersion: String) async -> [FabricLoader] {
        do {
            return try await fetchAllLoaderVersionsThrowing(for: minecraftVersion)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Fabric 加载器版本失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取所有 Loader 版本（抛出异常版本）
    /// - Parameter minecraftVersion: Minecraft 版本
    /// - Returns: 加载器版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchAllLoaderVersionsThrowing(for minecraftVersion: String) async throws -> [FabricLoader] {
        let url = URLConfig.API.Fabric.loader.appendingPathComponent(minecraftVersion)
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Fabric 加载器版本失败: HTTP \(response)",
                i18nKey: "error.download.fabric_loader_fetch_failed",
                level: .notification
            )
        }
        
        var result: [FabricLoader] = []
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in jsonArray {
                    let singleData = try JSONSerialization.data(withJSONObject: item)
                    let decoder = JSONDecoder()
                    if let loader = try? decoder.decode(FabricLoader.self, from: singleData) {
                        result.append(loader)
                    }
                }
            }
            return result
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Fabric 加载器版本数据失败: \(error.localizedDescription)",
                i18nKey: "error.validation.fabric_loader_parse_failed",
                level: .notification
            )
        }
        
        
    }

    
    
    /// 获取最新的稳定版 Loader 版本（抛出异常版本）
    /// - Parameter minecraftVersion: Minecraft 版本
    /// - Returns: 最新的稳定版加载器
    /// - Throws: GlobalError 当操作失败时
    static func fetchLatestStableLoaderVersion(for minecraftVersion: String) async throws -> ModrinthLoader {

        let allLoaders = await fetchAllLoaderVersions(for: minecraftVersion)
        let stableLoaders = allLoaders.filter { $0.loader.stable }
        guard let firstStable = stableLoaders.first else {
            throw GlobalError.validation(
                chineseMessage: "未找到稳定版 Fabric 加载器",
                i18nKey: "error.validation.fabric_loader_no_stable_found",
                level: .notification
            )
        }
        let fabricVersion = firstStable.loader.version
        let cacheKey = "\(minecraftVersion)-\(fabricVersion)"
        // 1. 查全局缓存
        
        if let cached = AppCacheManager.shared.get(namespace: "fabric", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }
        // 2. 直接下载 version.json
        let (data, response) = try await URLSession.shared.data(from: URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: fabricVersion))
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Fabric profile 失败: HTTP \(response)",
                i18nKey: "error.download.fabric_profile_fetch_failed",
                level: .notification
            )
        }
        
        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        loader.version = fabricVersion
        // 处理 ${modrinth.gameVersion} 占位符
        loader = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: minecraftVersion)
        AppCacheManager.shared.setSilently(namespace: "fabric", key: cacheKey, value: loader)
        return loader
                
    }
    
    
    /// 封装 Fabric 设置流程：获取版本、下载、生成 Classpath（静默版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果，失败时返回 nil
    static func setupFabric(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        do {
            return try await setupFabricThrowing(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
        } catch {
            
            let globalError = GlobalError.from(error)
            Logger.shared.error("Fabric 设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 封装 Fabric 设置流程：获取版本、下载、生成 Classpath（抛出异常版本）
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - gameInfo: 游戏信息
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 设置结果
    /// - Throws: GlobalError 当操作失败时
    static func setupFabricThrowing(
        for gameVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        let fabricProfile = try await fetchLatestStableLoaderVersion(for: gameVersion)
        guard let librariesDirectory = AppPaths.librariesDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取库目录路径",
                i18nKey: "error.configuration.libraries_directory_not_found",
                level: .notification
            )
        }
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate
        await fileManager.downloadFabricJars(libraries: fabricProfile.libraries)
        let classpathString = CommonService.generateFabricClasspath(from: fabricProfile, librariesDir: librariesDirectory)
        let mainClass = fabricProfile.mainClass
        return (loaderVersion: fabricProfile.version!, classpath: classpathString, mainClass: mainClass)
    }

    /// 设置 Fabric 加载器（静默版本）
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
        return await setupFabric(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
    }
    
    /// 设置 Fabric 加载器（抛出异常版本）
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
        return try await setupFabricThrowing(for: gameVersion, gameInfo: gameInfo, onProgressUpdate: onProgressUpdate)
    }
}

extension FabricLoaderService: ModLoaderHandler {} 
