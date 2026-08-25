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
        if let cachedData: Data = DIContainer.shared.core.appCacheManager.get(
            namespace: version,
            key: "manifest",
            as: Data.self,
            directory: AppPaths.versionCache,
        ) {
            return try decodeVersionInfo(from: cachedData, version: version)
        }

        let data = try await fetchVersionInfoDataThrowing(from: version)
        let versionInfo = try decodeVersionInfo(from: data, version: version)

        do {
            try DIContainer.shared.core.appCacheManager.set(
                namespace: version,
                key: "manifest",
                value: data,
                directory: AppPaths.versionCache,
            )
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }

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

            do {
                try DIContainer.shared.core.appCacheManager.set(
                    namespace: "version_time",
                    key: cacheKey,
                    value: formattedTime,
                )
            } catch {
                DIContainer.shared.core.errorHandler.handle(error)
            }
            return formattedTime
        } catch {
            return ""
        }
    }

    /// Fetches the raw Modrinth version manifest JSON data.
    private static func fetchVersionInfoDataThrowing(from version: String) async throws -> Data {
        let url = URLConfig.API.Modrinth.versionInfo(version: version)
        return try await APIClient.get(url: url)
    }

    /// Decodes a Minecraft version manifest from its raw JSON data.
    private static func decodeVersionInfo(from data: Data, version: String) throws -> MinecraftVersionManifest {
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

    static func fetchModrinthDetailThrowing(by hash: String) async throws -> ModrinthProjectDetail {
        let url = URLConfig.API.Modrinth.versionFile(hash: hash)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        let version = try decoder.decode(ModrinthProjectDetailVersion.self, from: data)

        return try await Self.fetchProjectDetailsThrowing(id: version.projectId)
    }
}
