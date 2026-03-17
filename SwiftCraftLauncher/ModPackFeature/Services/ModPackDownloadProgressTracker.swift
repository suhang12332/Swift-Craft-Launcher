import Foundation

// MARK: - Download Progress Tracker
final class ModPackDownloadProgressTracker: NSObject, URLSessionDownloadDelegate {
    private let progressCallback: (Int64, Int64) -> Void
    private let totalFileSize: Int64
    var completionHandler: ((Result<URL, Error>) -> Void)?

    init(totalSize: Int64, progressCallback: @escaping (Int64, Int64) -> Void) {
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
        if actualTotalSize > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback(totalBytesWritten, actualTotalSize)
            }
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

