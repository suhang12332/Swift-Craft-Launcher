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

private actor ServingHostRecorder {
    private(set) var value: String?

    func set(_ host: String) { value = host }
}

/// State shared by every chunk of one download, grouped so the per-chunk helper
/// stays within the project's six-parameter limit.
private struct ChunkJobContext: Sendable {
    let url: URL
    let headers: [String: String]?
    let remoteInfo: RemoteFileInfo
    let partURL: URL
    let aggregator: ChunkProgressAggregator
    let recorder: ChunkResumptionRecorder
    let servingHost: ServingHostRecorder
}

/// Everything one chunk needs to run.
private struct ChunkDownloadContext: Sendable {
    let chunk: DownloadChunk
    let cursor: ChunkWriteCursor
    let job: ChunkJobContext
}

/// Downloads one large file with several concurrent HTTP Range requests.
///
/// Each chunk writes into a pre-allocated temporary file through its own file
/// descriptor, so no merge pass is needed: the assembled file is ready as soon
/// as the last chunk completes.
enum ChunkedDownloader {
    static func download(
        url: URL,
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
    ) async throws -> URL {
        try await download(
            candidateURLs: [url],
            destinationURL: destinationURL,
            expectedSha1: expectedSha1,
            headers: headers,
            progressHandler: progressHandler,
        )
    }

    /// Downloads one large file with several concurrent HTTP Range requests.
    ///
    /// The candidate sources are probed in order so a mirror that ignores range
    /// requests falls through to the official host instead of abandoning chunking.
    static func download(
        candidateURLs: [URL],
        destinationURL: URL,
        expectedSha1: String? = nil,
        headers: [String: String]? = nil,
        progressHandler: (@Sendable (Int64, Int64) -> Void)? = nil,
    ) async throws -> URL {
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

        guard DIContainer.shared.ui.gameSettingsManager.enableChunkedDownloads else {
            throw ChunkedDownloadError.notSupported(reason: "chunked downloads are disabled in settings")
        }

        let (url, info) = try await probeChunkableSource(candidateURLs: candidateURLs, headers: headers)

        let budget = DownloadBudget.shared
        await budget.syncLimit(DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)
        let limit = await budget.currentLimit()
        let maxChunks = limit >= 2
            ? max(2, min(ChunkedDownloadConfig.maxChunksPerFile, limit))
            : 1

        // The initial plan deliberately stops short of the cap so a straggler has
        // somewhere to hand its tail later.
        let chunks = ChunkPlan.make(
            fileSize: info.contentLength,
            maxChunks: maxChunks,
            reservedSlots: ChunkedDownloadConfig.stealSlots,
        )
        guard !chunks.isEmpty else {
            throw ChunkedDownloadError.notSupported(reason: "empty chunk plan for size \(info.contentLength)")
        }

        try ensureFreeSpace(for: info.contentLength, at: destinationURL)

        let key = resumptionKey(for: url.absoluteString, destinationURL: destinationURL)
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
            url: url.absoluteString,
            info: info,
            chunkCount: chunks.count,
            initial: resumed,
        )
        let servingHost = ServingHostRecorder()

        let cursors: [Int: ChunkWriteCursor] = Dictionary(uniqueKeysWithValues: chunks.map { chunk in
            (chunk.index, ChunkWriteCursor(written: resumed[chunk.index] ?? 0, capacity: chunk.length))
        })

        let board = ChunkBoard(chunks: chunks, cursors: cursors, maxChunks: maxChunks)

        let job = ChunkJobContext(
            url: url,
            headers: headers,
            remoteInfo: info,
            partURL: partURL,
            aggregator: aggregator,
            recorder: recorder,
            servingHost: servingHost,
        )

        // Periodic saves mean a crash or force-quit loses at most one second of
        // progress rather than everything downloaded so far.
        let persistence = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                for entry in await board.progressSnapshot() {
                    await recorder.set(chunk: entry.index, written: entry.written)
                }
            }
        }
        defer { persistence.cancel() }

        // Reserve the whole cap up front: stealing may grow the chunk count later,
        // and acquiring per chunk would race with the group's teardown.
        let clock = ContinuousClock()
        let queuedAt = clock.now
        await budget.acquire(maxChunks)
        // Waiting for connections is not transferring bytes. During a busy
        // install that wait can dwarf the download itself, and counting it would
        // report a throughput that measures the queue rather than the transfer.
        let queueDelay = queuedAt.duration(to: clock.now)
        let startedAt = clock.now

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for chunk in chunks {
                    let context = ChunkDownloadContext(
                        chunk: chunk,
                        cursor: cursors[chunk.index] ?? ChunkWriteCursor(capacity: chunk.length),
                        job: job,
                    )
                    group.addTask {
                        try await downloadChunkWithRetry(context)
                    }
                }

                // Every completed chunk frees a connection. Offer it to the tail of
                // whichever chunk fell behind instead of letting it sit idle.
                while try await group.next() != nil {
                    guard let stolen = await board.steal() else { continue }
                    let context = ChunkDownloadContext(chunk: stolen.chunk, cursor: stolen.cursor, job: job)
                    group.addTask {
                        try await downloadChunkWithRetry(context)
                    }
                }
            }
        } catch {
            await budget.release(maxChunks)
            throw error
        }
        await budget.release(maxChunks)

        // Sampled here rather than after validation: hashing and moving the file
        // cost time that has nothing to do with how fast bytes arrived.
        let chunksUsed = await board.chunkCount
        recordThroughput(
            bytes: info.contentLength,
            elapsed: startedAt.duration(to: clock.now),
            queueDelay: queueDelay,
            chunkCount: chunksUsed,
            host: await servingHost.value ?? url.host,
        )

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

        return destinationURL
    }

    /// Finds the first candidate source that can serve range requests for a large file.
    /// - Returns: The chosen source and what its HEAD response told us.
    /// - Throws: ``ChunkedDownloadError.notSupported`` when no candidate qualifies.
    private static func probeChunkableSource(
        candidateURLs: [URL],
        headers: [String: String]?,
    ) async throws -> (URL, RemoteFileInfo) {
        var lastReason = "no candidate source"

        for candidate in candidateURLs {
            let host = candidate.host ?? "?"
            if ChunkedDownloadTelemetry.isChunkingDisabled(forHost: candidate.host) {
                lastReason = "chunking previously measured ineffective for \(host)"
                continue
            }
            guard let info = try? await RemoteFileProbe.probe(url: candidate, headers: headers) else {
                lastReason = "HEAD failed for \(host)"
                continue
            }
            guard info.acceptsRanges, info.contentLength >= ChunkedDownloadConfig.minimumFileSize else {
                lastReason = "acceptsRanges=\(info.acceptsRanges), size=\(info.contentLength) on \(host)"
                continue
            }
            return (candidate, info)
        }

        throw ChunkedDownloadError.notSupported(reason: lastReason)
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
        let canReuse = stored?.matches(
            etag: info.etag,
            lastModified: info.lastModified,
            fileSize: fileSize,
            chunkCount: chunkCount,
        ) ?? false
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

    private static func resumptionKey(for urlString: String, destinationURL: URL) -> String {
        SHA1Calculator.sha1(of: Data("\(urlString)\n\(destinationURL.standardizedFileURL.path)".utf8))
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

    /// Samples how fast a chunked download actually moved bytes.
    ///
    /// Only unpressured transfers are worth sampling. When a download had to wait
    /// for connections or shared the pipe with a queue of other files, its
    /// throughput says how busy the machine was, not whether splitting the file
    /// helped — and acting on those numbers pins hosts that are perfectly fine.
    private static func recordThroughput(
        bytes: Int64,
        elapsed: Duration,
        queueDelay: Duration,
        chunkCount: Int,
        host: String?,
    ) {
        guard chunkCount > 1 else { return }

        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        guard seconds > 0 else { return }

        let queuedSeconds = Double(queueDelay.components.seconds)
            + Double(queueDelay.components.attoseconds) / 1e18
        guard queuedSeconds < ChunkedDownloadConfig.maximumUnpressuredQueueSeconds else {
            AppLog.common.info("Ignoring a chunked throughput sample for \(host ?? "?"): waited \(Int(queuedSeconds))s for connections")
            return
        }

        let bytesPerSecond = Double(bytes) / seconds
        guard bytesPerSecond < Double(ChunkedDownloadConfig.minimumEffectiveBytesPerSecond) else {
            ChunkedDownloadTelemetry.recordEffective(host: host)
            return
        }

        AppLog.common.info("Chunked download averaged \(Int(bytesPerSecond)) B/s from \(host ?? "?"); sampling against chunking for this host")
        ChunkedDownloadTelemetry.recordIneffective(host: host)
    }

    private static func downloadChunkWithRetry(_ context: ChunkDownloadContext) async throws {
        let chunk = context.chunk
        let cursor = context.cursor
        var attempt = 0

        while true {
            try Task.checkCancellation()

            do {
                let servingHost = try await ChunkedDownloadSession.shared.download(
                    request: ChunkedDownloadSession.DownloadRequest(
                        chunk: chunk,
                        url: context.job.url,
                        headers: context.job.headers,
                        partURL: context.job.partURL,
                        cursor: cursor,
                        aggregator: context.job.aggregator,
                        remoteInfo: context.job.remoteInfo,
                    ),
                )
                // `cursor.written` rather than `chunk.length`: the chunk's tail may
                // have been handed to another request mid-flight.
                await context.job.recorder.set(chunk: chunk.index, written: cursor.written)
                if let host = servingHost {
                    await context.job.servingHost.set(host)
                }
                return
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    // Keep whatever landed on disk so the next run can resume.
                    await context.job.recorder.set(chunk: chunk.index, written: cursor.written)
                    throw CancellationError()
                }
                if case ChunkedDownloadError.notSupported = error {
                    throw error
                }
                guard attempt < DownloadRetryPolicy.maxRetryCount,
                      DownloadRetryPolicy.shouldRetry(error) else {
                    await context.job.recorder.set(chunk: chunk.index, written: cursor.written)
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
                statusCode: statusCode,
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

    private struct SessionCache {
        var session: URLSession?
        var connectionsPerHost = 0
        var retiring: [URLSession] = []
    }

    private let sessionState = OSAllocatedUnfairLock<SessionCache>(initialState: SessionCache())
    /// Hosts that answered a `Range` request with 200 instead of 206, so the
    /// remaining chunks stop before each of them pulls a full copy of the file.
    ///
    /// Keyed by host rather than a single flag: a host that ignores `Range` says
    /// nothing about the others, and one bad host must not quietly turn chunking
    /// off for the whole process.
    /// Statuses that mean "this host will not serve byte ranges", as opposed to a
    /// transient failure such as 429 or a 5xx that may clear on its own.
    private static let rangeRefusalStatuses: Set<Int> = [403, 405, 501]

    private let hostsWithoutRangeSupport = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    /// Created on first use: the delegate (`self`) only exists after `init`.
    private var session: URLSession {
        let limit = max(1, DIContainer.shared.ui.gameSettingsManager.concurrentDownloads)
        let (session, retired) = sessionState.withLock { cache -> (URLSession, URLSession?) in
            if let session = cache.session, cache.connectionsPerHost == limit {
                return (session, nil)
            }
            let created = NetworkSession.makeSession(delegate: self)
            let previous = cache.session
            if let previous { cache.retiring.append(previous) }
            cache.session = created
            cache.connectionsPerHost = limit
            return (created, previous)
        }
        retired?.finishTasksAndInvalidate()
        return session
    }

    fileprivate struct DownloadRequest {
        let chunk: DownloadChunk
        let url: URL
        let headers: [String: String]?
        let partURL: URL
        let cursor: ChunkWriteCursor
        let aggregator: ChunkProgressAggregator
        let remoteInfo: RemoteFileInfo
    }

    fileprivate func download(
        request: DownloadRequest,
    ) async throws -> String? {
        let chunk = request.chunk
        let url = request.url
        let headers = request.headers
        let partURL = request.partURL
        let cursor = request.cursor
        let aggregator = request.aggregator
        let remoteInfo = request.remoteInfo

        let resumeOffset = cursor.written
        let capacity = cursor.capacity
        if resumeOffset >= capacity {
            await aggregator.report(chunk: chunk.index, totalWritten: capacity)
            return nil
        }

        if ignoresRange(host: url.host) {
            throw ChunkedDownloadError.notSupported(
                reason: "\(url.host ?? "?") ignores Range requests",
            )
        }

        guard let handle = FileHandle(forWritingAtPath: partURL.path) else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification,
                message: "Cannot open \(partURL.path) for chunk \(chunk.index)",
            )
        }

        let startOffset = chunk.lowerBound + resumeOffset
        // The end follows `capacity`, not the chunk's original upper bound: a
        // stolen tail lowers the capacity so a retried request stops earlier too.
        let endOffset = chunk.lowerBound + capacity - 1

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
            remoteInfo: remoteInfo,
        )
        let context = ChunkedTaskContext()

        do {
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    tracker.setContinuation(continuation)

                    var request = URLRequest(url: url).headers(headers)
                    request.setValue("bytes=\(startOffset)-\(endOffset)", forHTTPHeaderField: "Range")
                    if let etag = remoteInfo.etag {
                        request.setValue(etag, forHTTPHeaderField: "If-Range")
                    } else if let lastModified = remoteInfo.lastModified {
                        request.setValue(lastModified, forHTTPHeaderField: "If-Range")
                    }

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
            return tracker.servingHost
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
            tracker.setServingHost(httpResponse.url?.host ?? dataTask.currentRequest?.url?.host)
            if httpResponse.statusCode == 200 {
                markIgnoresRange(host: response.url?.host ?? dataTask.originalRequest?.url?.host)
                fail(tracker, for: dataTask, with: ChunkedDownloadError.notSupported(
                    reason: "server returned 200 for a Range request",
                ))
                completionHandler(.cancel)
                return
            }
            guard httpResponse.statusCode == 206 else {
                // A refusal rather than a transient failure: the host will not
                // serve this file in parts, so stop offering it ranges.
                if Self.rangeRefusalStatuses.contains(httpResponse.statusCode) {
                    markIgnoresRange(host: response.url?.host ?? dataTask.originalRequest?.url?.host)
                }
                fail(tracker, for: dataTask, with: DownloadHTTPStatusError.httpStatus(httpResponse.statusCode))
                completionHandler(.cancel)
                return
            }
            let expectedRange = dataTask.originalRequest?.value(forHTTPHeaderField: "Range")
                .flatMap(Self.parseRangeHeader)
            let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
                .flatMap(Self.parseContentRange)
            guard let expectedRange, let contentRange,
                  contentRange.start == expectedRange.start,
                  contentRange.end == expectedRange.end,
                  contentRange.total == tracker.remoteInfo.contentLength else {
                fail(tracker, for: dataTask, with: ChunkedDownloadError.notSupported(
                    reason: "server returned an invalid Content-Range",
                ))
                completionHandler(.cancel)
                return
            }
            if let expectedETag = tracker.remoteInfo.etag,
               httpResponse.value(forHTTPHeaderField: "ETag") != expectedETag {
                fail(tracker, for: dataTask, with: ChunkedDownloadError.notSupported(
                    reason: "server changed its ETag during a chunked download",
                ))
                completionHandler(.cancel)
                return
            }
            if let expectedLastModified = tracker.remoteInfo.lastModified,
               httpResponse.value(forHTTPHeaderField: "Last-Modified") != expectedLastModified {
                fail(tracker, for: dataTask, with: ChunkedDownloadError.notSupported(
                    reason: "server changed its Last-Modified during a chunked download",
                ))
                completionHandler(.cancel)
                return
            }
        }

        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let tracker = tracker(for: dataTask) else { return }
        do {
            switch try tracker.append(data) {
            case .accepted:
                break
            case .reachedEnd:
                // The tail of this chunk now belongs to another request, so stop
                // pulling bytes we are no longer allowed to write.
                tracker.finish()
                removeTracker(for: dataTask)
                dataTask.cancel()
            }
        } catch {
            fail(tracker, for: dataTask, with: error)
            dataTask.cancel()
        }
    }

    private static func parseRangeHeader(_ value: String) -> (start: Int64, end: Int64)? {
        guard let range = value.split(separator: "=").last,
              let bounds = parseBounds(String(range)) else { return nil }
        return bounds
    }

    private static func parseContentRange(_ value: String) -> (start: Int64, end: Int64, total: Int64)? {
        guard value.lowercased().hasPrefix("bytes "),
              let range = value.split(separator: " ").last,
              let parts = Optional(range.split(separator: "/", maxSplits: 1)),
              parts.count == 2,
              let bounds = parseBounds(String(parts[0])),
              let total = Int64(parts[1]),
              total > 0 else {
            return nil
        }
        return (bounds.start, bounds.end, total)
    }

    private static func parseBounds(_ value: String) -> (start: Int64, end: Int64)? {
        let bounds = value.split(separator: "-")
        guard bounds.count == 2, let start = Int64(bounds[0]), let end = Int64(bounds[1]), start <= end else {
            return nil
        }
        return (start, end)
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

    private func ignoresRange(host: String?) -> Bool {
        guard let host else { return false }
        return hostsWithoutRangeSupport.withLock { $0.contains(host) }
    }

    private func markIgnoresRange(host: String?) {
        guard let host else { return }
        let isNew = hostsWithoutRangeSupport.withLock { $0.insert(host).inserted }
        guard isNew else { return }
        AppLog.common.info("\(host) will not serve byte ranges; chunking disabled for this host")
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
        var servingHost: String?
    }

    private let chunk: DownloadChunk
    private let fileHandle: FileHandle
    private let cursor: ChunkWriteCursor
    private let aggregator: ChunkProgressAggregator
    let remoteInfo: RemoteFileInfo
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    init(
        chunk: DownloadChunk,
        fileHandle: FileHandle,
        cursor: ChunkWriteCursor,
        aggregator: ChunkProgressAggregator,
        remoteInfo: RemoteFileInfo,
    ) {
        self.chunk = chunk
        self.fileHandle = fileHandle
        self.cursor = cursor
        self.aggregator = aggregator
        self.remoteInfo = remoteInfo
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

    func setServingHost(_ host: String?) {
        state.withLock { $0.servingHost = host }
    }

    var servingHost: String? {
        state.withLock { $0.servingHost }
    }

    /// What happened after handing a buffer to a tracker.
    enum AppendOutcome: Sendable {
        /// The whole buffer belonged to this chunk and was written.
        case accepted
        /// The chunk's end was reached, either exactly or because its tail was
        /// handed to another request. The caller should stop the transfer.
        case reachedEnd
    }

    func append(_ data: Data) throws -> AppendOutcome {
        let requested = Int64(data.count)
        let allowed = cursor.reserve(requested)
        guard allowed > 0 else { return .reachedEnd }

        let payload = allowed == requested ? data : Data(data.prefix(Int(allowed)))
        do {
            try fileHandle.write(contentsOf: payload)
        } catch {
            cursor.rollback(allowed)
            throw error
        }

        let shouldReport = state.withLock { state -> Bool in
            state.lastReported += allowed
            guard state.lastReported >= ChunkedDownloadConfig.progressReportThreshold else { return false }
            state.lastReported = 0
            return true
        }
        if shouldReport {
            let written = cursor.written
            let index = chunk.index
            Task { await aggregator.report(chunk: index, totalWritten: written) }
        }

        return allowed == requested ? .accepted : .reachedEnd
    }

    func finish() {
        let written = cursor.written
        let index = chunk.index
        Task { await aggregator.report(chunk: index, totalWritten: written) }

        // Compare against the cursor rather than `chunk.length`: a stolen tail
        // legitimately shortens the chunk.
        guard cursor.isComplete else {
            complete(.failure(ChunkedDownloadError.incompleteChunk(
                index: chunk.index,
                expected: cursor.capacity,
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
