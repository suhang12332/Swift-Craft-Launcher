import Foundation

extension LauncherInstallationScanner {
    private static let officialLauncherIgnoredVersionIDs: Set<String> = [
        "latest-release",
        "latest-snapshot",
    ]
    private static let primaryGameMarkerNames: Set<String> = [
        AppConstants.DirectoryNames.mods,
        AppConstants.DirectoryNames.config,
        AppConstants.DirectoryNames.saves,
        AppConstants.DirectoryNames.resourcepacks,
        AppConstants.DirectoryNames.shaderpacks,
        AppConstants.DirectoryNames.datapacks,
        AppConstants.DirectoryNames.option,
        "defaultconfigs",
    ]
    private static let genericMetadataFileNames: Set<String> = [
        "hmclversion.cfg",
        "modrinth.index.json",
        "manifest.json",
        "profile.json",
        "instance.json",
        "minecraftinstance.json",
        "mmc-pack.json",
        "instance.cfg",
    ]
    private static let genericContainerNames: Set<String> = [
        "instances",
        "profiles",
        "versions",
        "libraries",
        "assets",
        "runtime",
        "meta",
        "cache",
        "downloads",
        "install",
        "java",
    ]

    static func heuristicInstances(
        in rootPath: URL,
        excluding excludedPaths: Set<String>
    ) -> [ScannedLauncherInstance] {
        var results = [String: ScannedLauncherInstance]()

        func append(_ instance: ScannedLauncherInstance) {
            let instancePath = instance.instancePath.standardizedFileURL.path
            let sourcePath = instance.info.sourceGameDirectory.standardizedFileURL.path
            guard !isCoveredPath(instancePath, excludedPaths: excludedPaths),
                  !isCoveredPath(sourcePath, excludedPaths: excludedPaths) else {
                return
            }
            results[instance.id] = instance
        }

        for instance in launcherProfileInstances(in: rootPath, excluding: excludedPaths) {
            append(instance)
        }

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootPath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return Array(results.values)
        }

        for case let url as URL in enumerator {
            let standardizedURL = url.standardizedFileURL
            let pathComponents = standardizedURL.pathComponents
            if pathComponents.count - rootPath.standardizedFileURL.pathComponents.count > recursiveScanDepthLimit {
                enumerator.skipDescendants()
                continue
            }

            let name = standardizedURL.lastPathComponent
            if shouldSkip(url: standardizedURL, name: name) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? standardizedURL.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isDirectory == true else {
                continue
            }

            if genericContainerNames.contains(name.lowercased()) {
                continue
            }

            guard looksLikeStandaloneGameDirectory(standardizedURL) else {
                continue
            }

            if let instance = heuristicInstance(at: standardizedURL, preferredName: nil) {
                append(instance)
            }
        }

        return results.values.sorted {
            $0.info.gameName.localizedCaseInsensitiveCompare($1.info.gameName) == .orderedAscending
        }
    }

    static func officialLauncherInstances(within rootPath: URL) -> [ScannedLauncherInstance] {
        let fileManager = FileManager.default
        var results = [String: ScannedLauncherInstance]()
        var sharedRootPaths = Set<String>()

        func append(_ instance: ScannedLauncherInstance) {
            results[instance.id] = instance
        }

        for profileFile in officialLauncherProfileFiles(in: rootPath) {
            guard let profiles = parseLauncherProfiles(at: profileFile) else {
                continue
            }

            let defaultGameDirectory = profileFile.deletingLastPathComponent()
            for profile in profiles {
                let displayName = resolvedOfficialProfileName(
                    profile: profile,
                    defaultGameDirectory: defaultGameDirectory
                )
                let sourceGameDirectory = (profile.gameDirectory ?? defaultGameDirectory).standardizedFileURL
                if profile.gameDirectory == nil ||
                    sourceGameDirectory.path == defaultGameDirectory.standardizedFileURL.path {
                    sharedRootPaths.insert(sourceGameDirectory.path)
                }

                guard shouldImportOfficialProfile(
                    profile,
                    sourceGameDirectory: sourceGameDirectory,
                    defaultGameDirectory: defaultGameDirectory,
                    fileManager: fileManager
                ) else {
                    continue
                }

                guard let metadata = inferMetadata(
                    for: sourceGameDirectory,
                    preferredName: displayName,
                    lastVersionID: profile.lastVersionID
                ) else {
                    continue
                }

                guard !metadata.gameVersion.isEmpty,
                      AppConstants.modLoaders.contains(metadata.modLoader.lowercased()) else {
                    continue
                }

                let info = ImportInstanceInfo(
                    gameName: metadata.gameName,
                    gameVersion: metadata.gameVersion,
                    modLoader: metadata.modLoader,
                    modLoaderVersion: metadata.modLoaderVersion,
                    gameIconPath: nil,
                    iconDownloadUrl: nil,
                    sourceGameDirectory: sourceGameDirectory,
                    launcherType: .officialLauncher
                )

                let stableID = [
                    "official",
                    profile.profileKey,
                    sourceGameDirectory.path,
                    profile.lastVersionID ?? "",
                ].joined(separator: "::")

                append(ScannedLauncherInstance(
                    instancePath: sourceGameDirectory,
                    info: info,
                    stableID: stableID
                ))
            }
        }

        let excludedPaths = Set(
            results.values.flatMap {
                [
                    $0.instancePath.standardizedFileURL.path,
                    $0.info.sourceGameDirectory.standardizedFileURL.path,
                ]
            }
            .filter { !sharedRootPaths.contains($0) }
        )

        for instance in heuristicInstances(in: rootPath, excluding: excludedPaths) {
            let info = ImportInstanceInfo(
                gameName: instance.info.gameName,
                gameVersion: instance.info.gameVersion,
                modLoader: instance.info.modLoader,
                modLoaderVersion: instance.info.modLoaderVersion,
                gameIconPath: instance.info.gameIconPath,
                iconDownloadUrl: instance.info.iconDownloadUrl,
                sourceGameDirectory: instance.info.sourceGameDirectory,
                launcherType: .officialLauncher
            )
            let stableID = [
                "official-heuristic",
                instance.instancePath.standardizedFileURL.path,
                instance.info.gameVersion,
                instance.info.modLoader,
            ].joined(separator: "::")
            append(
                ScannedLauncherInstance(
                    instancePath: instance.instancePath,
                    info: info,
                    stableID: stableID
                )
            )
        }

        let discoveredDirectories = discoveredInstanceDirectories(in: rootPath)
        for launcherType in concreteLaunchers where launcherType != .officialLauncher {
            let parser = LauncherInstanceParserFactory.createParser(for: launcherType)
            let candidateDirectories = collectedCandidateDirectories(
                for: launcherType,
                rootPath: rootPath,
                discoveredDirectories: discoveredDirectories[launcherType] ?? []
            )

            for instance in parseCandidates(
                candidateDirectories,
                parser: parser,
                launcherType: launcherType
            ) {
                append(instance)
            }
        }

        return results.values.sorted {
            $0.info.gameName.localizedCaseInsensitiveCompare($1.info.gameName) == .orderedAscending
        }
    }

    static func officialLauncherInstancesProgressively(
        within rootPath: URL,
        emit: @escaping (ScannedLauncherInstance) -> Void
    ) async {
        let fileManager = FileManager.default
        var merged = [String: ScannedLauncherInstance]()
        var sharedRootPaths = Set<String>()

        func append(_ instance: ScannedLauncherInstance) {
            merged[instance.id] = instance
            emit(instance)
        }

        for profileFile in officialLauncherProfileFiles(in: rootPath) {
            guard !Task.isCancelled,
                  let profiles = parseLauncherProfiles(at: profileFile) else {
                continue
            }

            let defaultGameDirectory = profileFile.deletingLastPathComponent()
            for profile in profiles {
                guard !Task.isCancelled else { return }

                let displayName = resolvedOfficialProfileName(
                    profile: profile,
                    defaultGameDirectory: defaultGameDirectory
                )
                let sourceGameDirectory = (profile.gameDirectory ?? defaultGameDirectory).standardizedFileURL
                if profile.gameDirectory == nil ||
                    sourceGameDirectory.path == defaultGameDirectory.standardizedFileURL.path {
                    sharedRootPaths.insert(sourceGameDirectory.path)
                }

                guard shouldImportOfficialProfile(
                    profile,
                    sourceGameDirectory: sourceGameDirectory,
                    defaultGameDirectory: defaultGameDirectory,
                    fileManager: fileManager
                ) else {
                    continue
                }

                guard let metadata = inferMetadata(
                    for: sourceGameDirectory,
                    preferredName: displayName,
                    lastVersionID: profile.lastVersionID
                ) else {
                    continue
                }

                guard !metadata.gameVersion.isEmpty,
                      AppConstants.modLoaders.contains(metadata.modLoader.lowercased()) else {
                    continue
                }

                let info = ImportInstanceInfo(
                    gameName: metadata.gameName,
                    gameVersion: metadata.gameVersion,
                    modLoader: metadata.modLoader,
                    modLoaderVersion: metadata.modLoaderVersion,
                    gameIconPath: nil,
                    iconDownloadUrl: nil,
                    sourceGameDirectory: sourceGameDirectory,
                    launcherType: .officialLauncher
                )

                let stableID = [
                    "official",
                    profile.profileKey,
                    sourceGameDirectory.path,
                    profile.lastVersionID ?? "",
                ].joined(separator: "::")

                append(
                    ScannedLauncherInstance(
                        instancePath: sourceGameDirectory,
                        info: info,
                        stableID: stableID
                    )
                )
            }
        }

        guard !Task.isCancelled else { return }

        let discoveredDirectories = discoveredInstanceDirectories(in: rootPath)
        for launcherType in concreteLaunchers where launcherType != .officialLauncher {
            guard !Task.isCancelled else { return }

            let candidateDirectories = collectedCandidateDirectories(
                for: launcherType,
                rootPath: rootPath,
                discoveredDirectories: discoveredDirectories[launcherType] ?? []
            )

            await parseCandidatesProgressively(
                candidateDirectories,
                launcherType: launcherType
            ) { instance in
                if merged[instance.id] == nil {
                    append(instance)
                }
            }
        }

        guard !Task.isCancelled else { return }

        let excludedPaths = Set(
            merged.values.flatMap {
                [
                    $0.instancePath.standardizedFileURL.path,
                    $0.info.sourceGameDirectory.standardizedFileURL.path,
                ]
            }
            .filter { !sharedRootPaths.contains($0) }
        )

        for instance in heuristicInstances(in: rootPath, excluding: excludedPaths) {
            guard !Task.isCancelled else { return }

            let info = ImportInstanceInfo(
                gameName: instance.info.gameName,
                gameVersion: instance.info.gameVersion,
                modLoader: instance.info.modLoader,
                modLoaderVersion: instance.info.modLoaderVersion,
                gameIconPath: instance.info.gameIconPath,
                iconDownloadUrl: instance.info.iconDownloadUrl,
                sourceGameDirectory: instance.info.sourceGameDirectory,
                launcherType: .officialLauncher
            )
            let stableID = [
                "official-heuristic",
                instance.instancePath.standardizedFileURL.path,
                instance.info.gameVersion,
                instance.info.modLoader,
            ].joined(separator: "::")

            let scannedInstance = ScannedLauncherInstance(
                instancePath: instance.instancePath,
                info: info,
                stableID: stableID
            )
            if merged[scannedInstance.id] == nil {
                append(scannedInstance)
            }
        }
    }

    private static func launcherProfileInstances(
        in rootPath: URL,
        excluding excludedPaths: Set<String>
    ) -> [ScannedLauncherInstance] {
        var results = [ScannedLauncherInstance]()
        let fileManager = FileManager.default

        for profileFile in officialLauncherProfileFiles(in: rootPath) {
            guard let profiles = parseLauncherProfiles(at: profileFile) else {
                continue
            }

            for profile in profiles {
                guard let gameDirectory = profile.gameDirectory else {
                    continue
                }
                let standardizedDirectory = gameDirectory.standardizedFileURL
                guard fileManager.fileExists(atPath: standardizedDirectory.path),
                      !isCoveredPath(standardizedDirectory.path, excludedPaths: excludedPaths),
                      looksLikeStandaloneGameDirectory(standardizedDirectory) ||
                        containsPrimaryGameData(in: standardizedDirectory) else {
                    continue
                }

                if let instance = heuristicInstance(
                    at: standardizedDirectory,
                    preferredName: profile.displayName,
                    lastVersionID: profile.lastVersionID
                ) {
                    results.append(instance)
                }
            }
        }

        return results
    }

    private static func heuristicInstance(
        at directory: URL,
        preferredName: String?,
        lastVersionID: String? = nil
    ) -> ScannedLauncherInstance? {
        guard let metadata = inferMetadata(
            for: directory,
            preferredName: preferredName,
            lastVersionID: lastVersionID
        ) else {
            return nil
        }

        guard !metadata.gameVersion.isEmpty,
              AppConstants.modLoaders.contains(metadata.modLoader.lowercased()) else {
            return nil
        }

        let info = ImportInstanceInfo(
            gameName: metadata.gameName,
            gameVersion: metadata.gameVersion,
            modLoader: metadata.modLoader,
            modLoaderVersion: metadata.modLoaderVersion,
            gameIconPath: nil,
            iconDownloadUrl: nil,
            sourceGameDirectory: directory,
            launcherType: .all
        )

        return ScannedLauncherInstance(instancePath: directory, info: info, stableID: nil)
    }

    private static func inferMetadata(
        for directory: URL,
        preferredName: String?,
        lastVersionID: String?
    ) -> HeuristicInstanceMetadata? {
        let trimmedName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? directory.lastPathComponent

        if let metadata = parseModrinthIndexMetadata(in: directory, preferredName: baseName) {
            return metadata
        }

        if let metadata = parseCurseForgeManifestMetadata(in: directory, preferredName: baseName) {
            return metadata
        }

        if let metadata = parseVersionJSONMetadata(in: directory, preferredName: baseName) {
            return metadata
        }

        if let lastVersionID {
            let inferred = inferLoaderAndGameVersion(from: lastVersionID)
            if !inferred.gameVersion.isEmpty {
                return HeuristicInstanceMetadata(
                    gameName: baseName,
                    gameVersion: inferred.gameVersion,
                    modLoader: inferred.modLoader,
                    modLoaderVersion: inferred.modLoaderVersion
                )
            }
        }

        if let folderVersion = extractMinecraftVersion(from: directory.lastPathComponent) {
            return HeuristicInstanceMetadata(
                gameName: baseName,
                gameVersion: folderVersion,
                modLoader: GameLoader.vanilla.displayName,
                modLoaderVersion: ""
            )
        }

        return nil
    }

    private static func parseVersionJSONMetadata(
        in directory: URL,
        preferredName: String
    ) -> HeuristicInstanceMetadata? {
        let fileManager = FileManager.default
        let candidates = [
            directory.appendingPathComponent("\(directory.lastPathComponent).json"),
            directory.appendingPathComponent("version.json"),
        ]

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            guard let data = try? Data(contentsOf: candidate),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let gameVersion = extractVersionJSONGameVersion(json)
            let loader = extractVersionJSONLoader(json)
            if gameVersion.isEmpty {
                continue
            }

            return HeuristicInstanceMetadata(
                gameName: preferredName,
                gameVersion: gameVersion,
                modLoader: loader.modLoader,
                modLoaderVersion: loader.modLoaderVersion
            )
        }

        return nil
    }

    private static func extractVersionJSONGameVersion(_ json: [String: Any]) -> String {
        if let inheritsFrom = json["inheritsFrom"] as? String,
           let version = extractMinecraftVersion(from: inheritsFrom) {
            return version
        }

        if let patches = json["patches"] as? [[String: Any]] {
            for patch in patches {
                if let version = patch["version"] as? String,
                   let normalized = extractMinecraftVersion(from: version) ?? (!version.isEmpty ? version : nil) {
                    return normalized
                }
            }
        }

        if let arguments = json["arguments"] as? [String: Any],
           let gameArgs = arguments["game"] as? [Any] {
            for (index, value) in gameArgs.enumerated() {
                guard let argument = value as? String else {
                    continue
                }
                if argument == "--fml.mcVersion",
                   index + 1 < gameArgs.count,
                   let version = gameArgs[index + 1] as? String {
                    return version
                }
            }
        }

        if let identifier = json["id"] as? String,
           let version = extractMinecraftVersion(from: identifier) {
            return version
        }

        return ""
    }

    private static func extractVersionJSONLoader(
        _ json: [String: Any]
    ) -> (modLoader: String, modLoaderVersion: String) {
        if let libraries = json["libraries"] as? [[String: Any]] {
            for library in libraries {
                guard let name = library["name"] as? String else {
                    continue
                }

                if name.contains("net.fabricmc:fabric-loader:") {
                    return (GameLoader.fabric.displayName, name.components(separatedBy: ":").last ?? "")
                }
                if name.contains("net.minecraftforge:forge:") {
                    return (GameLoader.forge.displayName, name.components(separatedBy: ":").last ?? "")
                }
                if name.contains("net.neoforged:neoforge:") {
                    return (GameLoader.neoforge.displayName, name.components(separatedBy: ":").last ?? "")
                }
                if name.contains("org.quiltmc:quilt-loader:") {
                    return (GameLoader.quilt.rawValue, name.components(separatedBy: ":").last ?? "")
                }
            }
        }

        return (GameLoader.vanilla.displayName, "")
    }

    private static func parseCurseForgeManifestMetadata(
        in directory: URL,
        preferredName: String
    ) -> HeuristicInstanceMetadata? {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let minecraft = json["minecraft"] as? [String: Any],
              let gameVersion = minecraft["version"] as? String else {
            return nil
        }

        let loaderID = ((minecraft["modLoaders"] as? [[String: Any]])?.first?["id"] as? String) ?? ""
        let loader = inferLoaderAndGameVersion(from: loaderID)

        return HeuristicInstanceMetadata(
            gameName: preferredName,
            gameVersion: gameVersion,
            modLoader: loader.modLoader,
            modLoaderVersion: loader.modLoaderVersion
        )
    }

    private static func parseModrinthIndexMetadata(
        in directory: URL,
        preferredName: String
    ) -> HeuristicInstanceMetadata? {
        let indexURL = directory.appendingPathComponent("modrinth.index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dependencies = json["dependencies"] as? [String: Any] else {
            return nil
        }

        let gameVersion = dependencies["minecraft"] as? String ?? ""
        if gameVersion.isEmpty {
            return nil
        }

        let loaderOrder: [(String, String)] = [
            ("fabric-loader", GameLoader.fabric.displayName),
            ("forge", GameLoader.forge.displayName),
            ("neoforge", GameLoader.neoforge.displayName),
            ("quilt-loader", GameLoader.quilt.rawValue),
        ]

        for (key, loaderName) in loaderOrder {
            if let version = dependencies[key] as? String, !version.isEmpty {
                return HeuristicInstanceMetadata(
                    gameName: preferredName,
                    gameVersion: gameVersion,
                    modLoader: loaderName,
                    modLoaderVersion: version
                )
            }
        }

        return HeuristicInstanceMetadata(
            gameName: preferredName,
            gameVersion: gameVersion,
            modLoader: GameLoader.vanilla.displayName,
            modLoaderVersion: ""
        )
    }

    private static func parseLauncherProfiles(at url: URL) -> [LauncherProfileEntry]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = json["profiles"] as? [String: Any] else {
            return nil
        }

        return profiles.compactMap { profileKey, rawValue in
            guard let profile = rawValue as? [String: Any] else {
                return nil
            }

            let name = (profile["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let gameDirPath = (profile["gameDir"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastVersionID = (profile["lastVersionId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileType = (profile["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let gameDirectory: URL?
            if let gameDirPath, !gameDirPath.isEmpty {
                let expandedPath = (gameDirPath as NSString).expandingTildeInPath
                gameDirectory = URL(fileURLWithPath: expandedPath)
            } else {
                gameDirectory = nil
            }

            return LauncherProfileEntry(
                profileKey: profileKey,
                displayName: name?.isEmpty == false ? name : nil,
                gameDirectory: gameDirectory,
                lastVersionID: lastVersionID?.isEmpty == false ? lastVersionID : nil,
                profileType: profileType?.isEmpty == false ? profileType : nil
            )
        }
    }

    private static func inferLoaderAndGameVersion(
        from rawIdentifier: String
    ) -> (modLoader: String, modLoaderVersion: String, gameVersion: String) {
        let normalized = rawIdentifier.lowercased()
        let gameVersion = extractMinecraftVersion(from: rawIdentifier) ?? ""

        if normalized.contains("fabric") {
            return (
                GameLoader.fabric.displayName,
                extractLoaderVersion(from: rawIdentifier, marker: "fabric") ?? "",
                gameVersion
            )
        }
        if normalized.contains("quilt") {
            return (
                GameLoader.quilt.rawValue,
                extractLoaderVersion(from: rawIdentifier, marker: "quilt") ?? "",
                gameVersion
            )
        }
        if normalized.contains("neoforge") {
            return (
                GameLoader.neoforge.displayName,
                extractLoaderVersion(from: rawIdentifier, marker: "neoforge") ?? "",
                gameVersion
            )
        }
        if normalized.contains("forge") {
            return (
                GameLoader.forge.displayName,
                extractLoaderVersion(from: rawIdentifier, marker: "forge") ?? "",
                gameVersion
            )
        }

        return (GameLoader.vanilla.displayName, "", gameVersion)
    }

    private static func extractMinecraftVersion(from text: String) -> String? {
        let pattern = #"\b\d+\.\d+(?:\.\d+)?(?:-(?:pre|rc)\d+)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: text,
                  options: [],
                  range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func extractLoaderVersion(from text: String, marker: String) -> String? {
        let lowercased = text.lowercased()
        guard let range = lowercased.range(of: marker) else {
            return nil
        }

        let suffix = text[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
        guard !suffix.isEmpty else {
            return nil
        }

        if let gameVersion = extractMinecraftVersion(from: String(suffix)),
           let gameRange = suffix.range(of: gameVersion) {
            let loaderVersion = suffix[..<gameRange.lowerBound]
                .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            return loaderVersion.isEmpty ? nil : String(loaderVersion)
        }

        return String(suffix)
    }

    private static func looksLikeStandaloneGameDirectory(_ url: URL) -> Bool {
        guard containsPrimaryGameData(in: url) else {
            return false
        }

        let contents = Set(directoryEntryNames(at: url))
        if contents.contains("versions"),
           !contents.contains(AppConstants.DirectoryNames.mods),
           !contents.contains(AppConstants.DirectoryNames.option),
           !contents.contains(AppConstants.DirectoryNames.saves) {
            return false
        }

        if genericMetadataFileNames.contains(where: contents.contains) {
            return true
        }

        let versionJSONName = "\(url.lastPathComponent).json"
        if contents.contains(versionJSONName) {
            return true
        }

        let markerCount = contents.filter { primaryGameMarkerNames.contains($0) }.count
        return markerCount >= 2
    }

    private static func containsPrimaryGameData(in url: URL) -> Bool {
        let contents = Set(directoryEntryNames(at: url))
        return contents.contains(where: primaryGameMarkerNames.contains)
    }

    private static func directoryEntryNames(at url: URL) -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.map(\.lastPathComponent)
    }

    private static func isCoveredPath(
        _ candidatePath: String,
        excludedPaths: Set<String>
    ) -> Bool {
        excludedPaths.contains { path in
            candidatePath == path ||
                candidatePath.hasPrefix(path + "/") ||
                path.hasPrefix(candidatePath + "/")
        }
    }

    private static func officialLauncherProfileFiles(in rootPath: URL) -> [URL] {
        let fileManager = FileManager.default
        let directCandidates = [
            rootPath.appendingPathComponent("launcher_profiles.json"),
            rootPath.appendingPathComponent(".minecraft/launcher_profiles.json"),
            rootPath.appendingPathComponent("minecraft/launcher_profiles.json"),
            rootPath.appendingPathComponent("Library/Application Support/minecraft/launcher_profiles.json"),
            rootPath.appendingPathComponent("Library/Application Support/.minecraft/launcher_profiles.json"),
        ]

        var results = [URL]()
        var seenPaths = Set<String>()

        func append(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted,
                  fileManager.fileExists(atPath: normalized) else {
                return
            }
            results.append(url.standardizedFileURL)
        }

        directCandidates.forEach(append)

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        if let enumerator = fileManager.enumerator(
            at: rootPath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) {
            for case let url as URL in enumerator {
                let standardizedURL = url.standardizedFileURL
                let pathComponents = standardizedURL.pathComponents
                if pathComponents.count - rootPath.standardizedFileURL.pathComponents.count > recursiveScanDepthLimit {
                    continue
                }

                if shouldSkip(url: standardizedURL, name: standardizedURL.lastPathComponent) {
                    continue
                }

                if standardizedURL.lastPathComponent == "launcher_profiles.json" {
                    append(standardizedURL)
                }
            }
        }

        return results.sorted { $0.path < $1.path }
    }

    private static func shouldImportOfficialProfile(
        _ profile: LauncherProfileEntry,
        sourceGameDirectory: URL,
        defaultGameDirectory: URL,
        fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: sourceGameDirectory.path) else {
            return false
        }

        if let explicitGameDirectory = profile.gameDirectory {
            let standardizedDirectory = explicitGameDirectory.standardizedFileURL
            return looksLikeStandaloneGameDirectory(standardizedDirectory) ||
                containsPrimaryGameData(in: standardizedDirectory)
        }

        let normalizedVersionID = profile.lastVersionID?.lowercased()
        if profile.displayName == nil,
           profile.profileType?.hasPrefix("latest-") == true {
            return false
        }

        if profile.displayName == nil,
           let normalizedVersionID,
           officialLauncherIgnoredVersionIDs.contains(normalizedVersionID) {
            return false
        }

        if sourceGameDirectory.standardizedFileURL.path != defaultGameDirectory.standardizedFileURL.path,
           !containsPrimaryGameData(in: sourceGameDirectory) {
            return false
        }

        return looksLikeStandaloneGameDirectory(sourceGameDirectory) ||
            containsPrimaryGameData(in: sourceGameDirectory)
    }

    private static func resolvedOfficialProfileName(
        profile: LauncherProfileEntry,
        defaultGameDirectory: URL
    ) -> String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return displayName
        }

        if let gameDirectory = profile.gameDirectory {
            let lastComponent = gameDirectory.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !lastComponent.isEmpty,
               lastComponent != defaultGameDirectory.lastPathComponent {
                return lastComponent
            }
        }

        return "launcher.import.default_game_name".localized()
    }
}

private struct LauncherProfileEntry {
    let profileKey: String
    let displayName: String?
    let gameDirectory: URL?
    let lastVersionID: String?
    let profileType: String?
}

private struct HeuristicInstanceMetadata {
    let gameName: String
    let gameVersion: String
    let modLoader: String
    let modLoaderVersion: String
}
