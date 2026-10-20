//
//  ChunkedDownloader.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Failures raised by the chunked download path.
enum ChunkedDownloadError: Error {
    /// The server or file is not suitable for chunking; the caller should fall back to a single stream.
    case notSupported(reason: String)
    /// A chunk finished with fewer bytes than its range declared.
    case incompleteChunk(index: Int, expected: Int64, actual: Int64)
}

/// Everything one chunk needs to run, grouped so the retry helper stays within
/// the project's six-parameter limit.
private struct ChunkDownloadContext: Sendable {
    let chunk: DownloadChunk
    let url: URL
    let headers: [String: String]?
    let partURL: URL
    let aggregator: ChunkProgressAggregator
    let recorder: ChunkResumptionRecorder
    let cursor: ChunkWriteCursor
}

/// Downloads one large file with several concurrent HTTP Range requests.
///
/// Each chunk writes into a pre-allocated temporary file through its own file
/// descriptor, so no merge pass is needed: the assembled file is ready as soon
/// as the last chunk completes.
enum ChunkedDownloader {
    static func download(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
    ) async throws -> URL {
        try Task.checkCancellation()

        let url = try FileDownloadCore.parseURL(from: urlString)
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

        let info = try await RemoteFileProbe.probe(url: url, headers: headers)
        guard info.acceptsRanges, info.contentLength >= ChunkedDownloadConfig.minimumFileSize else {
            throw ChunkedDownloadError.notSupported(
                reason: "acceptsRanges=\(info.acceptsRanges), size=\(info.contentLength)",
            )
        }

        guard DIContainer.shared.ui.gameSettingsManager.enableChunkedDownloads else {
            throw ChunkedDownloadError.notSupported(reason: "chunked downloads are disabled in settings")
        }

        guard !ChunkedDownloadTelemetry.isChunkingDisabled(forHost: url.host) else {
            throw ChunkedDownloadError.notSupported(reason: "chunking previously measured ineffective for \(url.host ?? "?")")
        }

        let budget = DownloadBudget.shared
        await budget.syncLimit(DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)
        let limit = await budget.currentLimit()

        let chunks = ChunkPlan.make(
            fileSize: info.contentLength,
            maxChunks: min(ChunkedDownloadConfig.maxChunksPerFile, limit),
        )
        guard !chunks.isEmpty else {
            throw ChunkedDownloadError.notSupported(reason: "empty chunk plan for size \(info.contentLength)")
        }

        try ensureFreeSpace(for: info.contentLength, at: destinationURL)

        let key = resumptionKey(for: urlString)
        let partURL = DownloadResumptionStore.partFileURL(for: key)
        let resumed = preparePartFile(
            at: partURL,
            key: key,
            fileSize: info.contentLength,
            info: info,
            chunkCount: chunks.count,
            fileManager: fileManager,
        )

        let aggregator = ChunkProgressAggregator(
            totalSize: info.contentLength,
            progressHandler: progressHandler,
        )
        let recorder = ChunkResumptionRecorder(
            key: key,
            url: urlString,
            info: info,
            chunkCount: chunks.count,
            initial: resumed,
        )

        let clock = ContinuousClock()
        let startedAt = clock.now

        let cursors: [Int: ChunkWriteCursor] = Dictionary(uniqueKeysWithValues: chunks.map { chunk in
            (chunk.index, ChunkWriteCursor(initial: resumed[chunk.index] ?? 0))
        })

        // Periodic saves mean a crash or force-quit loses at most one second of
        // progress rather than everything downloaded so far.
        let persistence = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                for (index, cursor) in cursors {
                    await recorder.set(chunk: index, written: cursor.written)
                }
            }
        }
        defer { persistence.cancel() }

        await budget.acquire(chunks.count)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for chunk in chunks {
                    let context = ChunkDownloadContext(
                        chunk: chunk,
                        url: url,
                        headers: headers,
                        partURL: partURL,
                        aggregator: aggregator,
                        recorder: recorder,
                        cursor: cursors[chunk.index] ?? ChunkWriteCursor(),
                    )
                    group.addTask {
                        try await downloadChunkWithRetry(context)
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            await budget.release(chunks.count)
            throw error
        }
        await budget.release(chunks.count)

        await aggregator.flush()

        do {
            try await FileDownloadCore.validateSHA1IfNeeded(for: partURL, expectedSha1: expectedSha1)
        } catch {
            try? fileManager.removeItem(at: partURL)
            await recorder.clear()
            throw error
        }

        try FileDownloadCore.moveDownloadedFile(from: partURL, to: destinationURL, fileManager: fileManager)
        await recorder.clear()

        recordThroughput(bytes: info.contentLength, startedAt: startedAt, clock: clock, chunkCount: chunks.count, host: url.host)
        return destinationURL
    }

    /// Creates the part file if needed and returns any resumable per-chunk progress.
    private static func preparePartFile(
        at partURL: URL,
        key: String,
        fileSize: Int64,
        info: RemoteFileInfo,
        chunkCount: Int,
        fileManager: FileManager,
    ) -> [Int: Int64] {
        let stored = DownloadResumptionStore.load(key: key)
        try? fileManager.createDirectory(
            at: partURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )

        let existingSize = (try? fileManager.attributesOfItem(atPath: partURL.path)[.size] as? Int64) ?? -1
        let canReuse = stored?.matches(etag: info.etag, fileSize: fileSize, chunkCount: chunkCount) ?? false
        guard canReuse, existingSize == fileSize, let state = stored else {
            try? fileManager.removeItem(at: partURL)
            DownloadResumptionStore.remove(key: key)
            try? allocateSparseFile(at: partURL, size: fileSize, fileManager: fileManager)
            return [:]
        }

        // Drop any recorded progress that exceeds its chunk, otherwise the chunk
        // would be treated as already complete with the wrong byte count.
        let lengths = ChunkPlan.make(fileSize: fileSize, maxChunks: chunkCount)
        var progress: [Int: Int64] = [:]
        for chunk in lengths {
            let written = state.chunks[chunk.index] ?? 0
            if written > 0, written < chunk.length {
                progress[chunk.index] = written
            }
        }
        if progress.isEmpty {
            DownloadResumptionStore.remove(key: key)
        }
        return progress
    }

    private static func resumptionKey(for urlString: String) -> String {
        SHA1Calculator.sha1(of: Data(urlString.utf8))
    }

    private static func ensureFreeSpace(for size: Int64, at destinationURL: URL) throws {
        let values = try? destinationURL.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return }
        guard available >= size else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.insufficient_disk_space",
                level: .notification,
                message: "Need \(size) bytes for a chunked download, only \(available) available at \(destinationURL.path)",
            )
        }
    }

    private static func recordThroughput(
        bytes: Int64,
        startedAt: ContinuousClock.Instant,
        clock: ContinuousClock,
        chunkCount: Int,
        host: String?,
    ) {
        guard chunkCount > 1 else { return }
        let elapsed = startedAt.duration(to: clock.now)
        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        guard seconds > 0 else { return }
        let bytesPerSecond = Double(bytes) / seconds
        if bytesPerSecond < Double(ChunkedDownloadConfig.minimumEffectiveBytesPerSecond) {
            AppLog.common.info("Chunked download averaged \(Int(bytesPerSecond)) B/s from \(host ?? "?"); disabling chunking for this host")
            ChunkedDownloadTelemetry.markIneffective(host: host)
        }
    }

    private static func downloadChunkWithRetry(_ context: ChunkDownloadContext) async throws {
        let chunk = context.chunk
        let cursor = context.cursor
        var attempt = 0

        while true {
            try Task.checkCancellation()

            do {
                try await ChunkedDownloadSession.shared.download(
                    chunk: chunk,
                    from: context.url,
                    headers: context.headers,
                    partURL: context.partURL,
                    cursor: cursor,
                    aggregator: context.aggregator,
                )
                await context.recorder.set(chunk: chunk.index, written: chunk.length)
                return
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    // Keep whatever landed on disk so the next run can resume.
                    await context.recorder.set(chunk: chunk.index, written: cursor.written)
                    throw CancellationError()
                }
                if case ChunkedDownloadError.notSupported = error {
                    throw error
                }
                guard attempt < DownloadRetryPolicy.maxRetryCount,
                      DownloadRetryPolicy.shouldRetry(error) else {
                    await context.recorder.set(chunk: chunk.index, written: cursor.written)
                    throw mapChunkError(error)
                }
                attempt += 1
                try await Task.sleep(nanoseconds: DownloadRetryPolicy.delayNanoseconds(for: attempt))
            }
        }
    }

    private static func allocateSparseFile(
        at url: URL,
        size: Int64,
        fileManager: FileManager,
    ) throws {
        guard fileManager.createFile(atPath: url.path, contents: nil),
              let handle = FileHandle(forWritingAtPath: url.path) else {
            throw GlobalError.download(
                i18nKey: "error.download.general_failure",
                level: .notification,
                message: "Cannot create chunked download part file at \(url.path)",
            )
        }
        defer { try? handle.close() }

        handle.truncateFile(atOffset: UInt64(size))
    }

    private static func mapChunkError(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if error is GlobalError { return error }
        if case let ChunkedDownloadError.incompleteChunk(index, expected, actual) = error {
            return GlobalError.download(
                i18nKey: "error.download.general_failure",
                level: .notification,
                message: "Chunk \(index) incomplete: expected \(expected) bytes, got \(actual)",
            )
        }
        if case let DownloadHTTPStatusError.httpStatus(statusCode) = error {
            return GlobalError.download(
                i18nKey: "error.download.http_status_error",
                level: .notification,
                message: "HTTP \(statusCode) from chunked download",
            )
        }
        if error is URLError {
            return GlobalError.download(
                i18nKey: "error.download.network_request_failed",
                level: .notification,
                message: "Network error during chunked download: \((error as NSError).domain) code \((error as NSError).code)",
            )
        }
        return GlobalError.download(
            i18nKey: "error.download.general_failure",
            level: .notification,
            message: "Unexpected chunked download error: \(error.localizedDescription)",
        )
    }
}

/// Tracks how many bytes of a chunk have already landed on disk, across retries.
private final class ChunkWriteCursor: @unchecked Sendable {
    private let lock: OSAllocatedUnfairLock<Int64>

    init(initial: Int64 = 0) {
        lock = OSAllocatedUnfairLock<Int64>(initialState: initial)
    }

    func advance(_ delta: Int64) {
        lock.withLock { $0 += delta }
    }

    var written: Int64 {
        lock.withLock { $0 }
    }
}

/// Keeps the on-disk resumption record in sync with chunk progress.
private actor ChunkResumptionRecorder {
    private var state: DownloadResumptionState
    private let key: String
    private var isFinished = false

    init(
        key: String,
        url: String,
        info: RemoteFileInfo,
        chunkCount: Int,
        initial: [Int: Int64],
    ) {
        self.key = key
        state = DownloadResumptionState(
            url: url,
            etag: info.etag,
            lastModified: info.lastModified,
            fileSize: info.contentLength,
            chunkCount: chunkCount,
            chunks: initial,
            updatedAt: Date(),
        )
    }

    func set(chunk index: Int, written: Int64) {
        // Periodic saves can race with completion; once finished, the record is gone for good.
        guard !isFinished else { return }
        state.chunks[index] = written
        state.updatedAt = Date()
        DownloadResumptionStore.save(state, key: key)
    }

    func clear() {
        isFinished = true
        DownloadResumptionStore.remove(key: key)
    }
}

/// Runs concurrent `Range` requests on a single `URLSession`.
private final class ChunkedDownloadSession: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let shared = ChunkedDownloadSession()

    private let lock = OSAllocatedUnfairLock<[Int: ChunkDownloadTracker]>(initialState: [:])
    private let sessionState = OSAllocatedUnfairLock<URLSession?>(initialState: nil)
    /// Set once a chunk discovers the server ignores `Range`, so the remaining
    /// chunks stop before each of them pulls a full copy of the file.
    private let aborted = OSAllocatedUnfairLock<Bool>(initialState: false)

    /// Created on first use: the delegate (`self`) only exists after `init`.
    private var session: URLSession {
        sessionState.withLock { cached in
            if let cached { return cached }
            let created = NetworkSession.makeSession(delegate: self)
            cached = created
            return created
        }
    }

    func download(
        chunk: DownloadChunk,
        from url: URL,
        headers: [String: String]?,
        partURL: URL,
        cursor: ChunkWriteCursor,
        aggregator: ChunkProgressAggregator,
    ) async throws {
        let resumeOffset = cursor.written
        if resumeOffset >= chunk.length {
            await aggregator.report(chunk: chunk.index, totalWritten: chunk.length)
            return
        }

        if isAborted {
            throw ChunkedDownloadError.notSupported(reason: "another chunk found the server ignores Range requests")
        }

        guard let handle = FileHandle(forWritingAtPath: partURL.path) else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification,
                message: "Cannot open \(partURL.path) for chunk \(chunk.index)",
            )
        }

        let startOffset = chunk.lowerBound + resumeOffset

        do {
            try handle.seek(toOffset: UInt64(startOffset))
        } catch {
            try? handle.close()
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification,
                message: "Cannot seek to \(startOffset) in \(partURL.path) for chunk \(chunk.index): \(error.localizedDescription)",
            )
        }

        let tracker = ChunkDownloadTracker(
            chunk: chunk,
            fileHandle: handle,
            cursor: cursor,
            aggregator: aggregator,
        )
        let context = ChunkedTaskContext()

        do {
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    tracker.setContinuation(continuation)

                    var request = URLRequest(url: url).headers(headers)
                    request.setValue("bytes=\(startOffset)-\(chunk.upperBound)", forHTTPHeaderField: "Range")

                    let task = self.session.dataTask(with: request)
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
        } catch {
            tracker.closeHandle()
            throw error
        }
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void,
    ) {
        guard let tracker = tracker(for: dataTask) else {
            completionHandler(.cancel)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                markAborted()
                fail(tracker, for: dataTask, with: ChunkedDownloadError.notSupported(
                    reason: "server returned 200 for a Range request",
                ))
                completionHandler(.cancel)
                return
            }
            guard httpResponse.statusCode == 206 else {
                fail(tracker, for: dataTask, with: DownloadHTTPStatusError.httpStatus(httpResponse.statusCode))
                completionHandler(.cancel)
                return
            }
        }

        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let tracker = tracker(for: dataTask) else { return }
        do {
            try tracker.append(data)
        } catch {
            fail(tracker, for: dataTask, with: error)
            dataTask.cancel()
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let tracker = tracker(for: task) else { return }
        if let error {
            fail(tracker, for: task, with: error)
            return
        }
        tracker.finish()
        removeTracker(for: task)
    }

    private func fail(_ tracker: ChunkDownloadTracker, for task: URLSessionTask, with error: Error) {
        tracker.complete(.failure(error))
        removeTracker(for: task)
    }

    private var isAborted: Bool {
        aborted.withLock { $0 }
    }

    private func markAborted() {
        aborted.withLock { $0 = true }
    }

    private func set(tracker: ChunkDownloadTracker, for task: URLSessionTask) {
        lock.withLock { $0[task.taskIdentifier] = tracker }
    }

    private func tracker(for task: URLSessionTask) -> ChunkDownloadTracker? {
        lock.withLock { $0[task.taskIdentifier] }
    }

    private func removeTracker(for task: URLSessionTask) {
        lock.withLock { $0[task.taskIdentifier] = nil }
    }
}

/// Owns one chunk's file handle, continuation and progress bookkeeping.
private final class ChunkDownloadTracker: @unchecked Sendable {
    private struct State {
        var isCompleted = false
        var continuation: CheckedContinuation<Void, Error>?
        var lastReported: Int64 = 0
    }

    private let chunk: DownloadChunk
    private let fileHandle: FileHandle
    private let cursor: ChunkWriteCursor
    private let aggregator: ChunkProgressAggregator
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    init(
        chunk: DownloadChunk,
        fileHandle: FileHandle,
        cursor: ChunkWriteCursor,
        aggregator: ChunkProgressAggregator,
    ) {
        self.chunk = chunk
        self.fileHandle = fileHandle
        self.cursor = cursor
        self.aggregator = aggregator
    }

    func setContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        state.withLock { state in
            if state.isCompleted {
                continuation.resume()
            } else {
                state.continuation = continuation
            }
        }
    }

    func append(_ data: Data) throws {
        try fileHandle.write(contentsOf: data)
        let delta = Int64(data.count)
        cursor.advance(delta)

        let shouldReport = state.withLock { state -> Bool in
            state.lastReported += delta
            guard state.lastReported >= ChunkedDownloadConfig.progressReportThreshold else { return false }
            state.lastReported = 0
            return true
        }
        guard shouldReport else { return }

        let written = cursor.written
        let index = chunk.index
        Task { await aggregator.report(chunk: index, totalWritten: written) }
    }

    func finish() {
        let written = cursor.written
        let index = chunk.index
        Task { await aggregator.report(chunk: index, totalWritten: written) }

        if written != chunk.length {
            complete(.failure(ChunkedDownloadError.incompleteChunk(
                index: chunk.index,
                expected: chunk.length,
                actual: written,
            )))
            return
        }
        complete(.success(()))
    }

    func complete(_ result: Result<Void, Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<Void, Error>? in
            guard !state.isCompleted else { return nil }
            state.isCompleted = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        closeHandle()
        switch result {
        case .success:
            continuation?.resume()
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }

    func closeHandle() {
        try? fileHandle.synchronize()
        try? fileHandle.close()
    }
}

/// Holds the in-flight task so cancellation can reach it.
private final class ChunkedTaskContext: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<URLSessionDataTask?>(initialState: nil)

    func set(task: URLSessionDataTask) {
        lock.withLock { $0 = task }
    }

    func cancel() {
        lock.withLock { $0 }?.cancel()
    }
}
