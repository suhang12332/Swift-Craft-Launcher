//
//  CurseForgeService+ModrinthAdapter.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides CurseForge project operations with Modrinth-compatible data formats.
extension CurseForgeService {
    /// Fetches project details and converts them to Modrinth format.
    /// - Parameter id: The CurseForge project identifier (may include "cf-" prefix).
    /// - Returns: The project details in Modrinth format, or `nil` on failure.
    static func fetchProjectDetailsAsModrinth(id: String) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to fetch project details (ID: \(id)): \(globalError.localizedDescription)")
            AppServices.errorHandler.handle(globalError)
            return nil
        }
    }

    /// Fetches project details and converts them to Modrinth format, throwing on failure.
    /// - Parameter id: The CurseForge project identifier (may include "cf-" prefix).
    /// - Returns: The project details in Modrinth format.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchProjectDetailsAsModrinthThrowing(id: String) async throws -> ModrinthProjectDetail {
        let (modId, _) = try parseCurseForgeId(id)

        async let cfDetailTask = fetchModDetailThrowing(modId: modId)
        async let descriptionTask = fetchModDescriptionThrowing(modId: modId)

        let cfDetail = try await cfDetailTask
        let description = try await descriptionTask

        guard var modrinthDetail = CFToModrinthAdapter.convertProjectDetail(cfDetail, descriptionHTML: description) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_detail_convert_failed",
                level: .notification,
            )
        }
        let releaseGameVersions = modrinthDetail.gameVersions.filter {
            $0.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
        }
        let result = CommonUtil.sortMinecraftVersions(releaseGameVersions)
        modrinthDetail.gameVersions = CommonUtil.versionsAtLeast(result)

        return modrinthDetail
    }

    /// Fetches project details by file fingerprint in Modrinth format.
    /// - Parameter fingerprint: The CurseForge file fingerprint (UInt32).
    /// - Returns: The project details in Modrinth format, or `nil` if no match or on failure.
    static func fetchProjectDetailsAsModrinthByFingerprint(fingerprint: UInt32) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsAsModrinthByFingerprintThrowing(fingerprint: fingerprint)
        } catch {
            AppLog.common.error("Failed to fetch CurseForge project details by fingerprint: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches project details by file fingerprint in Modrinth format.
    /// - Parameter fingerprint: The CurseForge file fingerprint (UInt32).
    /// - Returns: The project details in Modrinth format.
    static func fetchProjectDetailsAsModrinthByFingerprintThrowing(fingerprint: UInt32) async throws -> ModrinthProjectDetail? {
        let matches = try await fetchFingerprintMatchesThrowing(fingerprint: fingerprint)
        let modId = matches
            .data
            .exactMatches?
            .compactMap { $0.file?.modId }
            .first

        guard let modId else { return nil }
        return try await fetchProjectDetailsAsModrinthThrowing(id: "\(modId)")
    }

    /// Fetches the CurseForge project and file identifiers for a file fingerprint.
    /// - Parameter fingerprint: The CurseForge file fingerprint (UInt32).
    /// - Returns: A tuple of (projectId, fileId), or `nil` if no exact match.
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
            AppLog.common.error("Failed to fetch CurseForge file info by fingerprint: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches the version list for a CurseForge project in Modrinth format.
    /// - Parameter id: The CurseForge project identifier.
    /// - Returns: An array of versions in Modrinth format, or an empty array on failure.
    static func fetchProjectVersionsAsModrinth(id: String) async -> [ModrinthProjectDetailVersion] {
        do {
            return try await fetchProjectVersionsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to fetch project version list (ID: \(id)): \(globalError.localizedDescription)")
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    /// Fetches the version list for a CurseForge project in Modrinth format, throwing on failure.
    /// - Parameter id: The CurseForge project identifier (may include "cf-" prefix).
    /// - Returns: An array of versions in Modrinth format.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchProjectVersionsAsModrinthThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        let (modId, normalizedId) = try parseCurseForgeId(id)

        let cfFiles = try await fetchProjectFilesThrowing(projectId: modId)
        return cfFiles.compactMap { CFToModrinthAdapter.convertFile($0, projectId: normalizedId) }
    }

    /// Fetches and filters project versions in Modrinth format.
    /// - Parameters:
    ///   - id: The CurseForge project identifier (may include "cf-" prefix).
    ///   - selectedVersions: The selected game versions to filter by.
    ///   - selectedLoaders: The selected mod loader types to filter by.
    ///   - type: The project type.
    /// - Returns: An array of filtered versions in Modrinth format.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchProjectVersionsFilterAsModrinth(
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
    ) async throws -> [ModrinthProjectDetailVersion] {
        let (modId, normalizedId) = try parseCurseForgeId(id)

        let resourceTypeLowercased = type.lowercased()
        let shouldFilterByLoader = !(resourceTypeLowercased == ResourceType.shader.rawValue ||
                                     resourceTypeLowercased == ResourceType.resourcepack.rawValue ||
                                     resourceTypeLowercased == ResourceType.datapack.rawValue)

        var modLoaderTypes: [Int] = []
        if shouldFilterByLoader {
            for loader in selectedLoaders {
                if let loaderType = CurseForgeModLoaderType.from(loader) {
                    modLoaderTypes.append(loaderType.rawValue)
                }
            }
        }

        var cfFiles: [CurseForgeModFileDetail] = []
        if !selectedVersions.isEmpty, selectedVersions.count <= 3 {
            for version in selectedVersions {
                let modLoaderType = shouldFilterByLoader && !modLoaderTypes.isEmpty ? modLoaderTypes.first : nil
                let files = try await fetchProjectFilesThrowing(
                    projectId: modId,
                    gameVersion: version,
                    modLoaderType: modLoaderType,
                )
                cfFiles.append(contentsOf: files)
            }
        } else {
            cfFiles = try await fetchProjectFilesThrowing(
                projectId: modId,
                gameVersion: nil,
                modLoaderType: shouldFilterByLoader && !modLoaderTypes.isEmpty ? modLoaderTypes.first : nil,
            )
        }

        var seenFileIds = Set<Int>()
        cfFiles = cfFiles.filter { file in
            if seenFileIds.contains(file.id) {
                return false
            }
            seenFileIds.insert(file.id)
            return true
        }

        let filteredFiles = cfFiles.filter { file in
            let versionMatch = selectedVersions.isEmpty || !Set(file.gameVersions).isDisjoint(with: selectedVersions)

            let loaderMatch = !shouldFilterByLoader || modLoaderTypes.isEmpty || true

            return versionMatch && loaderMatch
        }

        return filteredFiles.compactMap { CFToModrinthAdapter.convertFile($0, projectId: normalizedId) }
    }

    /// Returns the first file from the list as the primary file.
    static func filterPrimaryFiles(from files: [CurseForgeModFileDetail]?) -> CurseForgeModFileDetail? {
        files?.first
    }
}
