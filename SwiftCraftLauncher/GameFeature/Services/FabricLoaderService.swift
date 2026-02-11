import Foundation

enum FabricLoaderService {

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
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

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

    /// 获取指定版本的 Fabric Loader
    /// - Parameters:
    ///   - minecraftVersion: Minecraft 版本
    ///   - loaderVersion: 指定的加载器版本
    /// - Returns: 指定版本的加载器
    /// - Throws: GlobalError 当操作失败时
    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        // 1. 查全局缓存
        if let cached = AppCacheManager.shared.get(namespace: "fabric", key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        // 2. 直接下载指定版本的 version.json
        // 使用统一的 API 客户端
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result.version = loaderVersion
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        // 3. 存入缓存
        AppCacheManager.shared.setSilently(namespace: "fabric", key: cacheKey, value: result)
        return result
    }

    /// 设置指定版本的 Fabric 加载器（静默版本）
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
            Logger.shared.error("Fabric 指定版本设置失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 设置指定版本的 Fabric 加载器（抛出异常版本）
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
        Logger.shared.info("开始设置指定版本的 Fabric 加载器: \(loaderVersion)")

        let fabricProfile = try await fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        await fileManager.downloadFabricJars(libraries: fabricProfile.libraries)

        let classpathString = CommonService.generateFabricClasspath(from: fabricProfile, librariesDir: librariesDirectory)
        let mainClass = fabricProfile.mainClass
        guard let version = fabricProfile.version else {
            throw GlobalError.validation(
                chineseMessage: "Fabric 加载器版本信息缺失",
                i18nKey: "error.validation.fabric_loader_version_missing",
                level: .notification
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension FabricLoaderService: ModLoaderHandler {}
