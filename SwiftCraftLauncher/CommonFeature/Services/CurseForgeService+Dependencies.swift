import Foundation

extension CurseForgeService {
    // MARK: - Dependency Methods

    /// 获取项目依赖（映射为 Modrinth 格式，静默版本）
    /// - Parameters:
    ///   - type: 项目类型
    ///   - cachePath: 缓存路径
    ///   - id: 项目 ID
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    /// - Returns: 项目依赖，失败时返回空依赖
    static func fetchProjectDependenciesAsModrinth(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String]
    ) async -> ModrinthProjectDependency {
        do {
            return try await fetchProjectDependenciesThrowingAsModrinth(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 CurseForge 项目依赖失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return ModrinthProjectDependency(projects: [])
        }
    }

    /// 获取项目依赖（映射为 Modrinth 格式，抛出异常版本）
    /// - Parameters:
    ///   - type: 项目类型
    ///   - cachePath: 缓存路径
    ///   - id: 项目 ID
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    /// - Returns: 项目依赖
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectDependenciesThrowingAsModrinth(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String]
    ) async throws -> ModrinthProjectDependency {
        // 1. 获取所有筛选后的版本
        let versions = try await fetchProjectVersionsFilterAsModrinth(
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            type: type
        )

        // 只取第一个版本
        guard let firstVersion = versions.first else {
            return ModrinthProjectDependency(projects: [])
        }

        // 2. 并发获取所有依赖项目的兼容版本（使用批处理限制并发数量）
        let requiredDeps = firstVersion.dependencies.filter { $0.dependencyType == "required" && $0.projectId != nil }
        let maxConcurrentTasks = 20 // 限制最大并发任务数
        var allDependencyVersions: [ModrinthProjectDetailVersion] = []

        // 分批处理依赖，每批最多 maxConcurrentTasks 个
        var currentIndex = 0
        while currentIndex < requiredDeps.count {
            let endIndex = min(currentIndex + maxConcurrentTasks, requiredDeps.count)
            let batch = Array(requiredDeps[currentIndex..<endIndex])
            currentIndex = endIndex

            let batchResults: [ModrinthProjectDetailVersion] = await withTaskGroup(of: ModrinthProjectDetailVersion?.self) { group in
                for dep in batch {
                    guard let projectId = dep.projectId else { continue }
                    group.addTask {
                        do {
                            let depVersion: ModrinthProjectDetailVersion

                            // 规范化 projectId：如果是纯数字，添加 "cf-" 前缀（CurseForge 依赖通常是纯数字）
                            let normalizedProjectId: String
                            if !projectId.hasPrefix("cf-") && Int(projectId) != nil {
                                // 纯数字，应该是 CurseForge 项目
                                normalizedProjectId = "cf-\(projectId)"
                            } else {
                                normalizedProjectId = projectId
                            }

                            if let versionId = dep.versionId {
                                // 如果有 versionId，需要检查是否是 CurseForge 版本
                                if versionId.hasPrefix("cf-") {
                                    // CurseForge 版本，需要从文件 ID 获取
                                    let fileId = Int(versionId.replacingOccurrences(of: "cf-", with: "")) ?? 0
                                    // 需要从 projectId 获取 modId
                                    let (modId, _) = try parseCurseForgeId(normalizedProjectId)
                                    let cfFile = try await fetchFileDetailThrowing(projectId: modId, fileId: fileId)
                                    guard let convertedVersion = CFToModrinthAdapter.convertFile(cfFile, projectId: normalizedProjectId) else {
                                        return nil
                                    }
                                    depVersion = convertedVersion
                                } else {
                                    // Modrinth 版本，使用 ModrinthService
                                    depVersion = try await ModrinthService.fetchProjectVersionThrowing(id: versionId)
                                }
                            } else {
                                // 如果没有 versionId，使用过滤逻辑获取兼容版本
                                // 检查是否是 CurseForge 项目
                                if normalizedProjectId.hasPrefix("cf-") {
                                    // CurseForge 项目
                                    let depVersions = try await fetchProjectVersionsFilterAsModrinth(
                                        id: normalizedProjectId,
                                        selectedVersions: selectedVersions,
                                        selectedLoaders: selectedLoaders,
                                        type: type
                                    )
                                    guard let firstDepVersion = depVersions.first else {
                                        return nil
                                    }
                                    depVersion = firstDepVersion
                                } else {
                                    // Modrinth 项目
                                    let depVersions = try await ModrinthService.fetchProjectVersionsFilter(
                                        id: normalizedProjectId,
                                        selectedVersions: selectedVersions,
                                        selectedLoaders: selectedLoaders,
                                        type: type
                                    )
                                    guard let firstDepVersion = depVersions.first else {
                                        return nil
                                    }
                                    depVersion = firstDepVersion
                                }
                            }

                            return depVersion
                        } catch {
                            let globalError = GlobalError.from(error)
                            Logger.shared.error("获取依赖项目版本失败 (ID: \(projectId)): \(globalError.chineseMessage)")
                            return nil
                        }
                    }
                }

                var results: [ModrinthProjectDetailVersion] = []
                for await result in group {
                    if let version = result {
                        results.append(version)
                    }
                }

                return results
            }

            allDependencyVersions.append(contentsOf: batchResults)
        }

        // 3. 使用统一的哈希检测逻辑，基于「所有兼容版本」判断依赖是否已安装
        var missingDependencyVersions: [ModrinthProjectDetailVersion] = []

        for version in allDependencyVersions {
            let isInstalled = await ModrinthService.isProjectInstalledByAnyCompatibleVersion(
                projectId: version.projectId,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
                modsDir: cachePath
            )

            if !isInstalled {
                missingDependencyVersions.append(version)
            }
        }

        return ModrinthProjectDependency(projects: missingDependencyVersions)
    }
}
