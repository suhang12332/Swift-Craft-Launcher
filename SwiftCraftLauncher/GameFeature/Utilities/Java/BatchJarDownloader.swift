//
//  BatchJarDownloader.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A task representing a single JAR file download.
struct JarDownloadTask {
    let name: String
    let url: URL
    let destinationPath: String
    let expectedSha1: String?
}

/// Downloads multiple JAR files concurrently with controlled parallelism.
enum BatchJarDownloader {
    static func download(
        tasks: [JarDownloadTask],
        metaLibrariesDir: URL,
        onProgressUpdate: (@MainActor @Sendable (String, Int, Int) -> Void)? = nil,
    ) async throws {
        let total = tasks.count
        let counter = AtomicCounter()

        let semaphore = AsyncSemaphore(value: DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    let fileManager = FileManager.default
                    let destinationURL = metaLibrariesDir.appendingPathComponent(task.destinationPath)
                    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    _ = try await DownloadManager.downloadFile(
                        urlString: task.url.absoluteString,
                        destinationURL: destinationURL,
                        expectedSha1: task.expectedSha1,
                    )
                    let completed = await counter.increment()
                    await onProgressUpdate?(task.name, completed, total)
                }
            }
            try await group.waitForAll()
        }
    }
}
