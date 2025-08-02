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

    
    /// 解析 ModrinthLoader 的 data 字段，提取 client 库并追加到 libraries
    static func parseDataFieldAndAddLibraries(to loader: inout ModrinthLoader, dataJsonString: String, url: URL) {
        guard let data = dataJsonString.data(using: .utf8) else { 
            Logger.shared.error("解析 data 字段失败: 无法将字符串转换为数据")
            return 
        }
        
        do {
            // 解析 data 字段的 JSON
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            // 检查是否为字典类型
            guard let jsonDict = jsonObject as? [String: Any] else { 
                Logger.shared.error("解析 data 字段失败: JSON 不是字典类型")
                return 
            }
            
            // 先将 jsonDict["data"] 转为 [String: Any]，再遍历
            if let dataDict = jsonDict["data"] as? [String: Any] {
                for (_, value) in dataDict {
                guard let objectDict = value as? [String: Any] else { continue }
                
                if let clientValue = objectDict["client"] {
                        // 1. 直接是 [String]
                         if let clientString = clientValue as? String {
                            // 去除单引号和双引号
                            let trimmed = clientString.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                            // 尝试解析为数组
                            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                                // 去除前后中括号
                                let inner = trimmed.dropFirst().dropLast()
                                // 按逗号分割并去除空格
                                let coordinates = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                for clientCoordinate in coordinates {
                                    if !clientCoordinate.isEmpty, let library = createLibraryFromCoordinate(clientCoordinate,url) {
                                        if let idx = loader.libraries.firstIndex(where: { $0.name.contains(library.name) }) {
                                            if loader.libraries[idx].downloads != nil {
                                                // 只替换 url 如果此处还能拼接上，说明这个文件需要下载
                                                loader.libraries[idx].downloads!.artifact.url = library.downloads!.artifact.url
                                                loader.libraries[idx].downloadable = true
                                            }
                                        } else {
                                            loader.libraries.append(library)
                                        }
                                    }
                                }
                            }
                            // 3. 不是数组，是 hash 或其他，跳过
                        }
                    }
                }
            }
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("解析 data 字段失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }
    
    /// 从坐标创建 ModrinthLoaderLibrary 对象
    private static func createLibraryFromCoordinate(_ coordinate: String,_ url: URL) -> ModrinthLoaderLibrary? {
        // 解析坐标格式：net.minecraft:client:1.21.8:mappings@tsrg
        let parts = coordinate.components(separatedBy: ":")
        guard parts.count >= 3 else { return nil }
        
        let groupId = parts[0] // net.minecraft
        let artifactId = parts[1] // client
        let version = parts[2] // 1.21.8
        
        // 检查是否有 @ 分隔符
        let artifactAndClassifier = parts.count > 3 ? parts[3] : ""
        let artifactClassifierParts = artifactAndClassifier.components(separatedBy: "@")
        let classifier = artifactClassifierParts.first ?? ""
        let fileExtension = artifactClassifierParts.count > 1 ? artifactClassifierParts[1] : "jar"
        
        // 构建路径：net/minecraftforge/forge/1.21.8-58.0.1/forge-1.21.8-58.0.1-client.jar
        var fileName = "\(artifactId)-\(version)"
        if !classifier.isEmpty {
            fileName += "-\(classifier)"
        }
        fileName += ".\(fileExtension)"
        let finalPath = "\(groupId.replacingOccurrences(of: ".", with: "/"))/\(artifactId)/\(version)/\(fileName)"
        
        // 创建 LibraryArtifact
        let artifact = LibraryArtifact(
            path: finalPath,
            sha1: "", // data 字段中通常没有 sha1
            size: 0,  // data 字段中通常没有 size
            url:  url.appendingPathComponent(fileName) // data 字段中通常没有 url
        )
        
        // 创建 LibraryDownloads
        let downloads = LibraryDownloads(artifact: artifact,classifiers: nil)
        
        // 创建 ModrinthLoaderLibrary
        return ModrinthLoaderLibrary(
            downloads: downloads,
            name: coordinate,
            includeInClasspath: false,
            downloadable: true,
            skip: true,

        )
    }
    
    /// Maven 坐标转相对路径
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: 相对路径
    static func mavenCoordinateToRelativePath(_ coordinate: String) -> String? {
        let parts = coordinate.split(separator: ":")
        guard parts.count == 3 else { return nil }
        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]
        let version = parts[2]
        return "\(group)/\(artifact)/\(version)/\(artifact)-\(version).jar"
    }
    
    /// Maven 坐标转 FabricMC Maven 仓库 URL
    /// - Parameter coordinate: Maven 坐标
    /// - Returns: Maven 仓库 URL
    static func mavenCoordinateToURL(lib: ModrinthLoaderLibrary) -> URL? {
        guard let relPath = mavenCoordinateToRelativePath(lib.name) else { return nil }
        return lib.url!.appendingPathComponent(relPath)
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
    
    /// 将 Maven URL 转换为 Maven 路径
    /// - Parameter url: Maven URL
    /// - Returns: Maven 路径
    static func mavenURLToMavenPath(url: URL) -> String {
        let path = url.path
        // 1. 将路径按 "/" 分割成组件
        var components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            
        // 2. 找到第一个 "maven" 并移除（如果存在）
        if let index = components.firstIndex(of: "maven") {
            components.remove(at: index)
        }
            
        // 3. 重新拼接为路径字符串
        return components.joined(separator: "/")
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
 
