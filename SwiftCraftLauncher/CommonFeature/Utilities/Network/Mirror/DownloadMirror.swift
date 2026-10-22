//
//  DownloadMirror.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A mirror site that serves official Minecraft files from inside mainland China.
///
/// Every mirror is expressed as a set of `official host -> mirror base URL`
/// mappings. A base URL may carry a path prefix, because some mirrors group a
/// resource class under a directory (BMCLAPI serves assets under `/assets` and
/// libraries under `/libraries`, for example).
///
/// Mirrors are deliberately limited to plain host rewriting: the official path
/// is preserved verbatim, so no manifest context (version id, asset index id)
/// is required to build the mirrored URL.
enum DownloadMirror: String, CaseIterable, Sendable, Codable {
    /// BMCLAPI (bangbang93). Covers the vanilla client jar, version and asset
    /// index JSON, asset objects, and library/maven artifacts.
    case bmclapi

    /// The user-visible name shown in settings.
    var displayName: String {
        switch self {
        case .bmclapi:
            return "BMCLAPI"
        }
    }

    /// Official host -> mirror base URL. Keys are lowercased host names.
    private var hostMappings: [String: String] {
        switch self {
        case .bmclapi:
            return [
                "resources.download.minecraft.net": "https://bmclapi2.bangbang93.com/assets",
                "piston-meta.mojang.com": "https://bmclapi2.bangbang93.com",
                "piston-data.mojang.com": "https://bmclapi2.bangbang93.com",
                "launcher.mojang.com": "https://bmclapi2.bangbang93.com",
                "launchermeta.mojang.com": "https://bmclapi2.bangbang93.com",
                "libraries.minecraft.net": "https://bmclapi2.bangbang93.com/libraries",
            ]
        }
    }

    /// Rewrites an official URL into its mirrored form.
    /// - Parameter url: The official download URL.
    /// - Returns: The mirrored URL, or `nil` when this mirror does not cover the host.
    func mirroredURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased(),
              let base = hostMappings[host],
              let baseComponents = URLComponents(string: base),
              let baseHost = baseComponents.host else {
            return nil
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = baseComponents.scheme
        components.host = baseHost
        components.path = baseComponents.path + components.path
        return components.url
    }

    /// Whether the mirror is expected to serve the given URL's host.
    func covers(_ url: URL) -> Bool {
        mirroredURL(for: url) != nil
    }
}
