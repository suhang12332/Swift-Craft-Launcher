//
//  ChunkWriteCursor.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Tracks how many bytes of a chunk have landed on disk, and how many may still be written.
///
/// `capacity` is mutable on purpose: when a straggler's tail is handed to another
/// chunk, the victim's capacity shrinks. That is how an already in-flight request
/// is told to stop early, without tearing down its connection.
final class ChunkWriteCursor: @unchecked Sendable {
    private struct State {
        var written: Int64
        var capacity: Int64
    }

    private let lock: OSAllocatedUnfairLock<State>

    init(written: Int64 = 0, capacity: Int64) {
        lock = OSAllocatedUnfairLock<State>(initialState: State(written: written, capacity: capacity))
    }

    /// Reserves up to `count` bytes of the remaining budget.
    /// - Returns: How many bytes may actually be written. Zero means the chunk has
    ///   reached its (possibly reduced) end and the caller must stop writing.
    func reserve(_ count: Int64) -> Int64 {
        lock.withLock { state in
            let remaining = state.capacity - state.written
            guard remaining > 0 else { return 0 }
            let allowed = min(count, remaining)
            state.written += allowed
            return allowed
        }
    }

    func rollback(_ count: Int64) {
        lock.withLock { state in
            state.written = max(Int64(0), state.written - count)
        }
    }

    /// Lowers the total byte budget to what is already written plus `remaining`.
    func capCapacity(toRemaining remaining: Int64) {
        lock.withLock { state in
            state.capacity = min(state.capacity, state.written + max(Int64(0), remaining))
        }
    }

    /// Atomically removes a tail from this cursor while checking the bytes
    /// currently written. This prevents a concurrent writer from racing a steal.
    func stealTail(_ requested: Int64, lowerBound: Int64, upperBound: Int64) -> (lowerBound: Int64, bytes: Int64)? {
        lock.withLock { state in
            let remaining = state.capacity - state.written
            let bytes = min(requested, remaining)
            guard bytes > 0 else { return nil }
            let newLowerBound = upperBound + 1 - bytes
            guard newLowerBound > lowerBound + state.written else { return nil }
            state.capacity -= bytes
            return (newLowerBound, bytes)
        }
    }

    var written: Int64 { lock.withLock { $0.written } }
    var capacity: Int64 { lock.withLock { $0.capacity } }
    var remaining: Int64 { lock.withLock { $0.capacity - $0.written } }
    var isComplete: Bool { lock.withLock { $0.written >= $0.capacity } }
}
