//
//  InstalledModPack.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The upstream identity and hashes of files owned by a Modrinth pack.
/// Stored inside the profile so renaming or moving a profile keeps its provenance.
struct InstalledModPack: Codable, Sendable {
    static let fileName = ".swiftcraft-modpack.json"

    let projectId: String
    let versionId: String
    let versionName: String
    let publishedAt: Date
    let versionType: String
    var files: [String: String]

    static func load(from directory: URL) throws -> Self {
        let url = directory.appendingPathComponent(fileName)
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func save(to directory: URL) throws {
        try JSONEncoder().encode(self).write(
            to: directory.appendingPathComponent(Self.fileName),
            options: .atomic,
        )
    }

    /// Rejects archive paths that can escape the profile or overwrite user data.
    static func fileURL(_ path: String, in directory: URL) throws -> URL {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        let protected = ["saves", "screenshots", "logs", "crash-reports", "backups"]
        guard !path.isEmpty, !path.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let first = components.first, !first.hasPrefix("."),
              !protected.contains(String(first).lowercased()),
              path.lowercased() != "servers.dat", path.lowercased() != "servers.dat_old"
        else {
            throw ModPackUpdateError.unsafePath(path)
        }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        let url = root.appendingPathComponent(path)
        guard url.resolvingSymlinksInPath().path.hasPrefix(root.path + "/") else {
            throw ModPackUpdateError.unsafePath(path)
        }
        // Even an internal symlink can alias an unrelated user file.
        var ancestor = url
        while ancestor != root {
            if (try? ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw ModPackUpdateError.unsafePath(path)
            }
            ancestor.deleteLastPathComponent()
        }
        return url
    }
}

enum ModPackUpdateError: LocalizedError {
    case unsafePath(String)
    case conflict(String)
    case incompatible
    case incomplete
    case busy

    var errorDescription: String? {
        switch self {
        case let .unsafePath(path):
            return String(format: "modpack.update.error.path".localized(), path)
        case let .conflict(path):
            return String(format: "modpack.update.error.conflict".localized(), path)
        case .incompatible: return "modpack.update.error.compatibility".localized()
        case .incomplete: return "modpack.update.error.incomplete".localized()
        case .busy: return "modpack.update.error.busy".localized()
        }
    }
}
