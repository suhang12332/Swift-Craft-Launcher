//
//  ChunkBoard.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// The work handed to a newly started request when a straggler is split.
struct ChunkSteal: Sendable {
    let chunk: DownloadChunk
    let cursor: ChunkWriteCursor
}

/// Tracks every live chunk of one download and decides when to split a straggler.
///
/// A static split wastes connections whenever one chunk runs slower than the
/// rest: the fast chunks finish, their connections go idle, and the slow one
/// keeps working alone. When that shows up, this board carves the tail off the
/// slowest chunk and hands it to a fresh request so the freed connection keeps
/// contributing.
///
/// The victim is never restarted. Its cursor's capacity is lowered instead, so
/// the request already in flight simply stops writing once it reaches the new
/// end and reports success for the shorter range.
actor ChunkBoard {
    private struct Entry {
        var lowerBound: Int64
        var upperBound: Int64
        let cursor: ChunkWriteCursor
    }

    private var entries: [Int: Entry] = [:]
    private var nextIndex = 0
    private let maxChunks: Int

    init(chunks: [DownloadChunk], cursors: [Int: ChunkWriteCursor], maxChunks: Int) {
        self.maxChunks = maxChunks
        for chunk in chunks {
            entries[chunk.index] = Entry(
                lowerBound: chunk.lowerBound,
                upperBound: chunk.upperBound,
                cursor: cursors[chunk.index] ?? ChunkWriteCursor(capacity: chunk.length),
            )
            nextIndex = max(nextIndex, chunk.index + 1)
        }
    }

    /// How many chunks the download has used so far, including stolen ones.
    var chunkCount: Int { entries.count }

    /// Per-chunk written byte counts, for the periodic resumption save.
    func progressSnapshot() -> [(index: Int, written: Int64)] {
        entries.map { (index: $0.key, written: $0.value.cursor.written) }
    }

    /// Carves a new chunk out of the tail of the slowest unfinished chunk.
    /// - Returns: The new chunk and its cursor, or `nil` when nothing is worth stealing.
    func steal() -> ChunkSteal? {
        guard entries.count < maxChunks else { return nil }

        var unfinished: [(index: Int, remaining: Int64)] = []
        for (index, entry) in entries {
            let remaining = entry.cursor.remaining
            if remaining > 0 {
                unfinished.append((index, remaining))
            }
        }

        guard let victim = unfinished.max(by: { $0.remaining < $1.remaining }),
              victim.remaining >= ChunkedDownloadConfig.minimumStealableBytes,
              var victimEntry = entries[victim.index] else {
            return nil
        }

        // Only intervene when one chunk is genuinely behind the others, otherwise
        // a normally progressing download would be split apart for no reason.
        // Once only one or two chunks remain, however, any split is a win: the
        // connections are already idle and the download is waiting on that tail.
        if unfinished.count > 1 {
            let total = unfinished.reduce(Int64(0)) { $0 + $1.remaining }
            let average = Double(total) / Double(unfinished.count)
            let factor = unfinished.count <= 2 ? 1.0 : ChunkedDownloadConfig.stealSlownessFactor
            guard Double(victim.remaining) >= factor * average else { return nil }
        }

        let stolenBytes = Int64(Double(victim.remaining) * ChunkedDownloadConfig.stealRatio)
        guard stolenBytes >= ChunkedDownloadConfig.minimumStealableBytes else { return nil }

        let victimUpperBound = victimEntry.upperBound
        let newLowerBound = victimUpperBound + 1 - stolenBytes
        // The victim must still own at least one byte, otherwise the ranges would
        // overlap and the two requests would write over each other.
        guard newLowerBound > victimEntry.lowerBound + victimEntry.cursor.written else { return nil }

        victimEntry.cursor.capCapacity(toRemaining: victim.remaining - stolenBytes)
        victimEntry.upperBound = newLowerBound - 1
        entries[victim.index] = victimEntry

        let index = nextIndex
        nextIndex += 1
        let cursor = ChunkWriteCursor(capacity: stolenBytes)
        entries[index] = Entry(
            lowerBound: newLowerBound,
            upperBound: victimUpperBound,
            cursor: cursor,
        )

        AppLog.common.info("Chunk \(victim.index) is behind; handed \(stolenBytes) bytes of its tail to chunk \(index)")
        return ChunkSteal(
            chunk: DownloadChunk(index: index, lowerBound: newLowerBound, upperBound: victimUpperBound),
            cursor: cursor,
        )
    }
}
