import Foundation

struct JarDownloadTask {
    let name: String         // 用于进度回调显示
    let url: URL
    let destinationPath: String // 相对于 metaLibrariesDir 的路径
    let expectedSha1: String?
}

enum BatchJarDownloader {
    static func download(
        tasks: [JarDownloadTask],
        metaLibrariesDir: URL,
        onProgressUpdate: ((String, Int, Int) -> Void)? = nil
    ) async throws {
        let total = tasks.count
        let counter = Counter()

        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(value: GeneralSettingsManager.shared.concurrentDownloads)

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
                        expectedSha1: task.expectedSha1
                    )
                    let completed = await counter.increment()
                    await MainActor.run {
                        onProgressUpdate?(task.name, completed, total)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    actor Counter {
        private var value = 0

        func increment() -> Int {
            value += 1
            return value
        }
    }
}
