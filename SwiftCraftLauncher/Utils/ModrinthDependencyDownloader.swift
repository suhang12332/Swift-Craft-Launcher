import Foundation
import os

enum ModrinthDependencyDownloader {
    /// 递归下载所有依赖（基于官方依赖API）
    static func downloadAllDependenciesRecursive(
        for projectId: String,
        gameInfo: GameVersionInfo,
        query: String,
        gameRepository: GameRepository,
        actuallyDownloaded: inout [ModrinthProjectDetail],
        visited: inout Set<String>
    ) async {
        // 检查 query 是否是有效的资源类型
        let validResourceTypes = ["mod", "datapack", "shader", "resourcepack"]
        let queryLowercased = query.lowercased()

        // 如果 query 是 modpack 或无效的资源类型，直接返回
        if queryLowercased == "modpack" || !validResourceTypes.contains(queryLowercased) {
            Logger.shared.error("不支持下载此类型的资源: \(query)")
            return
        }

        do {
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: gameInfo.gameName
            )
            guard let resourceDirUnwrapped = resourceDir else { return }
            // 1. 获取所有依赖

            // 新逻辑：用ModScanner判断对应资源目录下是否已安装
            let dependencies =
                await ModrinthService.fetchProjectDependencies(
                    type: query,
                    cachePath: resourceDirUnwrapped,
                    id: projectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: [gameInfo.modLoader]
                )

            // 2. 获取主mod详情
            guard
                await ModrinthService.fetchProjectDetails(id: projectId) != nil
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(projectId))")
                return
            }

            // 3. 读取最大并发数，最少为1
            let semaphore = AsyncSemaphore(
                value: GeneralSettingsManager.shared.concurrentDownloads
            )  // 控制最大并发数

            // 4. 并发下载所有依赖和主mod，收集结果
            let allDownloaded: [ModrinthProjectDetail] = await withTaskGroup(
                of: ModrinthProjectDetail?.self
            ) { group in
                // 依赖
                for depVersion in dependencies.projects {
                    group.addTask {
                        await semaphore.wait()  // 限制并发
                        defer { Task { await semaphore.signal() } }

                        // 获取项目详情
                        guard
                            let projectDetail =
                                await ModrinthService.fetchProjectDetails(
                                    id: depVersion.projectId
                                )
                        else {

                            Logger.shared.error(
                                "无法获取依赖项目详情 (ID: \(depVersion.projectId))"
                            )
                            Logger.shared.error(
                                "无法获取sss项目详情 (ID: \(depVersion.projectId))"
                            )
                            return nil
                        }

                        // 使用版本中的文件信息
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
                            // 新增缓存
                            if let fileURL = fileURL,
                                let hash = ModScanner.sha1Hash(of: fileURL) {
                                ModScanner.shared.saveToCache(
                                    hash: hash,
                                    detail: detailWithFile
                                )
                            }
                            // 如果是 mod，添加到安装缓存
                            if query.lowercased() == "mod" {
                                ModScanner.shared.addModProjectId(
                                    detailWithFile.id,
                                    to: gameInfo.gameName
                                )
                            }
                            return detailWithFile
                        }
                        return nil
                    }
                }
                // 主mod
                group.addTask {
                    await semaphore.wait()  // 限制并发
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
                            // 新增缓存
                            if let fileURL = fileURL,
                                let hash = ModScanner.sha1Hash(of: fileURL) {
                                ModScanner.shared.saveToCache(
                                    hash: hash,
                                    detail: mainProjectDetail
                                )
                            }
                            // 如果是 mod，添加到安装缓存
                            if query.lowercased() == "mod" {
                                ModScanner.shared.addModProjectId(
                                    mainProjectDetail.id,
                                    to: gameInfo.gameName
                                )
                            }
                            return mainProjectDetail
                        }
                        return nil
                    } catch {
                        let globalError = GlobalError.from(error)
                        Logger.shared.error(
                            "下载主资源 \(projectId) 失败: \(globalError.chineseMessage)"
                        )
                        GlobalErrorHandler.shared.handle(globalError)
                        return nil
                    }
                }
                // 收集所有下载结果
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

    /// 获取缺失的依赖项（包含版本信息）
    static func getMissingDependenciesWithVersions(
        for projectId: String,
        gameInfo: GameVersionInfo
    ) async -> [(
        detail: ModrinthProjectDetail, versions: [ModrinthProjectDetailVersion]
    )] {
        let query = "mod"
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

        // 并发获取所有依赖项目的详情和版本信息
        return await withTaskGroup(
            of: (ModrinthProjectDetail, [ModrinthProjectDetailVersion])?.self
        ) { group in
            for depVersion in dependencies.projects {
                group.addTask {
                    // 获取项目详情
                    guard
                        let projectDetail =
                            await ModrinthService.fetchProjectDetails(
                                id: depVersion.projectId
                            )
                    else {
                        return nil
                    }

                    // 获取项目版本并过滤
                    let allVersions =
                        await ModrinthService.fetchProjectVersions(
                            id: depVersion.projectId
                        )
                    let filteredVersions = allVersions.filter {
                        $0.loaders.contains(gameInfo.modLoader)
                            && $0.gameVersions.contains(gameInfo.gameVersion)
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

    /// 获取缺失的依赖项
    static func getMissingDependencies(
        for projectId: String,
        gameInfo: GameVersionInfo
    ) async -> [ModrinthProjectDetail] {
        let query = "mod"
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

        // 将 ModrinthProjectDetailVersion 转换为 ModrinthProjectDetail
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

    // 手动下载依赖和主mod（不递归，仅当前依赖和主mod）
    // swiftlint:disable:next function_parameter_count
    static func downloadManualDependenciesAndMain(
        dependencies: [ModrinthProjectDetail],
        selectedVersions: [String: String],
        dependencyVersions: [String: [ModrinthProjectDetailVersion]],
        mainProjectId: String,
        mainProjectVersionId: String?,
        gameInfo: GameVersionInfo,
        query: String,
        gameRepository: GameRepository,
        onDependencyDownloadStart: @escaping (String) -> Void,
        onDependencyDownloadFinish: @escaping (String, Bool) -> Void
    ) async -> Bool {
        var resourcesToAdd: [ModrinthProjectDetail] = []
        var allSuccess = true
        let semaphore = AsyncSemaphore(
            value: GeneralSettingsManager.shared.concurrentDownloads
        )

        await withTaskGroup(of: (String, Bool, ModrinthProjectDetail?).self) { group in
            for dep in dependencies {
                guard let versionId = selectedVersions[dep.id],
                    let versions = dependencyVersions[dep.id],
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
                                for: gameInfo,
                                urlString: primaryFile.url,
                                resourceType: query,
                                expectedSha1: primaryFile.hashes.sha1
                            )
                        depCopy.fileName = primaryFile.filename
                        depCopy.type = query
                        success = true
                        // 新增缓存
                        if let hash = ModScanner.sha1Hash(of: fileURL) {
                            ModScanner.shared.saveToCache(
                                hash: hash,
                                detail: depCopy
                            )
                        }
                        // 如果是 mod，添加到安装缓存
                        if query.lowercased() == "mod" {
                            ModScanner.shared.addModProjectId(
                                depCopy.id,
                                to: gameInfo.gameName
                            )
                        }
                    } catch {
                        let globalError = GlobalError.from(error)
                        Logger.shared.error(
                            "下载依赖 \(depId) 失败: \(globalError.chineseMessage)"
                        )
                        GlobalErrorHandler.shared.handle(globalError)
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
            // 如果依赖下载失败，就不再继续下载主mod，直接返回失败
            return false
        }

        // 所有依赖都成功了，现在下载主 mod
        do {
            guard
                var mainProjectDetail =
                    await ModrinthService.fetchProjectDetails(id: mainProjectId)
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(mainProjectId))")
                return false
            }

            let selectedLoaders = [gameInfo.modLoader]
            let filteredVersions =
                try await ModrinthService.fetchProjectVersionsFilter(
                    id: mainProjectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: selectedLoaders,
                    type: query
                )

            // 如果指定了版本ID，使用指定版本；否则使用最新版本
            let targetVersion: ModrinthProjectDetailVersion
            if let mainProjectVersionId = mainProjectVersionId,
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
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: query,
                expectedSha1: primaryFile.hashes.sha1
            )
            mainProjectDetail.fileName = primaryFile.filename
            mainProjectDetail.type = query
            // 新增缓存
            if let hash = ModScanner.sha1Hash(of: fileURL) {
                ModScanner.shared.saveToCache(
                    hash: hash,
                    detail: mainProjectDetail
                )
            }
            // 如果是 mod，添加到安装缓存
            if query.lowercased() == "mod" {
                ModScanner.shared.addModProjectId(
                    mainProjectDetail.id,
                    to: gameInfo.gameName
                )
            }
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "下载主资源 \(mainProjectId) 失败: \(globalError.chineseMessage)"
            )
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    static func downloadMainResourceOnly(
        mainProjectId: String,
        gameInfo: GameVersionInfo,
        query: String,
        gameRepository: GameRepository,
        filterLoader: Bool = true
    ) async -> Bool {
        do {
            guard
                var mainProjectDetail =
                    await ModrinthService.fetchProjectDetails(id: mainProjectId)
            else {
                Logger.shared.error("无法获取主项目详情 (ID: \(mainProjectId))")
                return false
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
                return false
            }

            let fileURL = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: query,
                expectedSha1: primaryFile.hashes.sha1
            )
            mainProjectDetail.fileName = primaryFile.filename
            mainProjectDetail.type = query

            // 新增缓存
            if let hash = ModScanner.sha1Hash(of: fileURL) {
                ModScanner.shared.saveToCache(
                    hash: hash,
                    detail: mainProjectDetail
                )
            }
            // 如果是 mod，添加到安装缓存
            if query.lowercased() == "mod" {
                ModScanner.shared.addModProjectId(
                    mainProjectDetail.id,
                    to: gameInfo.gameName
                )
            }
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "仅下载主资源 \(mainProjectId) 失败: \(globalError.chineseMessage)"
            )
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }
}
