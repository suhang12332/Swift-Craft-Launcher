import Foundation

enum ProgressDownloadManager {
    private static let githubPrefix = "https://github.com/"
    private static let rawGithubPrefix = "https://raw.githubusercontent.com/"
    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) async throws -> URL {
        try Task.checkCancellation()
        let url: URL = try autoreleasepool {
            guard let url = URL(string: urlString) else {
                throw GlobalError.validation(
                    chineseMessage: "无效的下载地址",
                    i18nKey: "error.validation.invalid_download_url",
                    level: .notification
                )
            }
            return url
        }

        let finalURL: URL = autoreleasepool {
            let needsProxy: Bool
            if let host = url.host {
                needsProxy = host == Self.githubHost || host == Self.rawGithubHost
            } else {
                let absoluteString = url.absoluteString
                needsProxy = absoluteString.hasPrefix(Self.githubPrefix) || absoluteString.hasPrefix(Self.rawGithubPrefix)
            }
            return needsProxy ? URLConfig.applyGitProxyIfNeeded(url) : url
        }

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "创建目标目录失败",
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification
            )
        }

        let shouldCheckSha1 = (expectedSha1?.isEmpty == false)
        if fileManager.fileExists(atPath: destinationURL.path) {
            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                do {
                    let actualSha1 = try autoreleasepool {
                        try DownloadManager.calculateFileSHA1(at: destinationURL)
                    }
                    if actualSha1 == expectedSha1 {
                        if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                           let fileSize = attributes[.size] as? Int64 {
                            progressHandler?(fileSize, fileSize)
                        }
                        return destinationURL
                    }
                } catch {
                    // SHA1 读取失败时继续重新下载
                }
            } else {
                if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    progressHandler?(fileSize, fileSize)
                }
                return destinationURL
            }
        }

        let fileSize = try await getRemoteFileSize(from: finalURL)
        progressHandler?(0, fileSize)

        let tracker = ProgressDownloadTracker(totalSize: fileSize, progressCallback: progressHandler)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        let context = ProgressDownloadTaskContext()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                tracker.completionHandler = { result in
                    switch result {
                    case .success(let tempURL):
                        defer { try? fileManager.removeItem(at: tempURL) }
                        do {
                            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                                let actualSha1 = try DownloadManager.calculateFileSHA1(at: tempURL)
                                if actualSha1 != expectedSha1 {
                                    throw GlobalError.validation(
                                        chineseMessage: "SHA1 校验失败",
                                        i18nKey: "error.validation.sha1_check_failed",
                                        level: .notification
                                    )
                                }
                            }

                            if fileManager.fileExists(atPath: destinationURL.path) {
                                try fileManager.replaceItem(
                                    at: destinationURL,
                                    withItemAt: tempURL,
                                    backupItemName: nil,
                                    options: [],
                                    resultingItemURL: nil
                                )
                            } else {
                                try fileManager.moveItem(at: tempURL, to: destinationURL)
                            }
                            continuation.resume(returning: destinationURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        if let urlError = error as? URLError, urlError.code == .cancelled {
                            continuation.resume(throwing: CancellationError())
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                let task = session.downloadTask(with: finalURL)
                context.set(task: task)
                if Task.isCancelled {
                    task.cancel()
                } else {
                    task.resume()
                }
            }
        }, onCancel: {
            context.cancel()
        })
    }

    private static func getRemoteFileSize(from url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        guard httpResponse.statusCode == 200,
              let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小",
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification
            )
        }
        return fileSize
    }
}

private final class ProgressDownloadTracker: NSObject, URLSessionDownloadDelegate {
    private let totalFileSize: Int64
    private let progressCallback: ((Int64, Int64) -> Void)?
    var completionHandler: ((Result<URL, Error>) -> Void)?

    init(totalSize: Int64, progressCallback: ((Int64, Int64) -> Void)?) {
        self.totalFileSize = totalSize
        self.progressCallback = progressCallback
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let actualTotalSize = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalFileSize
        guard actualTotalSize > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(totalBytesWritten, actualTotalSize)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        completionHandler?(.success(location))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            completionHandler?(.failure(error))
        }
    }
}

private final class ProgressDownloadTaskContext: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?

    func set(task: URLSessionDownloadTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let currentTask = task
        lock.unlock()
        currentTask?.cancel()
    }
}
