//
//  ModPackDependencyInstaller+Dependencies.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackDependencyInstaller {
    /// Installs all required dependencies for the modpack.
    static func installModPackDependencies(
        dependencies: [ModrinthIndexProjectDependency],
        gameInfo: GameVersionInfo,
        resourceDir: URL,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?,
    ) async -> Bool {
        let requiredDependencies = dependencies.filter { $0.dependencyType == "required" }

        onProgressUpdate?(
            "modpack.progress.dependencies_installation_started".localized(),
            0,
            requiredDependencies.count,
            .dependencies,
        )

        let semaphore = AsyncSemaphore(value: downloadSemaphoreValue)
        let completedCount = ModPackCounter()

        let results = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, dep) in requiredDependencies.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    if await shouldSkipDependency(dep: dep, gameInfo: gameInfo, resourceDir: resourceDir) {
                        let currentCount = completedCount.increment()
                        onProgressUpdate?(
                            "modpack.progress.dependency_skipped".localized(),
                            currentCount,
                            requiredDependencies.count,
                            .dependencies,
                        )
                        return (index, true)
                    }

                    let success = await installDependency(dep: dep, gameInfo: gameInfo, resourceDir: resourceDir)

                    if success {
                        let currentCount = completedCount.increment()
                        let dependencyName = dep.projectId ?? "Unknown dependency"
                        onProgressUpdate?(dependencyName, currentCount, requiredDependencies.count, .dependencies)
                    }

                    return (index, success)
                }
            }

            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }
        }

        let failedCount = results.count - results.count { $0.1 }

        if failedCount > 0 {
            AppLog.modPack.error("\(failedCount) dependencies failed to install")
            return false
        }

        onProgressUpdate?(
            "modpack.progress.dependencies_installation_completed".localized(),
            requiredDependencies.count,
            requiredDependencies.count,
            .dependencies,
        )

        return true
    }

    private static func shouldSkipDependency(
        dep: ModrinthIndexProjectDependency,
        gameInfo: GameVersionInfo,
        resourceDir: URL,
    ) async -> Bool {
        if dep.projectId == "P7dR8mSH", gameInfo.modLoader.lowercased() == GameLoader.quilt.rawValue {
            return true
        }

        if let projectId = dep.projectId {
            if let versionId = dep.versionId {
                if let version = try? await ModrinthService.fetchProjectVersionThrowing(id: versionId),
                   let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) {
                    if DIContainer.shared.core.modScanner.isModInstalledSync(hash: primaryFile.hashes.sha1, in: resourceDir) {
                        return true
                    }
                }
            } else {
                let versions = try? await ModrinthService.fetchProjectVersionsFilter(
                    id: projectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: [gameInfo.modLoader],
                    type: ResourceType.mod.rawValue,
                )
                if let version = versions?.first,
                   let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) {
                    if DIContainer.shared.core.modScanner.isModInstalledSync(hash: primaryFile.hashes.sha1, in: resourceDir) {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func installDependency(
        dep: ModrinthIndexProjectDependency,
        gameInfo: GameVersionInfo,
        resourceDir: URL,
    ) async -> Bool {
        guard let projectId = dep.projectId else {
            AppLog.modPack.error("Dependency missing project ID")
            return false
        }

        if let versionId = dep.versionId {
            return await addProjectFromVersion(
                projectId: projectId,
                versionId: versionId,
                gameInfo: gameInfo,
                resourceDir: resourceDir,
            )
        }
        return await addProjectFromLatestVersion(
            projectId: projectId,
            gameInfo: gameInfo,
            resourceDir: resourceDir,
        )
    }

    private static func addProjectFromVersion(
        projectId: String,
        versionId: String,
        gameInfo: GameVersionInfo,
        resourceDir: URL,
    ) async -> Bool {
        do {
            let version = try await ModrinthService.fetchProjectVersionThrowing(id: versionId)

            guard version.gameVersions.contains(gameInfo.gameVersion),
                  version.loaders.contains(gameInfo.modLoader) else {
                AppLog.modPack.error("Version incompatible: \(versionId)")
                return false
            }

            let projectDetail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId)

            return await downloadAndInstallVersion(
                version: version,
                projectDetail: projectDetail,
                gameInfo: gameInfo,
                resourceDir: resourceDir,
            )
        } catch {
            AppLog.modPack.error("Failed to get version details")
            return false
        }
    }

    private static func addProjectFromLatestVersion(
        projectId: String,
        gameInfo: GameVersionInfo,
        resourceDir: URL,
    ) async -> Bool {
        do {
            let projectDetail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId)
            let versions = try await ModrinthService.fetchProjectVersionsThrowing(id: projectId)
            let sortedVersions = versions.sorted { $0.datePublished > $1.datePublished }

            guard let latestVersion = sortedVersions.first(where: { version in
                version.gameVersions.contains(gameInfo.gameVersion) &&
                    version.loaders.contains(gameInfo.modLoader)
            }) else {
                AppLog.modPack.error("No compatible version found: \(projectId)")
                return false
            }

            return await downloadAndInstallVersion(
                version: latestVersion,
                projectDetail: projectDetail,
                gameInfo: gameInfo,
                resourceDir: resourceDir,
            )
        } catch {
            AppLog.modPack.error("Failed to get project details")
            return false
        }
    }

    private static func downloadAndInstallVersion(
        version: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameInfo: GameVersionInfo,
        resourceDir _: URL,
    ) async -> Bool {
        do {
            guard let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) else {
                AppLog.modPack.error("No primary file found: \(version.id)")
                return false
            }

            let downloadedFile = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: ResourceType.mod.rawValue,
                expectedSha1: primaryFile.hashes.sha1,
            )

            if let hash = DIContainer.shared.core.modScanner.sha1Hash(of: downloadedFile) {
                var detailWithFile = projectDetail
                detailWithFile.fileName = primaryFile.filename
                detailWithFile.type = ResourceType.mod.rawValue
                DIContainer.shared.core.modScanner.saveToCache(hash: hash, detail: detailWithFile)
            }

            return true
        } catch {
            AppLog.modPack.error("Failed to download dependency")
            return false
        }
    }
}
