import Foundation

enum ProgressDownloadManager {
    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) async throws -> URL {
        try Task.checkCancellation()
        let url = try FileDownloadCore.parseURL(from: urlString)
        let finalURL = FileDownloadCore.normalizedDownloadURL(from: url)

        let fileManager = FileManager.default

        try FileDownloadCore.ensureParentDirectory(for: destinationURL, fileManager: fileManager)

        if let existingFileSize = FileDownloadCore.existingFileSizeIfReusable(
            at: destinationURL,
            expectedSha1: expectedSha1,
            fileManager: fileManager
        ) {
            progressHandler?(existingFileSize, existingFileSize)
            return destinationURL
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
                            try FileDownloadCore.validateSHA1IfNeeded(for: tempURL, expectedSha1: expectedSha1)
                            try FileDownloadCore.moveDownloadedFile(from: tempURL, to: destinationURL, fileManager: fileManager)
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
