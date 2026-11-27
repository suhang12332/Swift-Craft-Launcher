//
//  PlayerSettingsViewModel.swift
//  PlayerFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Manages player-related settings in the settings view.
@MainActor
@Observable
final class PlayerSettingsViewModel {
    var isDownloadingAuthlibInjector: Bool = false
    var authlibInjectorExists: Bool = false

    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init() {
        sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: DIContainer.shared.ui.playerDataManager,
            source: .settings,
        )
    }

    /// Updates whether the authlib-injector JAR file exists on disk.
    func refreshAuthlibInjectorExists() {
        authlibInjectorExists = FileManager.default.fileExists(atPath: AppConstants.AuthlibInjector.jarPath)
    }

    /// Fetches the latest authlib-injector version info from GitHub.
    /// - Returns: A tuple of (version, downloadURL), or nil if the request fails.
    private func fetchLatestAuthlibInjectorVersion() async -> (version: String, downloadURL: URL)? {
        guard let data = try? await APIClient.get(url: URLConfig.API.AuthlibInjector.latestRelease),
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            return nil
        }
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        let downloadURL = URLConfig.API.AuthlibInjector.downloadURL(version)
        return (version, downloadURL)
    }

    /// Downloads the latest authlib-injector JAR from GitHub releases.
    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        do {
            guard let latest = await fetchLatestAuthlibInjectorVersion() else {
                throw GlobalError.download(
                    i18nKey: "error.download.authlib_injector_failed",
                    level: .notification,
                )
            }

            let authDir = AppPaths.authDirectory

            // Remove all existing files in the auth directory
            if let files = try? FileManager.default.contentsOfDirectory(atPath: authDir.path) {
                for file in files {
                    try? FileManager.default.removeItem(at: authDir.appendingPathComponent(file))
                }
            }

            let destinationURL = authDir.appendingPathComponent(latest.downloadURL.lastPathComponent)

            _ = try await DownloadManager.downloadFile(
                urlString: latest.downloadURL.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: nil,
            )

            authlibInjectorExists = true
            Defaults.save(latest.version, forKey: AppConstants.UserDefaultsKeys.authlibInjectorVersion)
        } catch {
            let globalError = GlobalError.download(
                i18nKey: "error.download.authlib_injector_failed",
                level: .notification,
            )
            sideEffects.handle(globalError)
        }
    }
}
