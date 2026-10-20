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

    /// Target size of a single chunk before the chunk count cap is applied.
    static let chunkSize: Int64 = 4 * 1024 * 1024

    /// Upper bound on chunks per file, regardless of file size.
    static let maxChunksPerFile = 8

    /// Retries per chunk before the whole download fails.
    static let maxRetryCount = 3

    /// Minimum interval between aggregated progress callbacks.
    static let progressEmitInterval: Duration = .milliseconds(100)

    /// Bytes a chunk accumulates before reporting progress to the aggregator.
    static let progressReportThreshold: Int64 = 256 * 1024

    /// Below this average throughput, a chunked download is treated as not worth
    /// the extra connections and the host is pinned to single-stream downloads.
    static let minimumEffectiveBytesPerSecond = 2 * 1024 * 1024
}
