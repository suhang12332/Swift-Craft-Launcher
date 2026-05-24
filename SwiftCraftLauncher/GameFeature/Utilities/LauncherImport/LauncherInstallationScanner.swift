import Foundation

struct ScannedLauncherInstance: Identifiable, Sendable {
    let instancePath: URL
    let info: ImportInstanceInfo
    let stableID: String?

    init(
        instancePath: URL,
        info: ImportInstanceInfo,
        stableID: String? = nil
    ) {
        self.instancePath = instancePath
        self.info = info
        self.stableID = stableID
    }

    var id: String {
        stableID ?? instancePath.standardizedFileURL.path
    }
}

enum LauncherInstallationScanner {
    static let skippedDirectoryNames: Set<String> = [
        ".Trash",
        ".git",
        ".swiftpm",
        ".npm",
        ".cargo",
        "Applications.localized",
        "Caches",
        "DerivedData",
        "Library/Containers",
        "Library/Developer",
        "Library/Mail",
        "Library/Messages",
        "Movies",
        "Music",
        "node_modules",
        "Pictures",
    ]

    static let recursiveScanDepthLimit = 7

    static func autoDetectedRoot(for launcherType: ImportLauncherType) -> URL? {
        if launcherType == .all {
            return FileManager.default.homeDirectoryForCurrentUser
        }

        if launcherType == .hmcl {
            return nil
        }

        let existingRoots = defaultRootCandidates(for: launcherType).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }

        for root in existingRoots where hasPotentialInstances(for: launcherType, rootPath: root) {
            return root
        }

        return existingRoots.first
    }

    static func scanInstancesStream(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> AsyncStream<ScannedLauncherInstance> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await progressiveScanInstances(
                    for: launcherType,
                    rootPath: rootPath
                ) { instance in
                    continuation.yield(instance)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func scanHMCLInstancesStream(
        from launcherJarPath: URL
    ) -> AsyncStream<ScannedLauncherInstance> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let candidateDirectories = hmclCandidateDirectories(from: launcherJarPath)
                await parseCandidatesProgressively(
                    candidateDirectories,
                    launcherType: .hmcl
                ) { instance in
                    continuation.yield(instance)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func scanInstances(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> [ScannedLauncherInstance] {
        if launcherType == .all {
            return aggregateScan(within: rootPath)
        }

        if launcherType == .officialLauncher {
            return officialLauncherInstances(within: rootPath)
        }

        let parser = LauncherInstanceParserFactory.createParser(for: launcherType)
        let candidateDirectories = collectedCandidateDirectories(
            for: launcherType,
            rootPath: rootPath
        )

        return parseCandidates(
            candidateDirectories,
            parser: parser,
            launcherType: launcherType
        )
    }

    static func defaultRootCandidates(for launcherType: ImportLauncherType) -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let appSupport = home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")

        switch launcherType {
        case .all:
            return [home]

        case .officialLauncher:
            return [
                appSupport.appendingPathComponent("minecraft"),
                appSupport.appendingPathComponent(".minecraft"),
                home.appendingPathComponent(".minecraft"),
            ]

        case .prismLauncher:
            return installedLauncherDataDirectories(
                matching: ["Prism Launcher.app", "PrismLauncher.app"],
                fileManager: fileManager,
                homeDirectory: home
            ) + [appSupport.appendingPathComponent("PrismLauncher")]

        case .multiMC:
            return installedLauncherDataDirectories(
                matching: ["MultiMC.app"],
                fileManager: fileManager,
                homeDirectory: home
            ) + [
                appSupport.appendingPathComponent("MultiMC"),
                appSupport.appendingPathComponent("MultiMC/Data"),
            ]

        case .gdLauncher:
            return [
                appSupport.appendingPathComponent("gdlauncher_carbon"),
                appSupport.appendingPathComponent("gdlauncher_next"),
            ]

        case .hmcl:
            return [
                appSupport.appendingPathComponent("hmcl"),
                appSupport.appendingPathComponent("minecraft"),
                home.appendingPathComponent(".minecraft"),
                home,
            ]

        case .sjmcLauncher:
            return [
                appSupport.appendingPathComponent("SJMCL"),
                appSupport.appendingPathComponent("SJMCL/minecraft"),
                appSupport.appendingPathComponent("minecraft"),
            ]

        case .xmcl:
            return [appSupport.appendingPathComponent("xmcl")]

        case .atLauncher:
            return [appSupport.appendingPathComponent(".atlauncher")]

        case .modrinthApp:
            return [
                appSupport.appendingPathComponent("ModrinthApp"),
                appSupport.appendingPathComponent("com.modrinth.theseus"),
            ]

        case .curseForgeApp:
            return [
                home.appendingPathComponent("Documents/curseforge/minecraft"),
                URL(fileURLWithPath: "/Users/Shared/CurseForge/minecraft"),
            ]
        }
    }

    static var concreteLaunchers: [ImportLauncherType] {
        ImportLauncherType.allCases.filter { $0 != .all }
    }

    private static func hasPotentialInstances(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> Bool {
        let fileManager = FileManager.default

        if LauncherInstanceParserFactory.createParser(for: launcherType).isValidInstance(at: rootPath) {
            return true
        }

        for searchRoot in relatedSearchRoots(for: rootPath) {
            if candidateInstanceDirectories(for: launcherType, rootPath: searchRoot).contains(where: {
                fileManager.fileExists(atPath: $0.path)
            }) {
                return true
            }

            if configuredInstanceDirectories(for: launcherType, rootPath: searchRoot).contains(where: {
                fileManager.fileExists(atPath: $0.path)
            }) {
                return true
            }
        }

        return false
    }

    private static func progressiveScanInstances(
        for launcherType: ImportLauncherType,
        rootPath: URL,
        emit: @escaping (ScannedLauncherInstance) -> Void
    ) async {
        if launcherType == .all {
            await aggregateScanProgressively(within: rootPath, emit: emit)
            return
        }

        if launcherType == .officialLauncher {
            await officialLauncherInstancesProgressively(within: rootPath, emit: emit)
            return
        }

        let candidateDirectories = collectedCandidateDirectories(
            for: launcherType,
            rootPath: rootPath
        )

        await parseCandidatesProgressively(
            candidateDirectories,
            launcherType: launcherType,
            emit: emit
        )
    }

    private static func aggregateScanProgressively(
        within rootPath: URL,
        emit: @escaping (ScannedLauncherInstance) -> Void
    ) async {
        var merged = [String: ScannedLauncherInstance]()

        func append(_ instance: ScannedLauncherInstance) {
            merged[instance.id] = instance
            emit(instance)
        }

        for launcherType in concreteLaunchers {
            guard !Task.isCancelled else { return }

            if launcherType == .officialLauncher {
                await officialLauncherInstancesProgressively(within: rootPath, emit: append)
                continue
            }

            let candidateDirectories = collectedCandidateDirectories(
                for: launcherType,
                rootPath: rootPath
            )

            await parseCandidatesProgressively(
                candidateDirectories,
                launcherType: launcherType
            ) { instance in
                append(instance)
            }
        }

        guard !Task.isCancelled else { return }

        let discoveredDirectories = discoveredInstanceDirectories(in: rootPath)
        for launcherType in concreteLaunchers where launcherType != .officialLauncher {
            guard !Task.isCancelled else { return }

            await parseCandidatesProgressively(
                discoveredDirectories[launcherType] ?? [],
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
        )

        for instance in heuristicInstances(in: rootPath, excluding: excludedPaths) where merged[instance.id] == nil {
            guard !Task.isCancelled else { return }
            append(instance)
        }
    }

    static func parseCandidatesProgressively(
        _ candidateDirectories: [URL],
        launcherType: ImportLauncherType,
        emit: @escaping (ScannedLauncherInstance) -> Void
    ) async {
        var seenPaths = Set<String>()
        let uniqueDirectories = candidateDirectories.filter {
            seenPaths.insert($0.standardizedFileURL.path).inserted
        }

        await withTaskGroup(of: ScannedLauncherInstance?.self) { group in
            for directory in uniqueDirectories {
                group.addTask(priority: .userInitiated) {
                    guard !Task.isCancelled else {
                        return nil
                    }

                    let parser = LauncherInstanceParserFactory.createParser(for: launcherType)
                    guard parser.isValidInstance(at: directory) else {
                        return nil
                    }

                    do {
                        let basePath = inferredBasePath(
                            for: launcherType,
                            instancePath: directory
                        )
                        guard let info = try parser.parseInstance(at: directory, basePath: basePath),
                              !info.gameVersion.isEmpty,
                              AppConstants.modLoaders.contains(info.modLoader.lowercased()) else {
                            return nil
                        }

                        return ScannedLauncherInstance(
                            instancePath: directory,
                            info: info,
                            stableID: nil
                        )
                    } catch {
                        Logger.shared.warning("扫描实例失败: \(directory.path), \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await instance in group {
                guard !Task.isCancelled else { return }
                if let instance {
                    emit(instance)
                }
            }
        }
    }

    private static func aggregateScan(within rootPath: URL) -> [ScannedLauncherInstance] {
        let discoveredDirectories = discoveredInstanceDirectories(in: rootPath)
        var merged = [String: ScannedLauncherInstance]()

        for launcherType in concreteLaunchers {
            if launcherType == .officialLauncher {
                for instance in officialLauncherInstances(within: rootPath) {
                    merged[instance.id] = instance
                }
                continue
            }

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
                merged[instance.id] = instance
            }
        }

        let excludedPaths = Set(
            merged.values.flatMap {
                [
                    $0.instancePath.standardizedFileURL.path,
                    $0.info.sourceGameDirectory.standardizedFileURL.path,
                ]
            }
        )

        for instance in heuristicInstances(in: rootPath, excluding: excludedPaths) {
            merged[instance.id] = instance
        }

        return merged.values.sorted {
            $0.info.gameName.localizedCaseInsensitiveCompare($1.info.gameName) == .orderedAscending
        }
    }

    static func collectedCandidateDirectories(
        for launcherType: ImportLauncherType,
        rootPath: URL,
        discoveredDirectories: [URL]? = nil
    ) -> [URL] {
        if launcherType == .hmcl {
            return collectedHMCLCandidateDirectories(rootPath: rootPath)
        }

        var candidates = [URL]()
        var seenPaths = Set<String>()

        func append(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted else {
                return
            }
            candidates.append(url)
        }

        for searchRoot in relatedSearchRoots(for: rootPath) {
            for configuredRoot in configuredInstanceDirectories(
                for: launcherType,
                rootPath: searchRoot
            ) {
                for candidate in candidateInstanceDirectories(
                    for: launcherType,
                    rootPath: configuredRoot
                ) {
                    append(candidate)
                }
            }

            for candidate in candidateInstanceDirectories(
                for: launcherType,
                rootPath: searchRoot
            ) {
                append(candidate)
            }
        }

        for candidate in defaultRootCandidates(for: launcherType) {
            for configuredRoot in configuredInstanceDirectories(
                for: launcherType,
                rootPath: candidate
            ) {
                for nestedCandidate in candidateInstanceDirectories(
                    for: launcherType,
                    rootPath: configuredRoot
                ) {
                    append(nestedCandidate)
                }
            }

            for nestedCandidate in candidateInstanceDirectories(
                for: launcherType,
                rootPath: candidate
            ) {
                append(nestedCandidate)
            }
        }

        let recursiveCandidates = discoveredDirectories ?? discoveredInstanceDirectories(in: rootPath)[launcherType] ?? []
        for candidate in recursiveCandidates {
            append(candidate)
        }

        return candidates
    }

    private static func collectedHMCLCandidateDirectories(rootPath: URL) -> [URL] {
        var candidates = [URL]()
        var seenPaths = Set<String>()

        func append(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted else {
                return
            }
            candidates.append(url)
        }

        for searchRoot in Array(relatedSearchRoots(for: rootPath).prefix(2)) {
            for configuredRoot in configuredInstanceDirectories(
                for: .hmcl,
                rootPath: searchRoot
            ) {
                for candidate in candidateInstanceDirectories(
                    for: .hmcl,
                    rootPath: configuredRoot
                ) {
                    append(candidate)
                }
            }
        }

        return candidates
    }

    private static func hmclCandidateDirectories(from launcherJarPath: URL) -> [URL] {
        let launcherDirectory = launcherJarPath.deletingLastPathComponent()
        var candidates = [URL]()
        var seenPaths = Set<String>()

        func append(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            guard seenPaths.insert(normalized).inserted else {
                return
            }
            candidates.append(url)
        }

        for candidate in hmclConfigurationInstanceDirectories(from: launcherJarPath) {
            append(candidate)
        }

        for configuredRoot in configuredInstanceDirectories(
            for: .hmcl,
            rootPath: launcherDirectory
        ) {
            for candidate in candidateInstanceDirectories(
                for: .hmcl,
                rootPath: configuredRoot
            ) {
                append(candidate)
            }
        }

        return candidates
    }

    static func parseCandidates(
        _ candidateDirectories: [URL],
        parser: LauncherInstanceParser,
        launcherType: ImportLauncherType
    ) -> [ScannedLauncherInstance] {
        var results = [ScannedLauncherInstance]()

        for directory in candidateDirectories where parser.isValidInstance(at: directory) {
            do {
                let basePath = inferredBasePath(
                    for: launcherType,
                    instancePath: directory
                )
                guard let info = try parser.parseInstance(at: directory, basePath: basePath) else {
                    continue
                }
                guard !info.gameVersion.isEmpty else {
                    continue
                }
                guard AppConstants.modLoaders.contains(info.modLoader.lowercased()) else {
                    continue
                }
                results.append(
                    ScannedLauncherInstance(
                        instancePath: directory,
                        info: info,
                        stableID: nil
                    )
                )
            } catch {
                Logger.shared.warning("扫描实例失败: \(directory.path), \(error.localizedDescription)")
            }
        }

        return results
    }

    private static func candidateInstanceDirectories(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> [URL] {
        var candidates = [URL]()

        if LauncherInstanceParserFactory.createParser(for: launcherType).isValidInstance(at: rootPath) {
            candidates.append(rootPath)
        }

        for container in candidateContainers(for: launcherType, rootPath: rootPath) {
            candidates.append(contentsOf: immediateDirectories(at: container))
        }

        return candidates
    }

    private static func candidateContainers(
        for launcherType: ImportLauncherType,
        rootPath: URL
    ) -> [URL] {
        let lastPath = rootPath.lastPathComponent.lowercased()

        switch launcherType {
        case .all:
            return []

        case .officialLauncher:
            return []

        case .multiMC, .prismLauncher, .atLauncher, .xmcl:
            if lastPath == "instances" {
                return [rootPath]
            }
            return [rootPath.appendingPathComponent("instances")]

        case .gdLauncher:
            if lastPath == "instances" {
                return [rootPath]
            }
            return [
                rootPath.appendingPathComponent("instances"),
                rootPath.appendingPathComponent("data/instances"),
            ]

        case .modrinthApp:
            if lastPath == "profiles" {
                return [rootPath]
            }
            return [rootPath.appendingPathComponent("profiles")]

        case .curseForgeApp:
            if lastPath == "instances" {
                return [rootPath]
            }
            return [rootPath.appendingPathComponent("Instances")]

        case .hmcl, .sjmcLauncher:
            if lastPath == "versions" {
                return [rootPath]
            }
            return [
                rootPath.appendingPathComponent("versions"),
                rootPath.appendingPathComponent(".minecraft/versions"),
                rootPath.appendingPathComponent("minecraft/versions"),
            ]
        }
    }

    private static func relatedSearchRoots(for rootPath: URL) -> [URL] {
        var roots = [rootPath]
        var current = rootPath

        for _ in 0..<3 {
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else {
                break
            }
            roots.append(parent)
            current = parent
        }

        return roots
    }

    private static func inferredBasePath(
        for launcherType: ImportLauncherType,
        instancePath: URL
    ) -> URL {
        switch launcherType {
        case .officialLauncher:
            return instancePath.deletingLastPathComponent()
        case .multiMC, .prismLauncher, .atLauncher, .xmcl:
            return instancePath.deletingLastPathComponent().deletingLastPathComponent()
        case .gdLauncher:
            return instancePath
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        case .modrinthApp:
            return instancePath.deletingLastPathComponent().deletingLastPathComponent()
        case .curseForgeApp:
            return instancePath.deletingLastPathComponent()
        case .hmcl, .sjmcLauncher:
            return instancePath.deletingLastPathComponent().deletingLastPathComponent()
        case .all:
            return instancePath.deletingLastPathComponent()
        }
    }

    static func discoveredInstanceDirectories(
        in rootPath: URL
    ) -> [ImportLauncherType: [URL]] {
        var discovered = [ImportLauncherType: Set<String>]()

        func record(_ launcherType: ImportLauncherType, url: URL) {
            var values = discovered[launcherType] ?? []
            values.insert(url.standardizedFileURL.path)
            discovered[launcherType] = values
        }

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootPath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return [:]
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
            let isDirectory = values?.isDirectory == true

            if isDirectory {
                switch name {
                case "instances":
                    let children = immediateDirectories(at: standardizedURL)
                    children.forEach {
                        record(.multiMC, url: $0)
                        record(.prismLauncher, url: $0)
                        record(.atLauncher, url: $0)
                        record(.xmcl, url: $0)
                        record(.gdLauncher, url: $0)
                    }
                    enumerator.skipDescendants()
                case "profiles":
                    let parent = standardizedURL.deletingLastPathComponent()
                    let appDB = parent.appendingPathComponent("app.db")
                    if FileManager.default.fileExists(atPath: appDB.path) {
                        immediateDirectories(at: standardizedURL).forEach {
                            record(.modrinthApp, url: $0)
                        }
                        enumerator.skipDescendants()
                    }
                case "versions":
                    let children = immediateDirectories(at: standardizedURL)
                    children.forEach {
                        record(.hmcl, url: $0)
                        record(.sjmcLauncher, url: $0)
                    }
                case "Instances":
                    immediateDirectories(at: standardizedURL).forEach {
                        record(.curseForgeApp, url: $0)
                    }
                    enumerator.skipDescendants()
                default:
                    break
                }
                continue
            }

            switch name {
            case "app.db":
                let profilesDirectory = standardizedURL.deletingLastPathComponent().appendingPathComponent("profiles")
                immediateDirectories(at: profilesDirectory).forEach {
                    record(.modrinthApp, url: $0)
                }
            case "instance.cfg", "mmc-pack.json":
                let parent = standardizedURL.deletingLastPathComponent()
                record(.multiMC, url: parent)
                record(.prismLauncher, url: parent)
            case "instance.json":
                let parent = standardizedURL.deletingLastPathComponent()
                record(.atLauncher, url: parent)
                record(.xmcl, url: parent)
                record(.gdLauncher, url: parent)
            case "config.json":
                record(.gdLauncher, url: standardizedURL.deletingLastPathComponent())
            case "minecraftinstance.json":
                record(.curseForgeApp, url: standardizedURL.deletingLastPathComponent())
            case "sjmclcfg.json":
                record(.sjmcLauncher, url: standardizedURL.deletingLastPathComponent())
            case "hmclversion.cfg":
                record(.hmcl, url: standardizedURL.deletingLastPathComponent())
            case "profile.json":
                record(.modrinthApp, url: standardizedURL.deletingLastPathComponent())
            default:
                break
            }
        }

        return discovered.mapValues { paths in
            paths.map(URL.init(fileURLWithPath:)).sorted { $0.path < $1.path }
        }
    }

    static func shouldSkip(url: URL, name: String) -> Bool {
        if skippedDirectoryNames.contains(name) {
            return true
        }

        let normalizedPath = url.path
        return skippedDirectoryNames.contains { marker in
            normalizedPath.contains("/\(marker)/")
        }
    }

    private static func immediateDirectories(at url: URL) -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        guard let childURLs = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return childURLs.filter { candidate in
            let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory == true
        }
    }

    private static func installedLauncherDataDirectories(
        matching appNames: [String],
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        let applicationsDirectories = [
            URL(fileURLWithPath: "/Applications"),
            homeDirectory.appendingPathComponent("Applications"),
        ]
        var results = [URL]()

        for applicationsDirectory in applicationsDirectories {
            guard let children = try? fileManager.contentsOfDirectory(
                at: applicationsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for child in children where appNames.contains(child.lastPathComponent) {
                let dataDirectory = child
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("MacOS")
                    .appendingPathComponent("Data")
                if fileManager.fileExists(atPath: dataDirectory.path) {
                    results.append(dataDirectory)
                }
            }
        }

        return results
    }
}
