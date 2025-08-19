import Foundation

class CommonService {
    
    /// 根据 mod loader 获取适配的版本列表（静默版本）
    /// - Parameter loader: 加载器类型
    /// - Returns: 兼容的版本列表
    static func compatibleVersions(for loader: String) async -> [String] {
        do {
            return try await compatibleVersionsThrowing(for: loader)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 \(loader) 版本失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 根据 mod loader 获取适配的版本列表（抛出异常版本）
    /// - Parameter loader: 加载器类型
    /// - Returns: 兼容的版本列表
    /// - Throws: GlobalError 当操作失败时
    static func compatibleVersionsThrowing(for loader: String) async throws -> [String] {
        var result: [String] = []
        switch loader.lowercased() {
        case "fabric", "forge", "quilt", "neoforge":
            let loaderType = loader.lowercased() == "neoforge" ? "neo" : loader.lowercased()
            let loaderVersions = try await fetchAllVersionThrowing(type: loaderType)
            result = loaderVersions.map { $0.id }
                .filter { version in
                    // 过滤出纯数字版本（如 1.21.1, 1.20.4 等）
                    let components = version.components(separatedBy: ".")
                    return components.allSatisfy { $0.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil }
                }
        default:
            guard let manifest = await MinecraftService.fetchVersionManifest() else {
                Logger.shared.error("无法获取 Minecraft 版本清单")
                return []
            }
            let allVersions = manifest.versions.filter { $0.type == "release" }.map { version in
                // 缓存每个版本的时间信息
                let cacheKey = "version_time_\(version.id)"
                let formattedTime = CommonUtil.formatRelativeTime(version.releaseTime)
                AppCacheManager.shared.setSilently(namespace: "version_time", key: cacheKey, value: formattedTime)
                return version.id
            }
            .filter { version in
                // 过滤出纯数字版本（如 1.21.1, 1.20.4 等）
                let components = version.components(separatedBy: ".")
                return components.allSatisfy { $0.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil }
            }
            result = allVersions
        }
        return result
    }

    
    // forge 和 neoforge 通用的classpath生成
    static func generateClasspath(from loader: ModrinthLoader, librariesDir: URL) -> String {
        let jarPaths: [String] = loader.libraries.compactMap { lib in
            guard lib.includeInClasspath else { return nil }
            if lib.includeInClasspath {
                let artifact = lib.downloads!.artifact
                return librariesDir.appendingPathComponent(artifact.path).path
            }else{
                return ""
            }
        }
        return jarPaths.joined(separator: ":")
    }
    
    
    /// 获取指定加载器类型和 Minecraft 版本的所有加载器版本（静默版本）
    /// - Parameters:
    ///   - type: 加载器类型
    ///   - minecraftVersion: Minecraft 版本
    /// - Returns: 加载器版本信息，失败时返回 nil
    static func fetchAllLoaderVersions(type: String, minecraftVersion: String) async -> LoaderVersion? {
        do {
            return try await fetchAllLoaderVersionsThrowing(type: type, minecraftVersion: minecraftVersion)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取加载器版本失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 获取指定加载器类型和 Minecraft 版本的所有加载器版本（抛出异常版本）
    /// - Parameters:
    ///   - type: 加载器类型
    ///   - minecraftVersion: Minecraft 版本
    /// - Returns: 加载器版本信息
    /// - Throws: GlobalError 当操作失败时
    static func fetchAllLoaderVersionsThrowing(type: String, minecraftVersion: String) async throws -> LoaderVersion {
        let manifest = try await fetchAllVersionThrowing(type: type)
        
        // 过滤出 id 等于当前 minecraftVersion 的结果
        let filteredVersions = manifest.filter { $0.id == minecraftVersion }
        
        // 返回第一个匹配的版本，如果没有则抛出错误
        guard let firstVersion = filteredVersions.first else {
            throw GlobalError.resource(
                chineseMessage: "未找到 Minecraft \(minecraftVersion) 的 \(type) 加载器版本",
                i18nKey: "error.resource.loader_version_not_found",
                level: .notification
            )
        }
        
        return firstVersion
    }
    
    /// 获取指定加载器类型的所有版本（静默版本）
    /// - Parameter type: 加载器类型
    /// - Returns: 版本列表，失败时返回空数组
    static func fetchAllVersion(type: String) async -> [LoaderVersion] {
        do {
            return try await fetchAllVersionThrowing(type: type)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 \(type) 版本失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取指定加载器类型的所有版本（抛出异常版本）
    /// - Parameter type: 加载器类型
    /// - Returns: 版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchAllVersionThrowing(type: String) async throws -> [LoaderVersion] {
        // 首先获取版本清单
        let manifestURL = URLConfig.API.Modrinth.loaderManifest(loader: type)
        let (manifestData, manifestResponse) = try await URLSession.shared.data(from: manifestURL)
        guard let httpResponse = manifestResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 \(type) 版本清单失败: HTTP \(manifestResponse)",
                i18nKey: "error.download.loader_manifest_failed",
                level: .notification
            )
        }
        
        // 解析版本清单
        do {
            let result = try JSONDecoder().decode(ModrinthLoaderVersion.self, from: manifestData)
            
            // 对于 NeoForge，不进行 stable 过滤，因为所有版本都是 beta
            if type == "neo" {
                return result.gameVersions
            } else {
                // 过滤出稳定版本
                return result.gameVersions.filter { $0.stable }
            }
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 \(type) 版本清单失败: \(error.localizedDescription)",
                i18nKey: "error.validation.version_manifest_parse_failed",
                level: .notification
            )
        }
    }

    
    
    
    
    /// 将Maven坐标转换为文件路径（支持classifier和@符号）
    /// - Parameter coordinate: Maven坐标
    /// - Returns: 文件路径
    static func convertMavenCoordinateToPath(_ coordinate: String) -> String {
        // 检查是否包含@符号，需要特殊处理
        if coordinate.contains("@") {
            return convertMavenCoordinateWithAtSymbol(coordinate)
        }
        
        // 对于标准Maven坐标，使用CommonService的方法
        if let relativePath = mavenCoordinateToRelativePath(coordinate) {
            guard let librariesDir = AppPaths.librariesDirectory else {
                return relativePath
            }
            return librariesDir.appendingPathComponent(relativePath).path
        }
        
        // 如果CommonService方法失败，可能是非标准格式，返回原值
        return coordinate
    }
    
    /// 处理包含@符号的Maven坐标
    /// - Parameter coordinate: Maven坐标
    /// - Returns: 文件路径
    static func convertMavenCoordinateWithAtSymbol(_ coordinate: String) -> String {
        let parts = coordinate.components(separatedBy: ":")
        guard parts.count >= 3 else { return coordinate }
        
        let groupId = parts[0]
        let artifactId = parts[1]
        let version = parts[2]
        let classifier = parts.count > 3 ? parts[3] : ""
        
        // 构建文件名
        var fileName = "\(artifactId)-\(version)"
        if !classifier.isEmpty {
            let processedClassifier = classifier.replacingOccurrences(of: "@", with: ".")
            fileName += "-\(processedClassifier)"
        }
        
        // 包含@符号的Maven坐标不添加.jar扩展名
        // 构建完整路径
        let groupPath = groupId.replacingOccurrences(of: ".", with: "/")
        let relativePath = "\(groupPath)/\(artifactId)/\(version)/\(fileName)"
        
        guard let librariesDir = AppPaths.librariesDirectory else {
            return relativePath
        }
        return librariesDir.appendingPathComponent(relativePath).path
    }
    /// Maven 坐标转相对路径
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: 相对路径
    static func mavenCoordinateToRelativePath(_ coordinate: String) -> String? {
        let parts = coordinate.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        
        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]
        
        var version = ""
        var classifier: String? = nil
        
        if parts.count == 3 {
            // group:artifact:version
            version = String(parts[2])
        } else if parts.count == 4 {
            // group:artifact:version:classifier  (MC这种情况)
            version = String(parts[2])
            classifier = String(parts[3])
        } else if parts.count == 5 {
            // group:artifact:packaging:classifier:version
            version = String(parts[4])
            classifier = String(parts[3])
        }
        
        if let classifier = classifier {
            return "\(group)/\(artifact)/\(version)/\(artifact)-\(version)-\(classifier).jar"
        } else {
            return "\(group)/\(artifact)/\(version)/\(artifact)-\(version).jar"
        }
    }
    
    /// Maven 坐标转相对路径（支持特殊格式）
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: 相对路径
    static func mavenCoordinateToRelativePathForURL(_ coordinate: String) -> String {
        // 检查是否包含@符号，需要特殊处理
        if coordinate.contains("@") {
            return convertMavenCoordinateWithAtSymbolForURL(coordinate)
        }
        
        // 对于标准Maven坐标，使用标准方法
        if let relativePath = mavenCoordinateToRelativePath(coordinate) {
            return relativePath
        }
        
        // 如果标准方法失败，可能是非标准格式，返回原值
        return coordinate
    }
    
    /// 处理包含@符号的Maven坐标（用于URL构建）
    /// - Parameter coordinate: Maven坐标
    /// - Returns: 相对路径
    static func convertMavenCoordinateWithAtSymbolForURL(_ coordinate: String) -> String {
        let parts = coordinate.components(separatedBy: ":")
        guard parts.count >= 3 else { return coordinate }
        
        let groupId = parts[0]
        let artifactId = parts[1]
        let version = parts[2]
        let classifier = parts.count > 3 ? parts[3] : ""
        
        // 构建文件名
        var fileName = "\(artifactId)-\(version)"
        if !classifier.isEmpty {
            let processedClassifier = classifier.replacingOccurrences(of: "@", with: ".")
            fileName += "-\(processedClassifier)"
        }
        
        // 包含@符号的Maven坐标不添加.jar扩展名
        // 构建相对路径（不包含本地目录）
        let groupPath = groupId.replacingOccurrences(of: ".", with: "/")
        return "\(groupPath)/\(artifactId)/\(version)/\(fileName)"
    }
    
    /// Maven 坐标转 FabricMC Maven 仓库 URL
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: Maven 仓库 URL
    static func mavenCoordinateToURL(lib: ModrinthLoaderLibrary) -> URL {
        // 使用相对路径而不是完整路径来构建URL
        let relativePath = mavenCoordinateToRelativePathForURL(lib.name)
        return lib.url!.appendingPathComponent(relativePath)
    }
    
    /// Maven 坐标转默认 Minecraft 库 URL
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: Minecraft 库 URL
    static func mavenCoordinateToDefaultURL(_ coordinate: String,url: URL) -> URL {
        // 使用相对路径而不是完整路径来构建URL
        let relativePath = mavenCoordinateToRelativePathForURL(coordinate)
        return url.appendingPathComponent(relativePath)
    }
    
    /// Maven 坐标转默认路径（用于本地文件路径）
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: 本地文件路径
    static func mavenCoordinateToDefaultPath(_ coordinate: String) -> String {
        // 使用相对路径而不是完整路径来构建URL
        return mavenCoordinateToRelativePathForURL(coordinate)
    }
    /// 根据 FabricLoader 生成 classpath 字符串
    /// - Parameters:
    ///   - loader: Fabric 加载器
    ///   - librariesDir: 库目录
    /// - Returns: classpath 字符串
    static func generateFabricClasspath(from loader: ModrinthLoader, librariesDir: URL) -> String {
        
        let jarPaths = loader.libraries.compactMap { coordinate -> String? in
            guard let relPath = mavenCoordinateToRelativePath(coordinate.name) else { return nil }
            return librariesDir.appendingPathComponent(relPath).path
        }
        return jarPaths.joined(separator: ":")
    }
    
    
    
    /// 处理 ModrinthLoader 中的游戏版本占位符
    /// - Parameters:
    ///   - loader: 原始加载器数据
    ///   - gameVersion: 游戏版本
    /// - Returns: 处理后的加载器数据
    public static func processGameVersionPlaceholders(loader: ModrinthLoader, gameVersion: String) -> ModrinthLoader {
        var processedLoader = loader
        
        // 处理 libraries 中的 URL 占位符
        processedLoader.libraries = loader.libraries.map { library in
            var processedLibrary = library
            
            // 处理 name 字段中的占位符
            processedLibrary.name = library.name.replacingOccurrences(of: "${modrinth.gameVersion}", with: gameVersion)
            
            
            
            return processedLibrary
        }
        
        return processedLoader
    }
    
}
 
