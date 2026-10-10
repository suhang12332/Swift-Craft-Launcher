//
//  ModPackUpdateFiles.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Builds a replacement profile without changing the installed profile.
enum ModPackUpdateFiles {
    /// Hashes only upstream files, never user-added files in the installed profile.
    static func manifest(
        index: ModrinthIndexInfo,
        extracted: URL,
        version: ModrinthProjectDetailVersion,
    ) throws -> InstalledModPack {
        guard index.source == .modrinth, index.dependencies.isEmpty else {
            throw ModPackUpdateError.incompatible
        }
        var hashes: [String: String] = [:]
        var pathsByCase: [String: String] = [:]
        for file in index.files where file.env?.client != "unsupported" {
            _ = try InstalledModPack.fileURL(file.path, in: extracted)
            guard let hash = file.hashes.sha1, hash.count == 40,
                  hash.allSatisfy(\.isHexDigit)
            else {
                throw ModPackUpdateError.incomplete
            }
            if let existing = pathsByCase.updateValue(file.path, forKey: file.path.lowercased()), existing != file.path {
                throw ModPackUpdateError.unsafePath(file.path)
            }
            guard hashes.updateValue(hash, forKey: file.path) == nil else {
                throw ModPackUpdateError.unsafePath(file.path)
            }
        }
        for folder in ["overrides", "client-overrides"] {
            let root = extracted.appendingPathComponent(folder)
            if FileManager.default.fileExists(atPath: root.path) {
                for path in try relativeFiles(in: root) {
                    if let existing = pathsByCase.updateValue(path, forKey: path.lowercased()), existing != path {
                        throw ModPackUpdateError.unsafePath(path)
                    }
                    let url = try InstalledModPack.fileURL(path, in: root)
                    hashes[path] = try SHA1Calculator.sha1(ofFileAt: url)
                }
            }
        }
        return InstalledModPack(
            projectId: version.projectId,
            versionId: version.id,
            versionName: version.name,
            publishedAt: version.datePublished,
            versionType: version.versionType,
            files: hashes,
        )
    }

    static func relativeFiles(in root: URL) throws -> [String] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var enumerationError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            errorHandler: { _, error in
                enumerationError = error
                return false
            },
        ) else { throw ModPackUpdateError.incomplete }
        var paths: [String] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true else {
                throw ModPackUpdateError.unsafePath(url.lastPathComponent)
            }
            if values.isRegularFile == true {
                paths.append(String(url.path.dropFirst(root.path.count + 1)))
            }
        }
        if let enumerationError {
            throw enumerationError
        }
        return paths.sorted()
    }

    /// Links an older installation only when its pack mods match the selected release.
    static func validateLink(_ pack: InstalledModPack, profile: URL) throws {
        for (path, hash) in pack.files where path.hasPrefix("mods/") {
            let file = try existingFile(path, in: profile)
            guard FileManager.default.fileExists(atPath: file.path),
                  try SHA1Calculator.sha1(ofFileAt: file) == hash
            else { throw ModPackUpdateError.conflict(path) }
        }
    }

    /// Preserves modified configuration files and disabled mods. Changed mods fail closed.
    static func merge(
        old: InstalledModPack,
        new: InstalledModPack,
        payload: URL,
        replacement: URL,
    ) throws {
        let fm = FileManager.default
        try validateLink(old, profile: replacement)
        var managed = new
        let disabledTargets = try renamedDisabledMods(old: old, new: new, payload: payload, profile: replacement)
        for path in Set(old.files.keys).union(new.files.keys).sorted() {
            try Task.checkCancellation()
            let destination = try InstalledModPack.fileURL(disabledTargets[path] ?? path, in: replacement)
            let effectiveDestination = disabledTargets[path] == nil ? try existingFile(path, in: replacement) : destination
            let exists = fm.fileExists(atPath: effectiveDestination.path)
            let currentHash = exists ? try SHA1Calculator.sha1(ofFileAt: effectiveDestination) : nil
            if exists, old.files[path] == nil {
                if path.hasPrefix("mods/"), currentHash != new.files[path] {
                    throw ModPackUpdateError.conflict(path)
                }
                managed.files.removeValue(forKey: path)
                continue
            }
            if exists, currentHash != old.files[path], currentHash != new.files[path] {
                if path.hasPrefix("mods/") {
                    throw ModPackUpdateError.conflict(path)
                }
                continue
            }
            if let newHash = new.files[path] {
                let source = try InstalledModPack.fileURL(path, in: payload)
                guard try SHA1Calculator.sha1(ofFileAt: source) == newHash else {
                    throw ModPackUpdateError.incomplete
                }
                if exists {
                    try fm.removeItem(at: effectiveDestination)
                }
                try fm.createDirectory(at: effectiveDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: effectiveDestination)
            } else if exists, currentHash == old.files[path] {
                try fm.removeItem(at: effectiveDestination)
            }
        }
        try managed.save(to: replacement)
    }

    /// Fabric and Quilt retain stable IDs when their JAR filenames change between versions.
    private static func renamedDisabledMods(
        old: InstalledModPack,
        new: InstalledModPack,
        payload: URL,
        profile: URL,
    ) throws -> [String: String] {
        var disabledIds: Set<String> = []
        for path in old.files.keys where path.hasPrefix("mods/") && new.files[path] == nil {
            let disabled = try InstalledModPack.fileURL(path + ".disable", in: profile)
            if FileManager.default.fileExists(atPath: disabled.path) {
                guard let id = try modId(at: disabled) else { throw ModPackUpdateError.conflict(path) }
                disabledIds.insert(id)
            }
        }
        guard !disabledIds.isEmpty else { return [:] }
        var targets: [String: String] = [:]
        for path in new.files.keys where path.hasPrefix("mods/") && old.files[path] == nil {
            let source = try InstalledModPack.fileURL(path, in: payload)
            if let id = try modId(at: source), disabledIds.contains(id) {
                let enabled = try InstalledModPack.fileURL(path, in: profile)
                let disabled = try InstalledModPack.fileURL(path + ".disable", in: profile)
                guard !FileManager.default.fileExists(atPath: enabled.path),
                      !FileManager.default.fileExists(atPath: disabled.path)
                else { throw ModPackUpdateError.conflict(path) }
                targets[path] = path + ".disable"
            }
        }
        return targets
    }

    private static func modId(at url: URL) throws -> String? {
        guard let archive = try? Archive(url: url, accessMode: .read) else { return nil }
        for name in ["fabric.mod.json", "quilt.mod.json"] {
            if let entry = archive[name] {
                guard entry.uncompressedSize < 1_048_576 else { throw ModPackUpdateError.incomplete }
                var data = Data()
                _ = try archive.extract(entry) { data.append($0) }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if name == "fabric.mod.json" {
                    return json?["id"] as? String
                }
                return (json?["quilt_loader"] as? [String: Any])?["id"] as? String
            }
        }
        return nil
    }

    /// Detects external profile edits while downloads or staging are in progress.
    static func profileFingerprint(_ profile: URL) throws -> [String: String] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isSymbolicLinkKey]
        var enumerationError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: profile,
            includingPropertiesForKeys: Array(keys),
            errorHandler: { _, error in
                enumerationError = error
                return false
            },
        ) else {
            throw ModPackUpdateError.incomplete
        }
        var result: [String: String] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            let path = String(url.path.dropFirst(profile.path.count + 1))
            let target = values.isSymbolicLink == true ? try FileManager.default.destinationOfSymbolicLink(atPath: url.path) : ""
            result[path] = "\(values.contentModificationDate?.timeIntervalSince1970 ?? 0):\(values.fileSize ?? 0):\(target)"
        }
        if let enumerationError {
            throw enumerationError
        }
        return result
    }

    private static func existingFile(_ path: String, in profile: URL) throws -> URL {
        let enabled = try InstalledModPack.fileURL(path, in: profile)
        let disabled = try InstalledModPack.fileURL(path + ".disable", in: profile)
        if path.hasPrefix("mods/"), FileManager.default.fileExists(atPath: disabled.path) {
            guard !FileManager.default.fileExists(atPath: enabled.path) else {
                throw ModPackUpdateError.conflict(path)
            }
            return disabled
        }
        return enabled
    }
}
