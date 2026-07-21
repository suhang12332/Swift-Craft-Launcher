//
//  JavaRuntimeService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Provides Java runtime version information and manifest URLs for the current platform.
class JavaRuntimeService {
    private static let armJavaVersions: [String: URL] = [
        "jre-legacy": URLConfig.API.JavaRuntimeARM.jreLegacy,
        "java-runtime-alpha": URLConfig.API.JavaRuntimeARM.javaRuntimeAlpha,
        "java-runtime-beta": URLConfig.API.JavaRuntimeARM.javaRuntimeBeta,
    ]

    private static let intelJavaVersions: [String: URL] = [
        "jre-legacy": URLConfig.API.JavaRuntimeIntel.jreLegacy,
        "java-runtime-alpha": URLConfig.API.JavaRuntimeIntel.javaRuntimeAlpha,
        "java-runtime-beta": URLConfig.API.JavaRuntimeIntel.javaRuntimeBeta,
    ]

    func specialJavaRuntimeURL(for version: String) -> URL? {
        switch Architecture.current {
        case .arm64:
            return Self.armJavaVersions[version]
        case .x86_64:
            return Self.intelJavaVersions[version]
        }
    }

    func getGamecoreSupportedVersions() async throws -> [String] {
        let json = try await fetchJavaRuntimeAPI()
        guard let gamecore = json["gamecore"] as? [String: Any] else {
            throw GlobalError.validation(
                i18nKey: "error.validation.gamecore_not_found",
                level: .notification,
                message: "no 'gamecore' key found in Java runtime API response",
            )
        }

        return Array(gamecore.keys)
    }

    func getMacJavaRuntimeData() async throws -> [String: Any] {
        let json = try await fetchJavaRuntimeAPI()
        let platform = getCurrentMacPlatform()
        guard let platformData = json[platform] as? [String: Any] else {
            throw GlobalError.validation(
                i18nKey: "error.validation.platform_data_not_found",
                level: .notification,
                message: "no data for platform '\(platform)' in Java runtime API response",
            )
        }

        return platformData
    }

    func getMacJavaRuntimeData(for version: String) async throws -> [[String: Any]] {
        let platformData = try await getMacJavaRuntimeData()
        guard let versionData = platformData[version] as? [[String: Any]] else {
            AppLog.game.error("Version \(version) data type is incorrect, expected [[String: Any]], actual: \(type(of: platformData[version]))")
            throw GlobalError.validation(
                i18nKey: "error.validation.version_data_not_found",
                level: .notification,
                message: "version '\(version)' data not found or wrong type in platform data",
            )
        }

        return versionData
    }

    func getManifestURL(for version: String) async throws -> String {
        let versionData = try await getMacJavaRuntimeData(for: version)
        guard let firstVersion = versionData.first,
              let manifest = firstVersion["manifest"] as? [String: Any],
              let manifestURL = manifest["url"] as? String else {
            AppLog.game.error("Unable to parse version \(version) data structure")
            throw GlobalError.validation(
                i18nKey: "error.validation.manifest_url_not_found",
                level: .notification,
                message: "unable to parse manifest URL from version '\(version)' data structure",
            )
        }

        AppLog.game.info("Found manifest URL for version \(version): \(manifestURL)")
        return manifestURL
    }

    private func fetchJavaRuntimeAPI() async throws -> [String: Any] {
        let url = URLConfig.API.JavaRuntime.allRuntimes
        let data = try await fetchDataFromURL(url.absoluteString)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GlobalError.validation(
                i18nKey: "error.validation.json_parse_failed",
                level: .notification,
                message: "failed to parse Java runtime API JSON from URL: \(url.absoluteString)",
            )
        }

        return json
    }

    private func fetchDataFromURL(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_url",
                level: .notification,
                message: "invalid URL: \(urlString)",
            )
        }
        return try await APIClient.get(url: url)
    }

    private func getCurrentMacPlatform() -> String {
        Architecture.current.macPlatformId
    }
}
