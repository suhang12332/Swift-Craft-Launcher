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

        // 优先解析 arguments（新版）；旧版用 minecraft_arguments 整行字符串，仅作 game 参数，无 jvm
        var jvmArgs = manifest.arguments?.jvm?
            .map { substituteVariables($0, with: variableMap) } ?? []
        var gameArgs: [String]
        // 旧版本判断：没有 arguments 但有 minecraftArguments，或者 arguments.jvm 为空但有 minecraftArguments
        let isOldVersion = (manifest.arguments == nil && manifest.minecraftArguments != nil) ||
            (manifest.arguments?.jvm == nil && manifest.minecraftArguments != nil)
        if let game = manifest.arguments?.game {
            gameArgs = game.map { substituteVariables($0, with: variableMap) }
        } else if let ma = manifest.minecraftArguments {
            gameArgs = MinecraftVersionManifest.parseMinecraftArguments(ma).map { substituteVariables($0, with: variableMap) }
        } else {
            gameArgs = []
        }

        // 旧版本需要在 JVM 参数中显式添加 classpath 和 java.library.path（因为 minecraft_arguments 不包含这些占位符）
        if isOldVersion {
            jvmArgs.append("-cp")
            jvmArgs.append(classpath)
            let nativesPath = paths.nativesDir
            jvmArgs.append("-Djava.library.path=\(nativesPath)")
            Logger.shared.debug("旧版本检测到，添加 java.library.path: \(nativesPath)")
        }

        // 额外拼接 JVM 内存参数
        let xmsArg = "-Xms${xms}M"
        let xmxArg = "-Xmx${xmx}M"
        jvmArgs.insert(contentsOf: [xmsArg, xmxArg], at: 0)

        // 添加 macOS 特定的 JVM 参数
        if !isOldVersion {
            jvmArgs.insert("-XstartOnFirstThread", at: 0)
        }

        // 拼接 modJvm
        if !gameInfo.modJvm.isEmpty {
            jvmArgs.append(contentsOf: gameInfo.modJvm)
        }

        // 拼接 gameInfo 的 gameArguments（过滤掉已存在的参数，避免重复）
        if !gameInfo.gameArguments.isEmpty {
            let filteredGameArgs = filterDuplicateArguments(gameInfo.gameArguments, existingArgs: gameArgs, variableMap: variableMap)
            gameArgs.append(contentsOf: filteredGameArgs)
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

    /// 过滤掉与现有参数重复的参数
    /// - Parameters:
    ///   - newArgs: 新参数列表（来自 mod loader）
    ///   - existingArgs: 现有参数列表（来自 manifest）
    ///   - variableMap: 变量映射表，用于替换新参数中的占位符
    /// - Returns: 过滤后且已替换变量的参数列表
    private static func filterDuplicateArguments(_ newArgs: [String], existingArgs: [String], variableMap: [String: String]) -> [String] {
        // 提取现有参数中的 key（以 -- 开头的参数名）
        var existingKeys = Set<String>()
        for arg in existingArgs {
            if arg.hasPrefix("--") {
                existingKeys.insert(arg)
            }
        }
        
        // 过滤新参数，跳过已存在的 key 及其对应的值
        var result: [String] = []
        var skipNext = false
        
        for (index, arg) in newArgs.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            
            if arg.hasPrefix("--") {
                // 检查该参数是否已存在
                if existingKeys.contains(arg) {
                    // 如果下一个参数不是以 -- 开头，说明它是当前参数的值，也需要跳过
                    if index + 1 < newArgs.count && !newArgs[index + 1].hasPrefix("--") {
                        skipNext = true
                    }
                    Logger.shared.debug("过滤重复参数: \(arg)")
                    continue
                }
            }
            
            // 对参数进行变量替换后添加
            let substitutedArg = substituteVariables(arg, with: variableMap)
            result.append(substitutedArg)
        }
        
        return result
    }

    private static func substituteVariables(_ arg: String, with map: [String: String]) -> String {
        // 快速检查：如果字符串不包含任何占位符，直接返回
        guard arg.contains("${") else {
            return arg
        }

        // 使用 NSMutableString 避免在循环中创建大量临时字符串
        let result = NSMutableString(string: arg)
        for (key, value) in map {
            let placeholder = "${\(key)}"
            // 先检查是否包含占位符，避免不必要的替换操作
            if result.range(of: placeholder).location != NSNotFound {
                result.replaceOccurrences(
                    of: placeholder,
                    with: value,
                    options: [],
                    range: NSRange(location: 0, length: result.length)
                )
            }
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
        guard let artifact = library.downloads?.artifact else { return nil }

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
