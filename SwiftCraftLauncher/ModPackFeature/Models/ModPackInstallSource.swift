//
//  ModPackInstallSource.swift
//  ModPackFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The origin of a modpack installation.
///
/// Local import, direct URL download, and online project installation differ only
/// in how the archive is obtained; everything after that runs the same
/// `ModPackInstallCoordinator` pipeline.
enum ModPackInstallSource {
    /// A local `.mrpack` or `.zip` archive.
    case local(URL)
    /// A user-provided direct download URL.
    case remoteURL
    /// A modpack version selected from an online project.
    case project(projectId: String, preloadedDetail: ModrinthProjectDetail?)

    var id: String {
        switch self {
        case let .local(url):
            return "local:\(url.path)"
        case .remoteURL:
            return "remote-url"
        case let .project(projectId, _):
            return "project:\(projectId)"
        }
    }
}
