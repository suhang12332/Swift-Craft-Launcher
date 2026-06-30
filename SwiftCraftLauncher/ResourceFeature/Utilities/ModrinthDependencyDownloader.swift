//
//  ModrinthDependencyDownloader.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Downloads Modrinth project dependencies and manages recursive and manual dependency resolution.
enum ModrinthDependencyDownloader {
    /// Recursively downloads all dependencies for a project using the official dependencies API.
    static func downloadAllDependenciesRecursive(
        for projectId: String,
        gameInfo: GameVersionInfo,
        query: String,
        gameRepository: GameRepository,
        actuallyDownloaded: inout [ModrinthProjectDetail],
        visited: inout Set<String>
    ) async {
        // Validate that the query is a supported resource type.
        let queryLowercased = query.lowercased()

        // Return early for modpacks or unrecognized types.
        if queryLowercased == ResourceType.modpack.rawValue || !AppConstants.validResourceTypes.contains(queryLowercased) {
            Logger.shared.error("不支持下载此类型的资源: \(query)")
            return
        }

        do {
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: gameInfo.gameName
            )
            guard let resourceDirUnwrapped = resourceDir else { return }

            // Check installed state using ModScanner.
            let dependencies =
                await ModrinthService.fetchProjectDependencies(
                    type: query,
                    cachePath: resourceDirUnwrapped,
                    id: projectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: [gameInfo.modLoader]
                )

            guard
                await ModrinthService.fetchProjectDetails(id: projectId) != nil
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(projectId))")
                return
            }

            let semaphore = AsyncSemaphore(
                value: AppServices.generalSettingsManager.concurrentDownloads
            )

            let allDownloaded: [ModrinthProjectDetail] = await withTaskGroup(
                of: ModrinthProjectDetail?.self
            ) { group in
                for depVersion in dependencies.projects {
                    group.addTask {
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        guard
                            let projectDetail =
                                await ModrinthService.fetchProjectDetails(
                                    id: depVersion.projectId
                                )
                        else {

                            Logger.shared.error(
                                "无法获取依赖项目详情 (ID: \(depVersion.projectId))"
                            )
                            return nil
                        }

                        let result = ModrinthService.filterPrimaryFiles(
                            from: depVersion.files
                        )
                        if let file = result {
                            let fileURL =
                                try? await DownloadManager.downloadResource(
                                    for: gameInfo,
                                    urlString: file.url,
                                    resourceType: query,
                                    expectedSha1: file.hashes.sha1
                                )
                            var detailWithFile = projectDetail
                            detailWithFile.fileName = file.filename
                            detailWithFile.type = query
                            if let fileURL = fileURL,
                                let hash = AppServices.modScanner.sha1Hash(of: fileURL) {
                                AppServices.modScanner.saveToCache(
                                    hash: hash,
                                    detail: detailWithFile
                                )
                                if query.lowercased() == ResourceType.mod.rawValue {
                                    AppServices.modScanner.addModHash(
                                        hash,
                                        to: gameInfo.gameName
                                    )
                                }
                            }
                            return detailWithFile
                        }
                        return nil
                    }
                }
                // Process the main mod.
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    do {
                        guard
                            var mainProjectDetail =
                                await ModrinthService.fetchProjectDetails(
                                    id: projectId
                                )
                        else {
                            Logger.shared.error("无法获取主项目详情 (ID: \(projectId))")
                            return nil
                        }
                        let filteredVersions =
                            try await ModrinthService.fetchProjectVersionsFilter(
                                id: projectId,
                                selectedVersions: [gameInfo.gameVersion],
                                selectedLoaders: [gameInfo.modLoader],
                                type: query
                            )
                        let result = ModrinthService.filterPrimaryFiles(
                            from: filteredVersions.first?.files
                        )
                        if let file = result {
                            let fileURL =
                                try? await DownloadManager.downloadResource(
                                    for: gameInfo,
                                    urlString: file.url,
                                    resourceType: query,
                                    expectedSha1: file.hashes.sha1
                                )
                            mainProjectDetail.fileName = file.filename
                            mainProjectDetail.type = query
                            if let fileURL = fileURL,
                                let hash = AppServices.modScanner.sha1Hash(of: fileURL) {
                                AppServices.modScanner.saveToCache(
                                    hash: hash,
                                    detail: mainProjectDetail
                                )
                                if query.lowercased() == ResourceType.mod.rawValue {
                                    AppServices.modScanner.addModHash(
                                        hash,
                                        to: gameInfo.gameName
                                    )
                                }
                            }
                            return mainProjectDetail
                        }
                        return nil
                    } catch {
                        let globalError = GlobalError.from(error)
                        Logger.shared.error(
                            "下载主资源 \(projectId) 失败: \(globalError.chineseMessage)"
                        )
                        AppServices.errorHandler.handle(globalError)
                        return nil
                    }
                }
                // Collect all download results.
                var localResults: [ModrinthProjectDetail] = []
                for await result in group {
                    if let project = result {
                        localResults.append(project)
                    }
                }
                return localResults
            }

            actuallyDownloaded.append(contentsOf: allDownloaded)
        }
    }

    /// Fetches missing dependencies with their available versions.
    static func getMissingDependenciesWithVersions(
        for projectId: String,
        gameInfo: GameVersionInfo
    ) async -> [(
        detail: ModrinthProjectDetail, versions: [ModrinthProjectDetailVersion]
    )] {
        let query = ResourceType.mod.rawValue
        let resourceDir = AppPaths.modsDirectory(
            gameName: gameInfo.gameName
        )

        let dependencies = await ModrinthService.fetchProjectDependencies(
            type: query,
            cachePath: resourceDir,
            id: projectId,
            selectedVersions: [gameInfo.gameVersion],
            selectedLoaders: [gameInfo.modLoader]
        )

        // Concurrently fetch project details and version info for all dependencies.
        return await withTaskGroup(
            of: (ModrinthProjectDetail, [ModrinthProjectDetailVersion])?.self
        ) { group in
            for depVersion in dependencies.projects {
                group.addTask {
                    // Fetch the project detail.
                    guard
                        let projectDetail =
                            await ModrinthService.fetchProjectDetails(
                                id: depVersion.projectId
                            )
                    else {
                        return nil
                    }

                    let filteredVersions: [ModrinthProjectDetailVersion]
                    do {
                        filteredVersions = try await ModrinthService.fetchProjectVersionsFilter(
                            id: depVersion.projectId,
                            selectedVersions: [gameInfo.gameVersion],
                            selectedLoaders: [gameInfo.modLoader],
                            type: ResourceType.mod.rawValue
                        )
                    } catch {
                        Logger.shared.error("获取依赖 \(projectDetail.title) 的版本失败: \(error.localizedDescription)")
                        filteredVersions = []
                    }

                    return (projectDetail, filteredVersions)
                }
            }

            var results:
                [(
                    detail: ModrinthProjectDetail,
                    versions: [ModrinthProjectDetailVersion]
                )] = []
            for await result in group {
                if let (detail, versions) = result {
                    results.append((detail, versions))
                }
            }

            return results
        }
    }

    /// Fetches missing dependencies without version details.
    static func getMissingDependencies(
        for projectId: String,
        gameInfo: GameVersionInfo
    ) async -> [ModrinthProjectDetail] {
        let query = ResourceType.mod.rawValue
        let resourceDir = AppPaths.modsDirectory(
            gameName: gameInfo.gameName
        )

        let dependencies = await ModrinthService.fetchProjectDependencies(
            type: query,
            cachePath: resourceDir,
            id: projectId,
            selectedVersions: [gameInfo.gameVersion],
            selectedLoaders: [gameInfo.modLoader]
        )

        // Convert ModrinthProjectDetailVersion values to ModrinthProjectDetail.
        var projectDetails: [ModrinthProjectDetail] = []
        for depVersion in dependencies.projects {
            if let projectDetail = await ModrinthService.fetchProjectDetails(
                id: depVersion.projectId
            ) {
                projectDetails.append(projectDetail)
            }
        }

        return projectDetails
    }

    struct ManualDownloadInput {
        let dependencies: [ModrinthProjectDetail]
        let selectedVersions: [String: String]
        let dependencyVersions: [String: [ModrinthProjectDetailVersion]]
        let mainProjectId: String
        let mainProjectVersionId: String?
        let gameInfo: GameVersionInfo
        let resourceType: String
        let gameRepository: GameRepository
    }

    // Downloads dependencies and the main mod manually, without recursion.
    static func downloadManualDependenciesAndMain(
        input: ManualDownloadInput,
        onDependencyDownloadStart: @escaping (String) -> Void,
        onDependencyDownloadFinish: @escaping (String, Bool) -> Void
    ) async -> Bool {
        var resourcesToAdd: [ModrinthProjectDetail] = []
        var allSuccess = true
        let semaphore = AsyncSemaphore(
            value: AppServices.generalSettingsManager.concurrentDownloads
        )

        await withTaskGroup(of: (String, Bool, ModrinthProjectDetail?).self) { group in
            for dep in input.dependencies {
                guard let versionId = input.selectedVersions[dep.id],
                    let versions = input.dependencyVersions[dep.id],
                    let version = versions.first(where: { $0.id == versionId }),
                    let primaryFile = ModrinthService.filterPrimaryFiles(
                        from: version.files
                    )
                else {
                    allSuccess = false
                    Task { @MainActor in
                        onDependencyDownloadFinish(dep.id, false)
                    }
                    continue
                }

                group.addTask {
                    var depCopy = dep
                    let depId = depCopy.id
                    await MainActor.run { onDependencyDownloadStart(depId) }
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    var success = false
                    do {
                        let fileURL =
                            try await DownloadManager.downloadResource(
                                for: input.gameInfo,
                                urlString: primaryFile.url,
                                resourceType: input.resourceType,
                                expectedSha1: primaryFile.hashes.sha1
                            )
                        depCopy.fileName = primaryFile.filename
                        depCopy.type = input.resourceType
                        success = true
                        if let hash = AppServices.modScanner.sha1Hash(of: fileURL) {
                            AppServices.modScanner.saveToCache(
                                hash: hash,
                                detail: depCopy
                            )
                            if input.resourceType.lowercased() == ResourceType.mod.rawValue {
                                AppServices.modScanner.addModHash(
                                    hash,
                                    to: input.gameInfo.gameName
                                )
                            }
                        }
                    } catch {
                        let globalError = GlobalError.from(error)
                        Logger.shared.error(
                            "下载依赖 \(depId) 失败: \(globalError.chineseMessage)"
                        )
                        AppServices.errorHandler.handle(globalError)
                        success = false
                    }
                    let depCopyFinal = depCopy
                    return (depId, success, success ? depCopyFinal : nil)
                }
            }

            for await (depId, success, depCopy) in group {
                await MainActor.run {
                    onDependencyDownloadFinish(depId, success)
                }
                if success, let depCopy = depCopy {
                    resourcesToAdd.append(depCopy)
                } else {
                    allSuccess = false
                }
            }
        }

        guard allSuccess else {
            return false
        }

        do {
            guard
                var mainProjectDetail =
                    await ModrinthService.fetchProjectDetails(id: input.mainProjectId)
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(input.mainProjectId))")
                return false
            }

            let selectedLoaders = [input.gameInfo.modLoader]
            let filteredVersions =
                try await ModrinthService.fetchProjectVersionsFilter(
                    id: input.mainProjectId,
                    selectedVersions: [input.gameInfo.gameVersion],
                    selectedLoaders: selectedLoaders,
                    type: input.resourceType
                )

            // Use the specified version or fall back to the latest.
            let targetVersion: ModrinthProjectDetailVersion
            if let mainProjectVersionId = input.mainProjectVersionId,
                let specifiedVersion = filteredVersions.first(where: {
                    $0.id == mainProjectVersionId
                }) {
                targetVersion = specifiedVersion
            } else if let latestVersion = filteredVersions.first {
                targetVersion = latestVersion
            } else {
                Logger.shared.error("无法找到合适的版本")
                return false
            }

            guard
                let primaryFile = ModrinthService.filterPrimaryFiles(
                    from: targetVersion.files
                )
            else {
                Logger.shared.error("无法找到主文件")
                return false
            }

            let fileURL = try await DownloadManager.downloadResource(
                for: input.gameInfo,
                urlString: primaryFile.url,
                resourceType: input.resourceType,
                expectedSha1: primaryFile.hashes.sha1
            )
            mainProjectDetail.fileName = primaryFile.filename
            mainProjectDetail.type = input.resourceType
            if let hash = AppServices.modScanner.sha1Hash(of: fileURL) {
                AppServices.modScanner.saveToCache(
                    hash: hash,
                    detail: mainProjectDetail
                )
                if input.resourceType.lowercased() == ResourceType.mod.rawValue {
                    AppServices.modScanner.addModHash(
                        hash,
                        to: input.gameInfo.gameName
                    )
                }
            }
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "下载主资源 \(input.mainProjectId) 失败: \(globalError.chineseMessage)"
            )
            AppServices.errorHandler.handle(globalError)
            return false
        }
    }

    /// Downloads only the main resource without its dependencies.
    /// - Returns: A tuple of (success, fileName, hash). fileName and hash are non-nil on success.
    static func downloadMainResourceOnly(
        mainProjectId: String,
        gameInfo: GameVersionInfo,
        query: String,
        gameRepository: GameRepository,
        filterLoader: Bool = true
    ) async -> (Bool, fileName: String?, hash: String?) {
        do {
            guard
                var mainProjectDetail =
                    await ModrinthService.fetchProjectDetails(id: mainProjectId)
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(mainProjectId))")
                return (false, nil, nil)
            }
            let selectedLoaders = filterLoader ? [gameInfo.modLoader] : []
            let filteredVersions =
                try await ModrinthService.fetchProjectVersionsFilter(
                    id: mainProjectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: selectedLoaders,
                    type: query
                )
            guard let latestVersion = filteredVersions.first,
                let primaryFile = ModrinthService.filterPrimaryFiles(
                    from: latestVersion.files
                )
            else {
                return (false, nil, nil)
            }

            let fileURL = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: query,
                expectedSha1: primaryFile.hashes.sha1
            )
            mainProjectDetail.fileName = primaryFile.filename
            mainProjectDetail.type = query

            var hash: String?
            if let h = AppServices.modScanner.sha1Hash(of: fileURL) {
                hash = h
                AppServices.modScanner.saveToCache(
                    hash: h,
                    detail: mainProjectDetail
                )
                if query.lowercased() == ResourceType.mod.rawValue {
                    AppServices.modScanner.addModHash(
                        h,
                        to: gameInfo.gameName
                    )
                }
            }
            return (true, primaryFile.filename, hash)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "仅下载主资源 \(mainProjectId) 失败: \(globalError.chineseMessage)"
            )
            AppServices.errorHandler.handle(globalError)
            return (false, nil, nil)
        }
    }
}
