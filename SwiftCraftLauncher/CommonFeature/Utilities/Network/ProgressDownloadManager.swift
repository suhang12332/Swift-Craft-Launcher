//
//  ProgressDownloadManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Manages file downloads with progress tracking, retry logic, and SHA1 validation.
enum ProgressDownloadManager {
    private static let maxRetryCount = 3

    static func cleanup() {
        ProgressDownloadSession.shared.finishTasksAndInvalidate()
    }

    /// Downloads a file from a remote URL to a local destination.
    ///
    /// The URL is expanded into an ordered list of candidate sources (official
    /// plus mirror) according to the user's download source preference, and each
    /// candidate is tried in turn until one succeeds.
    /// - Parameters:
    ///   - urlString: The remote file URL string.
    ///   - destinationURL: The local file URL to write to.
    ///   - expectedSha1: An optional SHA1 hash for integrity validation.
    ///   - progressHandler: An optional closure invoked with (bytesWritten, totalBytes) on progress updates.
    /// - Returns: The local file URL after a successful download.
    /// - Throws: An error if every candidate source fails.
    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
        allowsChunking: Bool = false,
    ) async throws -> URL {
        let url = try FileDownloadCore.parseURL(from: urlString)
        let preference = DIContainer.shared.ui.gameSettingsManager.downloadSourcePreference
        let candidates = await DownloadSourceResolver.shared.candidateURLs(for: url, preference: preference)
        return try await downloadFile(
            candidateURLs: candidates,
            destinationURL: destinationURL,
            expectedSha1: expectedSha1,
            headers: headers,
            progressHandler: progressHandler,
            allowsChunking: allowsChunking,
        )
    }

    /// Downloads a file from the first candidate source that succeeds.
    /// - Parameter candidateURLs: The sources to try, best first.
    /// - Returns: The local file URL after a successful download.
    /// - Throws: The error raised by the last source when all of them fail.
    static func downloadFile(
        candidateURLs: [URL],
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
        allowsChunking: Bool = false,
    ) async throws -> URL {
        var lastError: Error?

        for (index, candidate) in candidateURLs.enumerated() {
            do {
                let result = try await downloadFromSingleSource(
                    sources: Array(candidateURLs[index...]),
                    destinationURL: destinationURL,
                    expectedSha1: expectedSha1,
                    headers: headers,
                    progressHandler: progressHandler,
                    allowsChunking: allowsChunking,
                )
                await DownloadSourceResolver.shared.recordSuccess(host: candidate.host)
                return result
            } catch {
                if error is CancellationError {
                    throw error
                }
                let kind = DownloadSourceFailure.classify(error)
                await DownloadSourceResolver.shared.recordFailure(host: candidate.host, failure: kind)
                lastError = error
                guard index < candidateURLs.count - 1 else { break }
                AppLog.common.info("Download from \(candidate.host ?? "?") failed, trying the next source")
            }
        }

        throw lastError ?? GlobalError.download(
            i18nKey: "error.download.general_failure",
            level: .notification,
            message: "No download source available for \(destinationURL.lastPathComponent)",
        )
    }

    /// Downloads a file from one specific source, retrying transient failures.
    ///
    /// - Parameter sources: The source to use first, followed by any remaining
    ///   sources. The chunked path probes all of them because a mirror may not
    ///   honour range requests even when the official host does.
    private static func downloadFromSingleSource(
        sources: [URL],
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
        allowsChunking: Bool = false,
    ) async throws -> URL {
        guard let url = sources.first else {
            throw GlobalError.download(
                i18nKey: "error.download.general_failure",
                level: .notification,
                message: "No download source supplied for \(destinationURL.lastPathComponent)",
            )
        }

        if allowsChunking {
            do {
                return try await ChunkedDownloader.download(
                    candidateURLs: sources,
                    destinationURL: destinationURL,
                    expectedSha1: expectedSha1,
                    headers: headers,
                    progressHandler: progressHandler,
                )
            } catch let ChunkedDownloadError.notSupported(reason) {
                AppLog.common.info("Chunked download unavailable, falling back to single stream: \(reason)")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Chunking is an optimisation, so anything that goes wrong in it
                // degrades to the plain single-stream path instead of failing the
                // download. Servers that advertise range support in a HEAD but
                // refuse `Range` on a GET land here, and the plain GET still works.
                AppLog.common.info("Chunked download failed, falling back to single stream: \(error)")
            }
        }

        try Task.checkCancellation()
        let fileManager = FileManager.default

        try FileDownloadCore.ensureParentDirectory(for: destinationURL, fileManager: fileManager)

        if let existingFileSize = await FileDownloadCore.existingFileSizeIfReusable(
            at: destinationURL,
            expectedSha1: expectedSha1,
            fileManager: fileManager,
        ) {
            progressHandler?(existingFileSize, existingFileSize)
            return destinationURL
        }

        let fileSize: Int64
        if let progressHandler {
            fileSize = try await getRemoteFileSize(from: url, headers: headers)
            progressHandler(0, fileSize)
        } else {
            fileSize = 0
        }

        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                let budget = DownloadBudget.shared
                await budget.syncLimit(DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)
                await budget.acquire(1)
                let tempURL: URL
                do {
                    tempURL = try await ProgressDownloadSession.shared.download(
                        from: url,
                        totalSize: fileSize,
                        headers: headers,
                        progressHandler: progressHandler,
                    )
                } catch {
                    await budget.release(1)
                    throw error
                }
                await budget.release(1)
                defer { try? fileManager.removeItem(at: tempURL) }

                try await FileDownloadCore.validateSHA1IfNeeded(for: tempURL, expectedSha1: expectedSha1)
                try FileDownloadCore.moveDownloadedFile(from: tempURL, to: destinationURL, fileManager: fileManager)
                return destinationURL
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    throw CancellationError()
                }
                guard attempt < maxRetryCount, shouldRetry(error) else {
                    throw mapDownloadError(error)
                }
                attempt += 1
                try await Task.sleep(nanoseconds: retryDelayNanoseconds(for: attempt))
            }
        }
    }

    private static func getRemoteFileSize(from url: URL, headers: [String: String]? = nil) async throws -> Int64 {
        let (_, httpResponse) = try await ProgressDownloadSession.shared.head(url: url, headers: headers)

        guard httpResponse.statusCode == 200,
              let contentLength = httpResponse.value(forHTTPHeaderField: APIClient.Header.contentLength),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.download(
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification,
                message: "HEAD to \(url.absoluteString) returned status \(httpResponse.statusCode), Content-Length: \(httpResponse.value(forHTTPHeaderField: APIClient.Header.contentLength) ?? "nil")",
            )
        }
        return fileSize
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }

        if case let ProgressDownloadError.httpStatus(statusCode) = error {
            return statusCode == 408 || statusCode == 429 || (500 ... 599).contains(statusCode)
        }

        return false
    }

    private static func retryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let seconds = min(pow(2.0, Double(attempt - 1)) * 0.5, 4.0)
        return UInt64(seconds * 1_000_000_000)
    }

    private static func mapDownloadError(_ error: Error) -> Error {
        if error is CancellationError {
            return error
        }
        if let globalError = error as? GlobalError {
            return globalError
        }
        if case let ProgressDownloadError.httpStatus(statusCode) = error {
            return GlobalError.download(
                i18nKey: "error.download.http_status_error",
                level: .notification,
                statusCode: statusCode,
                message: "HTTP \(statusCode) from single-stream download",
            )
        }
        if error is URLError {
            return GlobalError.download(
                i18nKey: "error.download.network_request_failed",
                level: .notification,
                message: "Network error: \((error as NSError).domain) code \((error as NSError).code)",
            )
        }
        return GlobalError.download(
            i18nKey: "error.download.general_failure",
            level: .notification,
            message: "Unexpected download error: \(error.localizedDescription)",
        )
    }
}

private enum ProgressDownloadError: Error {
    case httpStatus(Int)
}

/// `@unchecked Sendable`: a `URLSessionDownloadDelegate`; all mutable state is guarded
/// by `OSAllocatedUnfairLock` (`lock`, `sessionState`).
private final class ProgressDownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = ProgressDownloadSession()

    private let lock = OSAllocatedUnfairLock<[ObjectIdentifier: ProgressDownloadTracker]>(initialState: [:])
    private let sessionState = OSAllocatedUnfairLock<SessionCache>(initialState: SessionCache())

    private struct SessionCache {
        var session: URLSession?
        var connectionsPerHost: Int = 0
        /// Sessions retired after a setting change; kept alive until their in-flight tasks finish.
        var retiring: [URLSession] = []
    }

    /// The active session, recreated when the concurrent download setting changes
    /// because the per-host connection limit is fixed at session creation time.
    /// The previous session is retired with `finishTasksAndInvalidate()` so in-flight
    /// downloads complete instead of being cancelled by session deallocation.
    private var session: URLSession {
        let connectionsPerHost = max(1, DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)
        let (session, retiredSession) = sessionState.withLock { cache -> (URLSession, URLSession?) in
            if let cachedSession = cache.session, cache.connectionsPerHost == connectionsPerHost {
                return (cachedSession, nil)
            }
            let newSession = NetworkSession.makeSession(delegate: self)
            let previousSession = cache.session
            if let previousSession {
                cache.retiring.append(previousSession)
            }
            cache.session = newSession
            cache.connectionsPerHost = connectionsPerHost
            return (newSession, previousSession)
        }
        retiredSession?.finishTasksAndInvalidate()
        return session
    }

    func download(
        from url: URL,
        totalSize: Int64,
        headers: [String: String]? = nil,
        progressHandler: ((Int64, Int64) -> Void)?,
    ) async throws -> URL {
        let tracker = ProgressDownloadTracker(totalSize: totalSize, progressCallback: progressHandler)
        let context = ProgressDownloadTaskContext()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                tracker.setContinuation(continuation)

                let request = URLRequest(url: url).headers(headers)
                let task = self.session.downloadTask(with: request)
                self.set(tracker: tracker, for: task)
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

    func head(url: URL, headers: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        let request = URLRequest(url: url)
            .method(APIClient.HTTPMethods.head)
            .headers(headers)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_response",
                level: .notification,
                message: "HEAD request to \(url.absoluteString) returned non-HTTP response: \(type(of: response))",
            )
        }
        return (data, httpResponse)
    }

    func invalidateAndCancel() {
        cancelPendingHandlers()
        takeAndClearSession()?.invalidateAndCancel()
    }

    func finishTasksAndInvalidate() {
        cancelPendingHandlers()
        takeAndClearSession()?.finishTasksAndInvalidate()
    }

    private func takeAndClearSession() -> URLSession? {
        sessionState.withLock { cache in
            defer { cache.session = nil }
            return cache.session
        }
    }

    private func cancelPendingHandlers() {
        let pendingHandlers = lock.withLock { handlers in
            let snapshot = handlers
            handlers.removeAll()
            return snapshot
        }

        for (_, tracker) in pendingHandlers {
            tracker.complete(.failure(CancellationError()))
        }
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64,
    ) {
        tracker(for: downloadTask)?.reportProgress(
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite,
        )
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL,
    ) {
        guard let tracker = tracker(for: downloadTask) else { return }
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            tracker.complete(.failure(ProgressDownloadError.httpStatus(httpResponse.statusCode)))
            removeTracker(for: downloadTask)
            return
        }

        do {
            let stableTempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: stableTempURL)
            tracker.complete(.success(stableTempURL))
        } catch {
            tracker.complete(.failure(error))
        }
        removeTracker(for: downloadTask)
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?,
    ) {
        guard let error else {
            removeTracker(for: task)
            return
        }

        tracker(for: task)?.complete(.failure(error))
        removeTracker(for: task)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError _: Error?) {
        sessionState.withLock { cache in
            cache.retiring.removeAll { $0 === session }
        }
    }

    private func set(tracker: ProgressDownloadTracker, for task: URLSessionTask) {
        lock.withLock { $0[ObjectIdentifier(task)] = tracker }
    }

    private func tracker(for task: URLSessionTask) -> ProgressDownloadTracker? {
        lock.withLock { $0[ObjectIdentifier(task)] }
    }

    private func removeTracker(for task: URLSessionTask) {
        lock.withLock { $0[ObjectIdentifier(task)] = nil }
    }
}

/// `@unchecked Sendable`: all mutable state is guarded by `OSAllocatedUnfairLock` (`state`).
private final class ProgressDownloadTracker: @unchecked Sendable {
    private let totalFileSize: Int64
    private let progressCallback: ((Int64, Int64) -> Void)?
    private let state = OSAllocatedUnfairLock<(isCompleted: Bool, continuation: CheckedContinuation<URL, Error>?)>(initialState: (false, nil))

    init(totalSize: Int64, progressCallback: ((Int64, Int64) -> Void)?) {
        totalFileSize = totalSize
        self.progressCallback = progressCallback
    }

    func reportProgress(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let actualTotalSize = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalFileSize
        guard actualTotalSize > 0 else { return }
        Task { @MainActor [weak self] in
            self?.progressCallback?(totalBytesWritten, actualTotalSize)
        }
    }

    func complete(_ result: Result<URL, Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<URL, Error>? in
            guard !state.isCompleted else { return nil }
            state.isCompleted = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        switch result {
        case let .success(url):
            continuation?.resume(returning: url)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }

    func setContinuation(_ continuation: CheckedContinuation<URL, Error>) {
        state.withLock { $0.continuation = continuation }
    }
}

/// `@unchecked Sendable`: the download task is guarded by `OSAllocatedUnfairLock` (`lock`).
private final class ProgressDownloadTaskContext: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<URLSessionDownloadTask?>(initialState: nil)

    func set(task: URLSessionDownloadTask) {
        lock.withLock { $0 = task }
    }

    func cancel() {
        lock.withLock { $0 }?.cancel()
    }
}
