//
//  ModrinthService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides access to the Modrinth API for Minecraft mod information and versions.
enum ModrinthService {
    static func fetchVersionInfo(from version: String) async throws -> MinecraftVersionManifest {
        if let cachedVersionInfo: MinecraftVersionManifest = DIContainer.shared.core.appCacheManager.get(
            namespace: version,
            key: "manifest",
            as: MinecraftVersionManifest.self,
            directory: AppPaths.versionCache,
        ) {
            return cachedVersionInfo
        }

        let versionInfo = try await fetchVersionInfoThrowing(from: version)

        DIContainer.shared.core.appCacheManager.setSilently(
            namespace: version,
            key: "manifest",
            value: versionInfo,
            directory: AppPaths.versionCache,
        )

        return versionInfo
    }

    static func queryVersionTime(from version: String) async -> String {
        let cacheKey = "version_time_\(version)"

        if let cachedTime: String = DIContainer.shared.core.appCacheManager.get(
            namespace: "version_time",
            key: cacheKey,
            as: String.self,
        ) {
            return cachedTime
        }

        do {
            let versionInfo = try await Self.fetchVersionInfo(from: version)
            let formattedTime = CommonUtil.formatRelativeTime(versionInfo.releaseTime)

            DIContainer.shared.core.appCacheManager.setSilently(
                namespace: "version_time",
                key: cacheKey,
                value: formattedTime,
            )
            return formattedTime
        } catch {
            return ""
        }
    }

    static func fetchVersionInfoThrowing(from version: String) async throws -> MinecraftVersionManifest {
        let url = URLConfig.API.Modrinth.versionInfo(version: version)
        let data = try await APIClient.get(url: url)

        do {
            let decoder = JSONDecoder()
            decoder.configureForModrinth()
            return try decoder.decode(MinecraftVersionManifest.self, from: data)
        } catch {
            if error is GlobalError {
                throw error
            } else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.version_info_parse_failed",
                    level: .notification,
                    message: "Failed to parse Minecraft version manifest for version '\(version)': \(error.localizedDescription)",
                )
            }
        }
    }

    static func filterPrimaryFiles(from files: [ModrinthVersionFile]?) -> ModrinthVersionFile? {
        files?.first { $0.primary == true }
    }

    static func fetchModrinthDetail(
        by hash: String,
        completion: @escaping @MainActor @Sendable (ModrinthProjectDetail?) -> Void,
    ) {
        Task {
            do {
                let detail = try await fetchModrinthDetailThrowing(by: hash)
                await completion(detail)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.common.error("Failed to fetch project details by hash (Hash: \(hash)): \(globalError.localizedDescription)")
                await completion(nil)
            }
        }
    }

    static func fetchModrinthDetailThrowing(by hash: String) async throws -> ModrinthProjectDetail {
        let url = URLConfig.API.Modrinth.versionFile(hash: hash)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        let version = try decoder.decode(ModrinthProjectDetailVersion.self, from: data)

        return try await Self.fetchProjectDetailsThrowing(id: version.projectId)
    }
}
