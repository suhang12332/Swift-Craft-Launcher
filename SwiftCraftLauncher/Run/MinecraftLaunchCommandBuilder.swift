import Foundation

struct MinecraftLaunchCommandBuilder {
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
            environment: getCurrentLaunchEnvironment(),
            modClassPath: gameInfo.modClassPath
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
            "clientid": AppConstants.clientId,
            "auth_xuid": "${auth_xuid}",
            "user_type": "msa",
            "version_type": "SCL",
            "natives_directory": paths.nativesDir,
            "launcher_name": Bundle.main.appName,
            "launcher_version": launcherVersion,
            "classpath": classpath
        ]

        // 优先解析 arguments 字段
        var jvmArgs = manifest.arguments.jvm?
            .map { substituteVariables($0, with: variableMap) } ?? []
        var gameArgs = manifest.arguments.game?
            .map { substituteVariables($0, with: variableMap) } ?? []

        // 额外拼接 JVM 内存参数
        let globalXms = GameSettingsManager.shared.globalXms
        let globalXmx = GameSettingsManager.shared.globalXmx
        let useGameMemory = gameInfo.xms > 0 && gameInfo.xmx > 0
        let xmsArg = "-Xms\((useGameMemory ? gameInfo.xms : globalXms))M"
        let xmxArg = "-Xmx\((useGameMemory ? gameInfo.xmx : globalXmx))M"
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
    private static func validateAndGetPaths(gameInfo: GameVersionInfo, manifest: MinecraftVersionManifest) throws -> (nativesDir: String, librariesDir: URL, assetsDir: String, gameDir: String, clientJarPath: String) {
        // 验证 natives 目录
        guard let nativesDir = AppPaths.nativesDirectory?.path else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取 natives 目录路径",
                i18nKey: "error.configuration.natives_directory_not_found",
                level: .popup
            )
        }
        
        // 验证 libraries 目录
        guard let librariesDir = AppPaths.librariesDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取 libraries 目录路径",
                i18nKey: "error.configuration.libraries_directory_not_found",
                level: .popup
            )
        }
        
        // 验证 assets 目录
        guard let assetsDir = AppPaths.assetsDirectory?.path else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取 assets 目录路径",
                i18nKey: "error.configuration.assets_directory_not_found",
                level: .popup
            )
        }
        
        // 验证游戏目录
        guard let gameDir = AppPaths.profileDirectory(gameName: gameInfo.gameName)?.path else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取游戏目录路径: \(gameInfo.gameName)",
                i18nKey: "error.configuration.game_directory_not_found",
                level: .popup
            )
        }
        
        // 验证 versions 目录
        guard let versionsDir = AppPaths.versionsDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取 versions 目录路径",
                i18nKey: "error.configuration.versions_directory_not_found",
                level: .popup
            )
        }
        
        // 验证客户端 JAR 文件
        let clientJarPath = versionsDir.appendingPathComponent(manifest.id).appendingPathComponent("\(manifest.id).jar").path
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: clientJarPath) else {
            throw GlobalError.resource(
                chineseMessage: "客户端 JAR 文件不存在: \(clientJarPath)",
                i18nKey: "error.resource.client_jar_not_found",
                level: .popup
            )
        }
        
        return (nativesDir: nativesDir, librariesDir: librariesDir, assetsDir: assetsDir, gameDir: gameDir, clientJarPath: clientJarPath)
    }

    private static func substituteVariables(_ arg: String, with map: [String: String]) -> String {
        var result = arg
        for (key, value) in map {
            result = result.replacingOccurrences(of: "${\(key)}", with: value)
        }
        return result
    }

    private static func getCurrentLaunchEnvironment() -> LaunchEnvironment {
        #if os(macOS)
        #if arch(x86_64)
        return LaunchEnvironment(osName: "osx", arch: "x86")
        #elseif arch(arm64)
        return LaunchEnvironment(osName: "osx", arch: "arm64")
        #else
        return LaunchEnvironment(osName: "unknown", arch: "unknown")
        #endif
        #else
        return LaunchEnvironment(osName: "unknown", arch: "unknown")
        #endif
    }

    private static func buildClasspath(_ libraries: [Library], librariesDir: URL, clientJarPath: String, environment: LaunchEnvironment, modClassPath: String) -> String {
        // 1. 拆分 modClassPath，提取 basePath 集合（相对路径）
        let librariesDirPath = librariesDir.path.hasSuffix("/") ? librariesDir.path : librariesDir.path + "/"
        let modClassPathArray = modClassPath.split(separator: ":").map { String($0) }
        let modClassBasePaths: Set<String> = Set(modClassPathArray.compactMap { path in
            guard path.hasPrefix(librariesDirPath) else { return nil }
            let relPath = String(path.dropFirst(librariesDirPath.count))
            let pathComponents = relPath.split(separator: "/")
            guard pathComponents.count >= 2 else { return nil }
            return pathComponents.dropLast(2).joined(separator: "/")
        })

        // 2. 遍历 libraries，先根据 rules 判断是否允许 osx，再做 basePath 去重
        let manifestLibraryPaths = libraries.compactMap { library -> [String]? in
            guard shouldIncludeLibrary(library) else { return nil }
            let artifact = library.downloads.artifact
            let libraryPath = librariesDir.appendingPathComponent(artifact.path).path
            let pathComponents = artifact.path.split(separator: "/")
            guard pathComponents.count >= 2 else { return nil }
            let basePath = pathComponents.dropLast(2).joined(separator: "/")
            if modClassBasePaths.contains(basePath) {
                return nil // modClassPath 已有，跳过
            }
            var paths = [libraryPath]
            // 加入 classifiers
            if let classifiers = library.downloads.classifiers {
                for classifierArtifact in classifiers.values {
                    let classifierPath = librariesDir.appendingPathComponent(classifierArtifact.path).path
                    paths.append(classifierPath)
                }
            }
            return paths
        }.flatMap { $0 }

        // 3. 拼接 manifest.libraries + modClassPath（原始顺序）+ clientJarPath
        let classpathList = manifestLibraryPaths + [clientJarPath] + modClassPathArray
        return classpathList.joined(separator: ":")
    }

    // 判断该库是否适用于 osx
    private static func shouldIncludeLibrary(_ library: Library) -> Bool {
        guard let rules = library.rules, !rules.isEmpty else {
            return true // 没有规则，直接放行
        }
        var allowed = false
        for rule in rules {
            if let os = rule.os, let name = os.name, name == "osx" {
                if rule.action == "disallow" {
                    return false // 有 disallow，直接禁止
                } else if rule.action == "allow" {
                    allowed = true // 有 allow，允许
                }
            }
        }
        return allowed
    }
}

struct LaunchEnvironment {
    let osName: String
    let arch: String
}

