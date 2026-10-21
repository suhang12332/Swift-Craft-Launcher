//
//  ChunkedDownloadTelemetry.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Remembers hosts where chunking did not pay off, so later downloads skip it.
///
/// A single slow download proves nothing on its own: a transfer that shared the
/// pipe with a dozen other files looks slow no matter how well chunking worked,
/// and one bad sample used to pin a host for good. So a host is only pinned
/// after several slow samples in a row, and every pin expires on its own.
enum ChunkedDownloadTelemetry {
    private static let storageKey = "chunkedDownloadIneffectiveHosts"

    /// Consecutive slow samples before a host is pinned to single-stream downloads.
    private static let streakThreshold = 3

    /// How long a pin lasts. A host that was slow last week may be fine now, and
    /// there is no way to re-measure a host that never gets sampled again.
    private static let pinLifetime: TimeInterval = 24 * 60 * 60

    /// Sample streaks, kept in memory: they are a property of this run, not of
    /// the machine, so losing them on relaunch is the right behaviour.
    private static let streaks = OSAllocatedUnfairLock<[String: Int]>(initialState: [:])

    static func isChunkingDisabled(forHost host: String?) -> Bool {
        guard let host, !host.isEmpty else { return false }
        guard let pinnedAt = pinned[host] else { return false }
        guard Date().timeIntervalSince1970 - pinnedAt < pinLifetime else {
            var remaining = pinned
            remaining.removeValue(forKey: host)
            save(remaining)
            return false
        }
        return true
    }

    /// Pins a host straight away, without waiting for a streak.
    static func markIneffective(host: String?) {
        guard let host, !host.isEmpty else { return }
        var remaining = pinned
        remaining[host] = Date().timeIntervalSince1970
        save(remaining)
    }

    /// Counts one slow sample and pins the host once enough of them pile up.
    static func recordIneffective(host: String?) {
        guard let host, !host.isEmpty else { return }
        let streak = streaks.withLock { streaks -> Int in
            let next = (streaks[host] ?? 0) + 1
            streaks[host] = next
            return next
        }
        guard streak >= streakThreshold else { return }
        markIneffective(host: host)
    }

    /// Counts one sample that was fast enough, clearing the streak and any pin.
    static func recordEffective(host: String?) {
        guard let host, !host.isEmpty else { return }
        streaks.withLock { _ = $0.removeValue(forKey: host) }
        var remaining = pinned
        guard remaining.removeValue(forKey: host) != nil else { return }
        save(remaining)
    }

    static func reset() {
        streaks.withLock { $0.removeAll() }
        save([String: TimeInterval]())
    }

    /// Hosts pinned to single-stream downloads, keyed by when they were pinned.
    private static var pinned: [String: TimeInterval] {
        // Older builds stored a plain host array here. That shape is ignored,
        // which also releases any host pinned under the old one-sample rule.
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: TimeInterval] ?? [:]
    }

    private static func save(_ hosts: [String: TimeInterval]) {
        Defaults.save(hosts, forKey: storageKey)
    }
}
