//
//  ChunkedDownloadConfig.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tunables for the chunked (HTTP Range) download path.
enum ChunkedDownloadConfig {
    /// Files smaller than this are never chunked; the overhead is not worth it.
    static let minimumFileSize: Int64 = 8 * 1024 * 1024

    /// Whether a file of this size is worth chunking.
    ///
    /// Chunking opens with a HEAD request to confirm the host serves ranges, so
    /// callers that already know the size can skip that round trip for files too
    /// small to be split anyway.
    static func isWorthChunking(fileSize: Int64) -> Bool {
        fileSize >= minimumFileSize
    }

    /// Target size of a single chunk before the chunk count cap is applied.
    static let chunkSize: Int64 = 4 * 1024 * 1024

    /// Upper bound on chunks per file, regardless of file size.
    static let maxChunksPerFile = 8

    /// Chunk slots the initial plan leaves free so a straggler's tail can be
    /// stolen later. Without spare slots every chunk is already in flight and
    /// stealing has nowhere to go.
    static let stealSlots = 2

    /// A chunk must still have this many unwritten bytes before it may be split,
    /// and the stolen tail must be at least this large too.
    static let minimumStealableBytes: Int64 = 1024 * 1024

    /// Fraction of the victim's remaining bytes handed to a newly started chunk.
    static let stealRatio = 0.4

    /// How far ahead of the average a chunk must be before it counts as a
    /// straggler. Comparing against the average (rather than an absolute size)
    /// keeps stealing idle while chunks progress at similar speeds.
    static let stealSlownessFactor = 2.0

    /// Retries per chunk before the whole download fails.
    static let maxRetryCount = 3

    /// Minimum interval between aggregated progress callbacks.
    static let progressEmitInterval: Duration = .milliseconds(100)

    /// Bytes a chunk accumulates before reporting progress to the aggregator.
    static let progressReportThreshold: Int64 = 256 * 1024

    /// Below this average throughput, a chunked download is treated as not worth
    /// the extra connections and counts as a sample against the host. Several
    /// such samples in a row pin the host to single-stream downloads.
    static let minimumEffectiveBytesPerSecond = 2 * 1024 * 1024

    /// How long a chunked download may wait for connections before its
    /// throughput is considered unrepresentative and discarded. A transfer that
    /// queued behind other files measures the competition, not the transfer.
    static let maximumUnpressuredQueueSeconds: Double = 1.0
}
