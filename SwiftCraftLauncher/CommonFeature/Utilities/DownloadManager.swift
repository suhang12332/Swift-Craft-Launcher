//
//  DownloadManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

enum DownloadManager {
    enum ResourceType: String {
        case mod, datapack, shader, resourcepack

        var folderName: String {
            switch self {
            case .mod: return AppConstants.DirectoryNames.mods
            case .datapack: return AppConstants.DirectoryNames.datapacks
            case .shader: return AppConstants.DirectoryNames.shaderpacks
            case .resourcepack: return AppConstants.DirectoryNames.resourcepacks
            }
        }

        init?(from string: String) {
            let lowercased = string.lowercased()
            switch lowercased {
            case Self.mod.rawValue: self = .mod
            case Self.datapack.rawValue: self = .datapack
            case Self.shader.rawValue: self = .shader
            case Self.resourcepack.rawValue: self = .resourcepack
            default: return nil
            }
        }
    }

    /// Downloads a resource file to the appropriate game directory.
    /// - Parameters:
    ///   - game: The game version information.
    ///   - urlString: The download URL string.
    ///   - resourceType: The resource type (e.g., "mod", "datapack", "shader", "resourcepack").
    ///   - expectedSha1: An optional expected SHA-1 hash for verification.
    /// - Returns: The local URL of the downloaded file.
    /// - Throws: A ``GlobalError`` if the operation fails.
    static func downloadResource(for game: GameVersionInfo, urlString: String, resourceType: String, expectedSha1: String? = nil) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_download_url",
                level: .notification,
            )
        }

        guard let type = ResourceType(from: resourceType) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.unknown_type",
                level: .notification,
            )
        }

        let resourceDir: URL? = {
            switch type {
            case .mod:
                return AppPaths.modsDirectory(gameName: game.gameName)
            case .datapack:
                let lowercasedPath = url.lastPathComponent.lowercased()
                if lowercasedPath.hasSuffix(".\(AppConstants.FileExtensions.jar)") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.datapacksDirectory(gameName: game.gameName)
            case .shader:
                return AppPaths.shaderpacksDirectory(gameName: game.gameName)
            case .resourcepack:
                let lowercasedPath = url.lastPathComponent.lowercased()
                if lowercasedPath.hasSuffix(".\(AppConstants.FileExtensions.jar)") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.resourcepacksDirectory(gameName: game.gameName)
            }
        }()

        guard let resourceDirUnwrapped = resourceDir else {
            throw GlobalError.resource(
                i18nKey: "error.resource.directory_not_found",
                level: .notification,
            )
        }

        let destURL = resourceDirUnwrapped.appendingPathComponent(url.lastPathComponent)
        return try await downloadFile(
            urlString: url.absoluteString,
            destinationURL: destURL,
            expectedSha1: expectedSha1,
        )
    }

    /// Downloads a file to a specified destination URL.
    /// - Parameters:
    ///   - urlString: The download URL string.
    ///   - destinationURL: The local file destination.
    ///   - expectedSha1: An optional expected SHA-1 hash for verification.
    /// - Returns: The local URL of the downloaded file.
    /// - Throws: A ``GlobalError`` if the operation fails.
    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil,
    ) async throws -> URL {
        do {
            return try await ProgressDownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationURL,
                expectedSha1: expectedSha1,
                progressHandler: nil,
            )
        } catch {
            throw mapDownloadError(error)
        }
    }

    private static func mapDownloadError(_ error: Error) -> Error {
        if error is CancellationError {
            return error
        }
        if let globalError = error as? GlobalError {
            return globalError
        }
        if error is URLError {
            return GlobalError.download(
                i18nKey: "error.download.network_request_failed",
                level: .notification,
            )
        }
        return GlobalError.download(
            i18nKey: "error.download.general_failure",
            level: .notification,
        )
    }

    /// Downloads raw data from a URL.
    /// - Parameter url: The URL to download from.
    /// - Returns: The downloaded data.
    /// - Throws: A ``GlobalError`` if the operation fails.
    static func downloadData(from url: URL) async throws -> Data {
        do {
            return try await APIClient.get(url: url)
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else if error is URLError {
                throw GlobalError.download(
                    i18nKey: "error.download.network_request_failed",
                    level: .notification,
                )
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.general_failure",
                    level: .notification,
                )
            }
        }
    }
}
