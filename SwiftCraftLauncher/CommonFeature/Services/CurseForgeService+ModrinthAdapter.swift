import Foundation

extension CurseForgeService {
    // MARK: - Project Detail Methods (as Modrinth format)

    /// 获取项目详情（映射为 Modrinth 格式，静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: Modrinth 格式的项目详情，失败时返回 nil
    static func fetchProjectDetailsAsModrinth(id: String) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return nil
        }
    }

    /// 获取项目详情（映射为 Modrinth 格式，抛出异常版本）
    /// - Parameter id: 项目 ID（可能包含 "cf-" 前缀）
    /// - Returns: Modrinth 格式的项目详情
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectDetailsAsModrinthThrowing(id: String) async throws -> ModrinthProjectDetail {
        let (modId, _) = try parseCurseForgeId(id)

        // 并发获取项目详情和描述
        async let cfDetailTask = fetchModDetailThrowing(modId: modId)
        async let descriptionTask = fetchModDescriptionThrowing(modId: modId)

        let cfDetail = try await cfDetailTask
        let description = try await descriptionTask

        guard var modrinthDetail = CFToModrinthAdapter.convertProjectDetail(cfDetail, descriptionHTML: description) else {
            throw GlobalError.validation(
                chineseMessage: "转换项目详情失败",
                i18nKey: "error.validation.project_detail_convert_failed",
                level: .notification
            )
        }
        let releaseGameVersions = modrinthDetail.gameVersions.filter {
            $0.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
        }
        let result = CommonUtil.sortMinecraftVersions(releaseGameVersions)
        modrinthDetail.gameVersions = CommonUtil.versionsAtLeast(result)

        return modrinthDetail
    }

    /// 通过文件 fingerprint 获取项目详情（映射为 Modrinth 格式）
    /// - Parameter fingerprint: CurseForge file fingerprint（UInt32）
    /// - Returns: Modrinth 格式的项目详情，如果未匹配或失败返回 nil
    static func fetchProjectDetailsAsModrinthByFingerprint(fingerprint: UInt32) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsAsModrinthByFingerprintThrowing(fingerprint: fingerprint)
        } catch {
            Logger.shared.error("通过 fingerprint 获取 CurseForge 项目详情失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 通过文件 fingerprint 获取项目详情（映射为 Modrinth 格式）
    /// - Parameter fingerprint: CurseForge file fingerprint（UInt32）
    /// - Returns: Modrinth 格式的项目详情
    static func fetchProjectDetailsAsModrinthByFingerprintThrowing(fingerprint: UInt32) async throws -> ModrinthProjectDetail? {
        let matches = try await fetchFingerprintMatchesThrowing(fingerprint: fingerprint)
        // 仅使用 exactMatches 的第一个 modId；找不到则返回 nil
        let modId = matches
            .data
            .exactMatches?
            .compactMap { $0.file?.modId }
            .first

        guard let modId else { return nil }
        return try await fetchProjectDetailsAsModrinthThrowing(id: "\(modId)")
    }

    /// 通过文件 fingerprint 获取 CurseForge 的 projectId/fileId
    /// - Parameter fingerprint: CurseForge file fingerprint（UInt32）
    /// - Returns: (projectId, fileId)，如果无精确匹配返回 nil
    static func fetchProjectAndFileByFingerprint(fingerprint: UInt32) async -> (projectId: Int, fileId: Int)? {
        do {
            let matches = try await fetchFingerprintMatchesThrowing(fingerprint: fingerprint)
            guard let match = matches.data.exactMatches?.first,
                  let projectId = match.file?.modId,
                  let fileId = match.file?.id else {
                return nil
            }
            return (projectId, fileId)
        } catch {
            if error is CancellationError {
                return nil
            }
            Logger.shared.warning("通过 fingerprint 获取 CurseForge 文件信息失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取项目版本列表（映射为 Modrinth 格式，静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: Modrinth 格式的版本列表，失败时返回空数组
    static func fetchProjectVersionsAsModrinth(id: String) async -> [ModrinthProjectDetailVersion] {
        do {
            return try await fetchProjectVersionsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目版本列表失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    /// 获取项目版本列表（映射为 Modrinth 格式，抛出异常版本）
    /// - Parameter id: 项目 ID（可能包含 "cf-" 前缀）
    /// - Returns: Modrinth 格式的版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionsAsModrinthThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        let (modId, normalizedId) = try parseCurseForgeId(id)

        let cfFiles = try await fetchProjectFilesThrowing(projectId: modId)
        return cfFiles.compactMap { CFToModrinthAdapter.convertFile($0, projectId: normalizedId) }
    }

    /// 获取项目版本列表（过滤版本，映射为 Modrinth 格式）
    /// - Parameters:
    ///   - id: 项目 ID（可能包含 "cf-" 前缀）
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    ///   - type: 项目类型
    /// - Returns: 过滤后的 Modrinth 格式版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionsFilterAsModrinth(
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String
    ) async throws -> [ModrinthProjectDetailVersion] {
        let (modId, normalizedId) = try parseCurseForgeId(id)

        // 对于光影包、资源包、数据包，CurseForge API 不支持 modLoaderType 过滤
        let resourceTypeLowercased = type.lowercased()
        let shouldFilterByLoader = !(resourceTypeLowercased == ResourceType.shader.rawValue ||
                                     resourceTypeLowercased == ResourceType.resourcepack.rawValue ||
                                     resourceTypeLowercased == ResourceType.datapack.rawValue)

        // 转换加载器名称到 CurseForge ModLoaderType（仅对需要过滤加载器的资源类型）
        var modLoaderTypes: [Int] = []
        if shouldFilterByLoader {
            for loader in selectedLoaders {
                if let loaderType = CurseForgeModLoaderType.from(loader) {
                    modLoaderTypes.append(loaderType.rawValue)
                }
            }
        }

        // 获取文件列表
        // 优化：如果版本数量较少（<=3），为每个版本单独获取；否则一次性获取所有文件然后过滤
        var cfFiles: [CurseForgeModFileDetail] = []
        if !selectedVersions.isEmpty && selectedVersions.count <= 3 {
            // 版本数量较少时，为每个版本获取文件（更精确）
            for version in selectedVersions {
                // 对于光影包、资源包、数据包，不传递 modLoaderType 参数
                let modLoaderType = shouldFilterByLoader && !modLoaderTypes.isEmpty ? modLoaderTypes.first : nil
                let files = try await fetchProjectFilesThrowing(
                    projectId: modId,
                    gameVersion: version,
                    modLoaderType: modLoaderType
                )
                cfFiles.append(contentsOf: files)
            }
        } else {
            // 版本数量较多或为空时，一次性获取所有文件，然后进行过滤（减少API调用和内存占用）
            cfFiles = try await fetchProjectFilesThrowing(
                projectId: modId,
                gameVersion: nil,
                modLoaderType: shouldFilterByLoader && !modLoaderTypes.isEmpty ? modLoaderTypes.first : nil
            )
        }

        // 去重：按 fileId 去重，保留第一个
        var seenFileIds = Set<Int>()
        cfFiles = cfFiles.filter { file in
            if seenFileIds.contains(file.id) {
                return false
            }
            seenFileIds.insert(file.id)
            return true
        }

        // 过滤文件
        let filteredFiles = cfFiles.filter { file in
            // 版本匹配
            let versionMatch = selectedVersions.isEmpty || !Set(file.gameVersions).isDisjoint(with: selectedVersions)

            // 对于光影包、资源包、数据包，不需要检查加载器匹配
            // 其他类型需匹配加载器，CurseForge API 可能不返回，简化处理
            let loaderMatch = !shouldFilterByLoader || modLoaderTypes.isEmpty || true

            return versionMatch && loaderMatch
        }

        // 转换为 Modrinth 格式，确保 projectId 包含 "cf-" 前缀
        return filteredFiles.compactMap { CFToModrinthAdapter.convertFile($0, projectId: normalizedId) }
    }

    /// 过滤出主要文件
    static func filterPrimaryFiles(from files: [CurseForgeModFileDetail]?) -> CurseForgeModFileDetail? {
        // CurseForge 没有 primary 字段，返回第一个文件
        return files?.first
    }
}
