import Foundation

enum MinecraftLaunchCommandBuilder {
    /// 构建启动命令（静默版本）
    /// - Returns: 启动命令数组，失败时返回空数组
    static func build(
        manifest: MinecraftVersionManifest,
        gameInfo: GameVersionInfo,
        launcherBrand: String,
        launcherVersion: String
    ) -> [String] {
        do {
            return try buildThrowing(
                manifest: manifest,
                gameInfo: gameInfo,
                launcherBrand: launcherBrand,
                launcherVersion: launcherVersion
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("构建启动命令失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 构建启动命令（抛出异常版本）
    /// - Throws: GlobalError 当构建失败时
    static func buildThrowing(
        manifest: MinecraftVersionManifest,
        gameInfo: GameVersionInfo,
        launcherBrand: String,
        launcherVersion: String
    ) throws -> [String] {
        // 验证并获取路径
        let paths = try validateAndGetPaths(gameInfo: gameInfo, manifest: manifest)

        // 构建 classpath
        let classpath = buildClasspath(
            manifest.libraries,
            librariesDir: paths.librariesDir,
            clientJarPath: paths.clientJarPath,
            modClassPath: gameInfo.modClassPath,
            minecraftVersion: manifest.id
        )

        // 变量映射
        let variableMap: [String: String] = [
            "auth_player_name": "${auth_player_name}",
            "version_name": gameInfo.gameVersion,
            "game_directory": paths.gameDir,
            "assets_root": paths.assetsDir,
            "assets_index_name": gameInfo.assetIndex,
            "auth_uuid": "${auth_uuid}",
            "auth_access_token": "${auth_access_token}",
            "clientid": AppConstants.minecraftClientId,
            "auth_xuid": "${auth_xuid}",
            "user_type": "msa",
            "version_type": Bundle.main.appName,
            "natives_directory": paths.nativesDir,
            "launcher_name": Bundle.main.appName,
            "launcher_version": launcherVersion,
            "classpath": classpath,
        ]

        // 优先解析 arguments 字段
        var jvmArgs = manifest.arguments.jvm?
            .map { substituteVariables($0, with: variableMap) } ?? []
        var gameArgs = manifest.arguments.game?
            .map { substituteVariables($0, with: variableMap) } ?? []

        // 额外拼接 JVM 内存参数
        let xmsArg = "-Xms${xms}M"
        let xmxArg = "-Xmx${xmx}M"
        jvmArgs.insert(contentsOf: [xmsArg, xmxArg], at: 0)

        // 添加 macOS 特定的 JVM 参数
        jvmArgs.insert("-XstartOnFirstThread", at: 0)

        // 拼接 modJvm
        if !gameInfo.modJvm.isEmpty {
            jvmArgs.append(contentsOf: gameInfo.modJvm)
        }

        // 拼接 gameInfo 的 gameArguments
        if !gameInfo.gameArguments.isEmpty {
            gameArgs.append(contentsOf: gameInfo.gameArguments)
        }

        // 拼接参数
        let allArgs = jvmArgs + [gameInfo.mainClass] + gameArgs
        return allArgs
    }

    /// 验证并获取必要的路径
    /// - Parameters:
    ///   - gameInfo: 游戏信息
    ///   - manifest: 版本清单
    /// - Returns: 验证后的路径集合
    /// - Throws: GlobalError 当路径无效时
    private static func validateAndGetPaths(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest
        // swiftlint:disable:next large_tuple
    ) throws -> (nativesDir: String, librariesDir: URL, assetsDir: String, gameDir: String, clientJarPath: String) {
        // 验证游戏目录

        // 验证客户端 JAR 文件
        let clientJarPath = AppPaths.versionsDirectory.appendingPathComponent(manifest.id).appendingPathComponent("\(manifest.id).jar").path
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: clientJarPath) else {
            throw GlobalError.resource(
                chineseMessage: "客户端 JAR 文件不存在: \(clientJarPath)",
                i18nKey: "error.resource.client_jar_not_found",
                level: .popup
            )
        }

        return (nativesDir: AppPaths.nativesDirectory.path, librariesDir: AppPaths.librariesDirectory, assetsDir: AppPaths.assetsDirectory.path, gameDir: AppPaths.profileDirectory(gameName: gameInfo.gameName).path, clientJarPath: clientJarPath)
    }

    private static func substituteVariables(_ arg: String, with map: [String: String]) -> String {
        // 使用 NSMutableString 避免在循环中创建大量临时字符串
        let result = NSMutableString(string: arg)
        for (key, value) in map {
            let placeholder = "${\(key)}"
            result.replaceOccurrences(
                of: placeholder,
                with: value,
                options: [],
                range: NSRange(location: 0, length: result.length)
            )
        }
        return result as String
    }

    private static func buildClasspath(_ libraries: [Library], librariesDir: URL, clientJarPath: String, modClassPath: String, minecraftVersion: String) -> String {
        Logger.shared.debug("开始构建类路径 - 库数量: \(libraries.count), mod类路径: \(modClassPath.isEmpty ? "无" : "\(modClassPath.split(separator: ":").count)个路径")")

        // 解析 mod 类路径并提取已存在的库路径
        let modClassPaths = parseModClassPath(modClassPath, librariesDir: librariesDir)
        let existingModBasePaths = extractBasePaths(from: modClassPaths, librariesDir: librariesDir)
        Logger.shared.debug("解析到 \(modClassPaths.count) 个 mod 类路径，\(existingModBasePaths.count) 个基础路径")

        // 过滤并处理 manifest 库
        let manifestLibraryPaths = libraries
            .filter { shouldIncludeLibrary($0, minecraftVersion: minecraftVersion) }
            .compactMap { library in
                processLibrary(library, librariesDir: librariesDir, existingModBasePaths: existingModBasePaths, minecraftVersion: minecraftVersion)
            }
            .flatMap { $0 }

        Logger.shared.debug("处理完成 - manifest库路径: \(manifestLibraryPaths.count)个")

        // 构建最终的类路径并去重
        let allPaths = manifestLibraryPaths + [clientJarPath] + modClassPaths
        let uniquePaths = removeDuplicatePaths(allPaths)
        let classpath = uniquePaths.joined(separator: ":")

        Logger.shared.debug("类路径构建完成 - 原始路径数: \(allPaths.count), 去重后: \(uniquePaths.count)")
        return classpath
    }

    /// 解析 mod 类路径字符串
    private static func parseModClassPath(_ modClassPath: String, librariesDir: URL) -> [String] {
        return modClassPath.split(separator: ":").map { String($0) }
    }

    /// 移除重复的路径，保持原始顺序
    private static func removeDuplicatePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { path in
            let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedPath.isEmpty else { return false }

            if seen.contains(normalizedPath) {
                Logger.shared.debug("发现重复路径，已跳过: \(normalizedPath)")
                return false
            } else {
                seen.insert(normalizedPath)
                return true
            }
        }
    }

    /// 从路径列表中提取基础路径（用于去重）
    private static func extractBasePaths(from paths: [String], librariesDir: URL) -> Set<String> {
        let librariesDirPath = librariesDir.path.appending("/")

        return Set(paths.compactMap { path in
            guard path.hasPrefix(librariesDirPath) else { return nil }
            let relPath = String(path.dropFirst(librariesDirPath.count))
            return extractBasePath(from: relPath)
        })
    }

    /// 从相对路径中提取基础路径（去掉最后两级目录）
    private static func extractBasePath(from relativePath: String) -> String? {
        let pathComponents = relativePath.split(separator: "/")
        guard pathComponents.count >= 2 else { return nil }
        return pathComponents.dropLast(2).joined(separator: "/")
    }

    /// 处理单个库，返回其所有相关路径
    private static func processLibrary(_ library: Library, librariesDir: URL, existingModBasePaths: Set<String>, minecraftVersion: String) -> [String]? {
        let artifact = library.downloads.artifact

        // 获取主库路径
        let libraryPath = getLibraryPath(artifact: artifact, libraryName: library.name, librariesDir: librariesDir)

        // 检查是否与 mod 路径重复
        let relativePath = String(libraryPath.dropFirst(librariesDir.path.appending("/").count))
        guard let basePath = extractBasePath(from: relativePath) else { return nil }

        if existingModBasePaths.contains(basePath) {
            return nil // mod 路径已存在，跳过
        }

        // 只返回 artifact 路径，不包含 classifiers
        // classifiers 是原生库，不应该添加到 classpath 中
        return [libraryPath]
    }

    /// 获取库文件路径
    private static func getLibraryPath(artifact: LibraryArtifact, libraryName: String, librariesDir: URL) -> String {
        if let existingPath = artifact.path {
            return librariesDir.appendingPathComponent(existingPath).path
        } else {
            let fullPath = CommonService.convertMavenCoordinateToPath(libraryName)
            Logger.shared.debug("库文件 \(libraryName) 缺少路径信息，使用 Maven 坐标生成路径: \(fullPath)")
            return fullPath
        }
    }

    /// 获取分类器库路径
    /// 注意：classifiers 库不再添加到 classpath 中，此方法保留用于其他用途
    private static func getClassifierPaths(library: Library, librariesDir: URL, minecraftVersion: String) -> [String] {
        // 不再将 classifiers 添加到 classpath 中
        return []
    }

    /// 判断该库是否应该包含在类路径中
    private static func shouldIncludeLibrary(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        // 检查基本条件：可下载且包含在类路径中
        guard library.downloadable == true && library.includeInClasspath == true else {
            return false
        }

        // 使用统一的库过滤逻辑
        return LibraryFilter.isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }
}
