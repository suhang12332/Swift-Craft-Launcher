import Foundation

extension LauncherInstallationScanner {
    static func configuredInstanceDirectories(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> [URL] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        switch launcherType {
        case .prismLauncher:
            return resolvedConfiguredDirectories(
                configKeys: ["InstanceDir"],
                configFiles: [rootPath.appendingPathComponent("prismlauncher.cfg")],
                rootPath: rootPath,
                fileManager: fileManager
            )
        case .multiMC:
            return resolvedConfiguredDirectories(
                configKeys: ["InstanceDir"],
                configFiles: [rootPath.appendingPathComponent("multimc.cfg")],
                rootPath: rootPath,
                fileManager: fileManager
            )
        case .hmcl:
            return resolvedHMCLDirectories(
                rootPath: rootPath,
                fileManager: fileManager,
                homeDirectory: homeDirectory
            )
        case .sjmcLauncher:
            return resolvedSJMCLDirectories(
                rootPath: rootPath,
                fileManager: fileManager,
                homeDirectory: homeDirectory
            )
        case .xmcl:
            return resolvedXMCLDirectories(
                rootPath: rootPath,
                fileManager: fileManager,
                homeDirectory: homeDirectory
            )
        case .gdLauncher:
            return resolvedGDLauncherRuntimeDirectories(
                rootPath: rootPath,
                fileManager: fileManager,
                homeDirectory: homeDirectory
            )
        default:
            return []
        }
    }

    private static func resolvedConfiguredDirectories(
        configKeys: [String],
        configFiles: [URL],
        rootPath: URL,
        fileManager: FileManager
    ) -> [URL] {
        var results = [URL]()
        var seenPaths = Set<String>()

        for configFile in configFiles where fileManager.fileExists(atPath: configFile.path) {
            guard let entries = parseSimpleConfig(at: configFile) else {
                continue
            }

            for key in configKeys {
                guard let rawValue = entries[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawValue.isEmpty else {
                    continue
                }

                let resolvedURL = resolveConfiguredPath(
                    rawValue,
                    rootPath: rootPath,
                    configFile: configFile
                )
                let normalized = resolvedURL.standardizedFileURL.path
                guard seenPaths.insert(normalized).inserted,
                      fileManager.fileExists(atPath: normalized) else {
                    continue
                }
                results.append(resolvedURL)
            }
        }

        return results
    }

    private static func resolvedHMCLDirectories(
        rootPath: URL,
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        var configCandidates = [
            rootPath.appendingPathComponent(".hmcl.json"),
            rootPath.deletingLastPathComponent().appendingPathComponent(".hmcl.json"),
            URL(fileURLWithPath: "/Applications/.hmcl.json"),
            homeDirectory.appendingPathComponent("Applications/.hmcl.json"),
        ]

        if rootPath.standardizedFileURL.path == homeDirectory.standardizedFileURL.path {
            configCandidates.append(
                contentsOf: recursiveConfigFiles(
                    named: ".hmcl.json",
                    within: rootPath,
                    maximumDepth: recursiveScanDepthLimit
                )
            )
        }

        return resolvedJSONConfiguredDirectories(
            configFiles: configCandidates,
            fileManager: fileManager
        ) { json, configFile, _ in
            var results = [URL]()

            if let commonPath = (json["commonpath"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !commonPath.isEmpty {
                results.append(
                    resolveHMCLConfiguredPath(
                        commonPath,
                        configFile: configFile
                    )
                )
            }

            if let configurations = json["configurations"] as? [String: Any] {
                for configurationValue in configurations.values {
                    guard let configuration = configurationValue as? [String: Any] else {
                        continue
                    }

                    if let gameDir = (configuration["gameDir"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !gameDir.isEmpty {
                        results.append(
                            resolveHMCLConfiguredPath(
                                gameDir,
                                configFile: configFile
                            )
                        )
                    }

                    if let global = configuration["global"] as? [String: Any],
                       let globalGameDir = (global["gameDir"] as? String)?
                       .trimmingCharacters(in: .whitespacesAndNewlines),
                       !globalGameDir.isEmpty {
                        results.append(
                            resolveHMCLConfiguredPath(
                                globalGameDir,
                                configFile: configFile
                            )
                        )
                    }
                }
            }

            return results
        }
    }

    private static func resolvedSJMCLDirectories(
        rootPath: URL,
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        let appSupport = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
        let configCandidates = [
            rootPath.appendingPathComponent("sjmcl.conf.json"),
            rootPath.deletingLastPathComponent().appendingPathComponent("sjmcl.conf.json"),
            appSupport.appendingPathComponent("SJMCL/sjmcl.conf.json"),
        ]

        return resolvedJSONConfiguredDirectories(
            configFiles: configCandidates,
            fileManager: fileManager
        ) { json, _, _ in
            guard let directories = json["localGameDirectories"] as? [[String: Any]] else {
                return []
            }

            return directories.compactMap { directory in
                guard let path = (directory["dir"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !path.isEmpty else {
                    return nil
                }
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            }
        }
    }

    private static func resolvedXMCLDirectories(
        rootPath: URL,
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        let appSupport = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
        let configCandidates = [
            rootPath.appendingPathComponent("instances.json"),
            appSupport.appendingPathComponent("xmcl/instances.json"),
        ]

        return resolvedJSONConfiguredDirectories(
            configFiles: configCandidates,
            fileManager: fileManager
        ) { json, _, _ in
            var results = [URL]()

            if let selectedInstance = (json["selectedInstance"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !selectedInstance.isEmpty {
                results.append(
                    URL(fileURLWithPath: (selectedInstance as NSString).expandingTildeInPath)
                )
            }

            if let instances = json["instances"] as? [String] {
                results.append(
                    contentsOf: instances.compactMap { instancePath in
                        let trimmed = instancePath.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            return nil
                        }
                        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
                    }
                )
            }

            return results
        }
    }

    private static func resolvedGDLauncherRuntimeDirectories(
        rootPath: URL,
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        let appSupport = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
        let markerCandidates = [
            rootPath.appendingPathComponent("runtime_path_override"),
            appSupport.appendingPathComponent("gdlauncher_carbon/runtime_path_override"),
            appSupport.appendingPathComponent("gdlauncher_next/runtime_path_override"),
        ]

        var results = [URL]()
        var seenPaths = Set<String>()

        for marker in markerCandidates where fileManager.fileExists(atPath: marker.path) {
            guard let content = try? String(contentsOf: marker, encoding: .utf8) else {
                continue
            }

            let runtimePath = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !runtimePath.isEmpty else {
                continue
            }

            let resolvedURL = URL(fileURLWithPath: (runtimePath as NSString).expandingTildeInPath)
            let normalized = resolvedURL.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted,
                  fileManager.fileExists(atPath: normalized) else {
                continue
            }

            results.append(resolvedURL)
        }

        return results
    }

    private static func resolvedJSONConfiguredDirectories(
        configFiles: [URL],
        fileManager: FileManager,
        extractor: ([String: Any], URL, URL) -> [URL]
    ) -> [URL] {
        var results = [URL]()
        var seenPaths = Set<String>()

        for configFile in configFiles where fileManager.fileExists(atPath: configFile.path) {
            guard let data = try? Data(contentsOf: configFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            for candidate in extractor(json, configFile, configFile.deletingLastPathComponent()) {
                let normalized = candidate.standardizedFileURL.path
                guard seenPaths.insert(normalized).inserted,
                      fileManager.fileExists(atPath: normalized) else {
                    continue
                }
                results.append(candidate.standardizedFileURL)
            }
        }

        return results
    }

    static func hmclConfigurationInstanceDirectories(from launcherJarPath: URL) -> [URL] {
        let fileManager = FileManager.default
        let launcherDirectory = launcherJarPath.deletingLastPathComponent()
        let configFiles = hmclConfigFiles(near: launcherDirectory, fileManager: fileManager)
        var results = [URL]()
        var seenPaths = Set<String>()

        func append(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted,
                  fileManager.fileExists(atPath: normalized) else {
                return
            }
            results.append(url)
        }

        for configFile in configFiles {
            guard let data = try? Data(contentsOf: configFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let configurations = json["configurations"] as? [String: Any] else {
                continue
            }

            for configurationValue in configurations.values {
                guard let configuration = configurationValue as? [String: Any],
                      let selectedVersion = (configuration["selectedMinecraftVersion"] as? String)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                      !selectedVersion.isEmpty else {
                    continue
                }

                let gameDirectoryPath = (
                    (configuration["gameDir"] as? String) ??
                        ((configuration["global"] as? [String: Any])?["gameDir"] as? String)
                )?.trimmingCharacters(in: .whitespacesAndNewlines)

                guard let gameDirectoryPath,
                      !gameDirectoryPath.isEmpty else {
                    continue
                }

                let resolvedGameDirectory = URL(
                    fileURLWithPath: (gameDirectoryPath as NSString).expandingTildeInPath
                )
                let versionDirectory = resolvedGameDirectory
                    .appendingPathComponent("versions")
                    .appendingPathComponent(selectedVersion)
                append(versionDirectory)
            }
        }

        return results
    }

    private static func hmclConfigFiles(
        near launcherDirectory: URL,
        fileManager: FileManager
    ) -> [URL] {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            launcherDirectory.appendingPathComponent(".hmcl.json"),
            launcherDirectory.deletingLastPathComponent().appendingPathComponent(".hmcl.json"),
            URL(fileURLWithPath: "/Applications/.hmcl.json"),
            homeDirectory.appendingPathComponent("Applications/.hmcl.json"),
        ]

        var results = [URL]()
        var seenPaths = Set<String>()
        for candidate in candidates {
            let normalized = candidate.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted,
                  fileManager.fileExists(atPath: normalized) else {
                continue
            }
            results.append(candidate)
        }

        return results
    }

    private static func recursiveConfigFiles(
        named fileName: String,
        within rootPath: URL,
        maximumDepth: Int
    ) -> [URL] {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        var results = [URL]()
        var seenPaths = Set<String>()

        guard let enumerator = fileManager.enumerator(
            at: rootPath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            let standardizedURL = url.standardizedFileURL
            let pathComponents = standardizedURL.pathComponents
            if pathComponents.count - rootPath.standardizedFileURL.pathComponents.count > maximumDepth {
                continue
            }

            if shouldSkip(url: standardizedURL, name: standardizedURL.lastPathComponent) {
                continue
            }

            guard standardizedURL.lastPathComponent == fileName else {
                continue
            }

            let normalized = standardizedURL.path
            guard seenPaths.insert(normalized).inserted else {
                continue
            }

            results.append(standardizedURL)
        }

        return results
    }

    private static func parseSimpleConfig(at url: URL) -> [String: String]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        var entries = [String: String]()
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") || trimmed.hasPrefix("[") {
                continue
            }

            guard let equalIndex = trimmed.firstIndex(of: "=") else {
                continue
            }

            let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                entries[key] = value
            }
        }

        return entries
    }

    private static func resolveConfiguredPath(
        _ rawPath: String,
        rootPath: URL,
        configFile: URL
    ) -> URL {
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        let nsPath = expandedPath as NSString
        if nsPath.isAbsolutePath {
            return URL(fileURLWithPath: expandedPath)
        }

        let configDirectory = configFile.deletingLastPathComponent()
        let candidates = [
            configDirectory.appendingPathComponent(expandedPath),
            rootPath.appendingPathComponent(expandedPath),
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        return configDirectory.appendingPathComponent(expandedPath)
    }

    private static func resolveHMCLConfiguredPath(
        _ rawPath: String,
        configFile: URL
    ) -> URL {
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        let nsPath = expandedPath as NSString
        if nsPath.isAbsolutePath {
            return URL(fileURLWithPath: expandedPath)
        }

        return configFile.deletingLastPathComponent().appendingPathComponent(expandedPath)
    }
}
