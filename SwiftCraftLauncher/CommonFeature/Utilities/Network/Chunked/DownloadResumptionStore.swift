//
//  DownloadResumptionStore.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The persisted progress of an interrupted chunked download.
struct DownloadResumptionState: Codable, Sendable {
    let url: String
    let etag: String?
    let lastModified: String?
    let fileSize: Int64
    let chunkCount: Int
    /// Bytes already written per chunk index.
    var chunks: [Int: Int64]
    var updatedAt: Date

    /// Guards against reusing progress recorded for a different file layout.
    func matches(etag: String?, fileSize: Int64, chunkCount: Int) -> Bool {
        guard self.fileSize == fileSize, self.chunkCount == chunkCount else { return false }
        if let etag, let stored = self.etag {
            return stored == etag
        }
        // Without an ETag on either side, fall back to Last-Modified.
        return lastModified == nil || lastModified == self.lastModified
    }
}

/// Persists partial chunked downloads so they can be resumed across app launches.
enum DownloadResumptionStore {
    /// How long an unfinished part is kept before cleanup discards it.
    static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    static func partFileURL(for key: String) -> URL {
        directory().appendingPathComponent("\(key).part", isDirectory: false)
    }

    static func metadataFileURL(for key: String) -> URL {
        directory().appendingPathComponent("\(key).json", isDirectory: false)
    }

    static func load(key: String) -> DownloadResumptionState? {
        let url = metadataFileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DownloadResumptionState.self, from: data)
    }

    static func save(_ state: DownloadResumptionState, key: String) {
        let directoryURL = directory()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: metadataFileURL(for: key), options: .atomic)
    }

    static func remove(key: String) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: metadataFileURL(for: key))
        try? fileManager.removeItem(at: partFileURL(for: key))
    }

    /// Deletes parts whose metadata has not been touched within the retention window.
    static func cleanup(olderThan interval: TimeInterval = retentionInterval) {
        let directoryURL = directory()
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
        ) else { return }

        let cutoff = Date().addingTimeInterval(-interval)
        for entry in entries where entry.pathExtension == "json" {
            let modificationDate = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let modificationDate, modificationDate < cutoff else { continue }
            let key = entry.deletingPathExtension().lastPathComponent
            remove(key: key)
        }
    }

    private static func directory() -> URL {
        AppPaths.chunkedDownloadDirectory
    }
}
