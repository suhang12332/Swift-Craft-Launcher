//
//  DownloadBudget.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A global cap on simultaneously in-flight download connections.
///
/// Chunked downloads consume `chunkCount` connections each, so without a shared
/// budget the total would be `concurrentFiles x chunksPerFile`. This keeps the
/// process-wide connection count at or below the user's concurrency setting.
actor DownloadBudget {
    static let shared = DownloadBudget()

    private struct Waiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var limit: Int
    private var available: Int
    private var waiters: [Waiter] = []

    init(limit: Int = 64) {
        let sanitized = max(1, limit)
        self.limit = sanitized
        available = sanitized
    }

    /// Aligns the budget with the current concurrency setting.
    func syncLimit(_ newLimit: Int) {
        let sanitized = max(1, newLimit)
        let delta = sanitized - limit
        guard delta != 0 else { return }
        limit = sanitized
        available += delta
        drain()
    }

    func currentLimit() -> Int {
        max(1, limit)
    }

    /// Reserves `count` connections, suspending until they are available.
    func acquire(_ count: Int) async {
        let needed = min(max(1, count), limit)
        if available >= needed {
            available -= needed
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(Waiter(count: needed, continuation: continuation))
        }
    }

    func release(_ count: Int) {
        // A reservation may have been made before the limit was lowered. Release
        // the original reservation, then clamp only the resulting free capacity.
        available += max(1, count)
        if available > limit { available = limit }
        drain()
    }

    /// Wakes every waiter that fits, skipping ones that still do not.
    ///
    /// Skipping is deliberate: strict FIFO would let an unsatisfiable large
    /// request block smaller ones behind it forever.
    private func drain() {
        guard !waiters.isEmpty else { return }
        var index = waiters.startIndex
        while index < waiters.endIndex {
            let waiter = waiters[index]
            if waiter.count <= available {
                waiters.remove(at: index)
                available -= waiter.count
                waiter.continuation.resume()
            } else {
                waiters.formIndex(after: &index)
            }
        }
    }
}
