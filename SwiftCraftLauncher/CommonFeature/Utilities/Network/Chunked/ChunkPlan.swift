//
//  ChunkPlan.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A byte range of a file to be fetched with a single HTTP Range request.
struct DownloadChunk: Sendable, Equatable {
    let index: Int
    /// Inclusive start offset.
    let lowerBound: Int64
    /// Inclusive end offset.
    let upperBound: Int64

    var length: Int64 { upperBound - lowerBound + 1 }

    /// Value for the `Range` header, e.g. `bytes=0-4194303`.
    var rangeHeaderValue: String { "bytes=\(lowerBound)-\(upperBound)" }
}

/// Splits a file into contiguous, non-overlapping chunks.
enum ChunkPlan {
    /// - Parameters:
    ///   - fileSize: Total size of the remote file in bytes.
    ///   - chunkSize: Desired size of one chunk.
    ///   - maxChunks: Hard cap on the number of chunks.
    ///   - reservedSlots: Slots left free for tail stealing. The initial plan
    ///     stops short of `maxChunks` by this many so a straggler later has
    ///     somewhere to hand its tail.
    /// - Returns: Chunks covering `[0, fileSize - 1]` in ascending order, empty if `fileSize <= 0`.
    static func make(
        fileSize: Int64,
        chunkSize: Int64 = ChunkedDownloadConfig.chunkSize,
        maxChunks: Int = ChunkedDownloadConfig.maxChunksPerFile,
        reservedSlots: Int = 0,
    ) -> [DownloadChunk] {
        guard fileSize > 0, maxChunks > 0 else { return [] }

        let cap = max(1, maxChunks - reservedSlots)
        let desired = Int((fileSize + chunkSize - 1) / max(1, chunkSize))
        let count = max(1, min(cap, desired))
        let chunkLength = (fileSize + Int64(count) - 1) / Int64(count)

        var chunks: [DownloadChunk] = []
        chunks.reserveCapacity(count)

        var lower: Int64 = 0
        for index in 0 ..< count {
            let upper = index == count - 1 ? fileSize - 1 : min(lower + chunkLength - 1, fileSize - 1)
            chunks.append(DownloadChunk(index: index, lowerBound: lower, upperBound: upper))
            lower = upper + 1
        }
        return chunks
    }
}
