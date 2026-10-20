//
//  ChunkProgressAggregator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Aggregates per-chunk byte counts into a single throttled progress callback.
actor ChunkProgressAggregator {
    private let totalSize: Int64
    private let progressHandler: (@Sendable (Int64, Int64) -> Void)?
    private let clock = ContinuousClock()

    private var perChunk: [Int: Int64] = [:]
    private var lastEmit: ContinuousClock.Instant?

    init(totalSize: Int64, progressHandler: (@Sendable (Int64, Int64) -> Void)?) {
        self.totalSize = totalSize
        self.progressHandler = progressHandler
    }

    /// Records the absolute number of bytes written for a chunk and emits
    /// progress when the throttle window allows it.
    ///
    /// Passing an absolute value (rather than a delta) keeps totals correct
    /// when a chunk is retried after a partial failure.
    func report(chunk index: Int, totalWritten: Int64) {
        perChunk[index] = totalWritten

        let now = clock.now
        if let lastEmit, lastEmit.duration(to: now) < ChunkedDownloadConfig.progressEmitInterval {
            return
        }
        lastEmit = now
        emit()
    }

    /// Forces a final progress emission with the exact accumulated total.
    func flush() {
        emit()
    }

    private func emit() {
        guard let progressHandler else { return }
        let written = perChunk.values.reduce(0, +)
        let total = totalSize
        Task { @MainActor in
            progressHandler(written, total)
        }
    }
}
