//
//  ResourceProcessor.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Identifies resource files and determines whether to add them to the index or copy them to overrides.
enum ResourceProcessor {
    struct ProcessResult {
        let indexFile: ModrinthIndexFile?
        let shouldCopyToOverrides: Bool
        let sourceFile: URL
        let relativePath: String
    }

    /// Identifies a resource file without copying it.
    /// - Parameters:
    ///   - file: The URL of the resource file.
    ///   - relativePath: The relative path within the overrides directory (e.g., "mods", "datapacks").
    /// - Returns: The identification result.
    static func identify(
        file: URL,
        relativePath: String,
    ) async -> ProcessResult {
        var indexFile: ModrinthIndexFile?
        if let modrinthResult = await ModrinthResourceIdentifier.getModrinthInfo(for: file) {
            indexFile = await createIndexFile(
                from: file,
                fileHash: modrinthResult.fileHash,
                modrinthInfo: modrinthResult.info,
                relativePath: relativePath,
            )
        }

        if let indexFile {
            return ProcessResult(
                indexFile: indexFile,
                shouldCopyToOverrides: false,
                sourceFile: file,
                relativePath: relativePath,
            )
        }

        return ProcessResult(
            indexFile: nil,
            shouldCopyToOverrides: true,
            sourceFile: file,
            relativePath: relativePath,
        )
    }

    /// Copies a file to the overrides directory.
    /// - Parameters:
    ///   - file: The source file URL.
    ///   - relativePath: The relative path within the overrides directory.
    ///   - overridesDir: The overrides directory URL.
    /// - Throws: An error if the copy operation fails.
    static func copyToOverrides(
        file: URL,
        relativePath: String,
        overridesDir: URL,
    ) throws {
        let overridesSubDir = overridesDir.appendingPathComponent(relativePath)
        let destPath = overridesSubDir.appendingPathComponent(file.lastPathComponent)

        try FileManager.default.createDirectory(at: overridesSubDir, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destPath.path) {
            try? FileManager.default.removeItem(at: destPath)
        }

        try FileManager.default.copyItem(at: file, to: destPath)
    }

    private static func createIndexFile(
        from modFile: URL,
        fileHash: String,
        modrinthInfo: ModrinthResourceIdentifier.ModrinthModInfo,
        relativePath: String,
    ) async -> ModrinthIndexFile? {
        let matchingFile = modrinthInfo.version.files.first { file in
            file.hashes.sha1 == fileHash
        } ?? modrinthInfo.version.files.first

        guard let matchingFile else {
            return nil
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: modFile.path)[.size] as? Int64) ?? 0

        let clientEnv = modrinthInfo.projectDetail.clientSide == "optional" ? "optional" : "required"
        let serverEnv = modrinthInfo.projectDetail.serverSide == "optional" ? "optional" : "required"

        let env = ModrinthIndexFileEnv(client: clientEnv, server: serverEnv)

        let indexPath: String
        if relativePath.isEmpty {
            indexPath = modFile.lastPathComponent
        } else {
            indexPath = "\(relativePath)/\(modFile.lastPathComponent)"
        }

        return ModrinthIndexFile(
            path: indexPath,
            hashes: ModrinthIndexFileHashes(from: [
                "sha1": matchingFile.hashes.sha1,
                "sha512": matchingFile.hashes.sha512,
            ]),
            downloads: [matchingFile.url],
            fileSize: Int(fileSize),
            env: env,
            source: .modrinth,
        )
    }
}

/// Fetches resource information from the Modrinth API.
enum ModrinthResourceIdentifier {
    struct ModrinthModInfo {
        let projectDetail: ModrinthProjectDetail
        let version: ModrinthProjectDetailVersion
    }

    struct ModrinthLookupResult {
        let info: ModrinthModInfo
        let fileHash: String
    }

    private static let infoCache = ModrinthInfoCache()

    /// Looks up Modrinth information for a mod file by its SHA-1 hash.
    ///
    /// Results are cached in memory to avoid redundant network requests.
    /// - Parameter modFile: The URL of the mod file to look up.
    /// - Returns: The lookup result, or `nil` if the file is not found on Modrinth.
    static func getModrinthInfo(for modFile: URL) async -> ModrinthLookupResult? {
        guard let hash = try? SHA1Calculator.sha1(ofFileAt: modFile) else {
            return nil
        }

        if let cached = await infoCache.get(hash: hash) {
            return ModrinthLookupResult(info: cached, fileHash: hash)
        }

        return await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                guard let detail else {
                    continuation.resume(returning: nil)
                    return
                }
                Task {
                    do {
                        let versions = try await ModrinthService.fetchProjectVersionsThrowing(id: detail.id)
                        if let matchingVersion = versions.first(where: { version in
                            version.files.contains { $0.hashes.sha1 == hash }
                        }) {
                            let info = ModrinthModInfo(
                                projectDetail: detail,
                                version: matchingVersion,
                            )
                            await infoCache.set(info: info, for: hash)
                            continuation.resume(
                                returning: ModrinthLookupResult(
                                    info: info,
                                    fileHash: hash,
                                ),
                            )
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

/// An in-memory cache for Modrinth project information, keyed by file hash.
private actor ModrinthInfoCache {
    private var cache: [String: ModrinthResourceIdentifier.ModrinthModInfo] = [:]

    func get(hash: String) -> ModrinthResourceIdentifier.ModrinthModInfo? {
        cache[hash]
    }

    func set(info: ModrinthResourceIdentifier.ModrinthModInfo, for hash: String) {
        cache[hash] = info
    }
}
