import Foundation

enum MinecraftService {

    /// 获取 Minecraft 版本清单（静默版本）
    /// - Returns: 版本清单，失败时返回 nil
    static func fetchVersionManifest() async -> MojangVersionManifest? {
        do {
            return try await fetchVersionManifestThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Minecraft 版本清单失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 获取 Minecraft 版本清单（抛出异常版本）
    /// - Returns: 版本清单
    /// - Throws: GlobalError 当操作失败时
    static func fetchVersionManifestThrowing() async throws -> MojangVersionManifest {
        do {
            let (data, response) = try await NetworkManager.shared.data(
                from: URLConfig.API.Minecraft.versionList
            )
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取版本清单失败: HTTP \(response)",
                    i18nKey: "error.download.version_manifest_failed",
                    level: .notification
                )
            }
            
            return try JSONDecoder().decode(MojangVersionManifest.self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取当前版本信息（静默版本）
    /// - Parameter currentVersion: 当前版本号
    /// - Returns: 版本信息，失败时返回 nil
    static func getCurrentVersion(currentVersion: String) async -> MojangVersionInfo? {
        do {
            return try await getCurrentVersionThrowing(currentVersion: currentVersion)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取当前版本信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 获取当前版本信息（抛出异常版本）
    /// - Parameter currentVersion: 当前版本号
    /// - Returns: 版本信息
    /// - Throws: GlobalError 当操作失败时
    static func getCurrentVersionThrowing(currentVersion: String) async throws -> MojangVersionInfo {
        let manifest = try await fetchVersionManifestThrowing()
        let version = manifest.versions.first { $0.type == "release" && $0.id == currentVersion }
        
        guard let version = version else {
            throw GlobalError.resource(
                chineseMessage: "未找到版本: \(currentVersion)",
                i18nKey: "error.resource.version_not_found",
                level: .notification
            )
        }
        
        return version
    }

    /// 根据版本获取时间信息（静默版本）
    /// - Parameter version: 游戏版本号
    /// - Returns: 格式化的相对时间字符串，失败时返回空字符串
    static func fetchVersionTime(for version: String) async -> String {
        do {
            return try await fetchVersionTimeThrowing(for: version)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取版本时间失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return ""
        }
    }
    
    /// 根据版本获取时间信息（抛出异常版本）
    /// - Parameter version: 游戏版本号
    /// - Returns: 格式化的相对时间字符串
    /// - Throws: GlobalError 当操作失败时
    static func fetchVersionTimeThrowing(for version: String) async throws -> String {
        // 检查缓存
        let cacheKey = "version_time_\(version)"
        if let cachedTime: String = AppCacheManager.shared.get(namespace: "version_time", key: cacheKey, as: String.self) {
            return cachedTime
        }
        
        do {
            let gameVersions = await ModrinthService.fetchGameVersions()
            guard let gameVersion = gameVersions.first(where: { $0.version == version }) else {
                throw GlobalError.resource(
                    chineseMessage: "未找到版本时间信息: \(version)",
                    i18nKey: "error.resource.version_time_not_found",
                    level: .notification
                )
            }
            
            let formattedTime = CommonUtil.formatRelativeTime(gameVersion.date)
            // 缓存结果
            AppCacheManager.shared.setSilently(namespace: "version_time", key: cacheKey, value: formattedTime)
            return formattedTime
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取 Mojang 版本清单（静默版本）
    /// - Parameter url: 版本清单 URL
    /// - Returns: 版本清单，失败时返回 nil
    static func fetchMojangManifest(from url: URL) async throws -> MinecraftVersionManifest? {
        return try await fetchMojangManifestThrowing(from: url)
    }

    /// 获取 Mojang 版本清单（抛出异常版本）
    /// - Parameter url: 版本清单 URL
    /// - Returns: 版本清单
    /// - Throws: GlobalError 当操作失败时
    static func fetchMojangManifestThrowing(from url: URL) async throws -> MinecraftVersionManifest {
        Logger.shared.info("正在从以下地址获取 Mojang 版本清单：\(url.absoluteString)")
        
        do {
            let (manifestData, response) = try await NetworkManager.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取版本清单失败: HTTP \(response)",
                    i18nKey: "error.download.mojang_manifest_failed",
                    level: .notification
                )
            }
            
            let downloadedManifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: manifestData)
            Logger.shared.info("成功获取版本清单：\(downloadedManifest.id)")
            return downloadedManifest
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }
}
