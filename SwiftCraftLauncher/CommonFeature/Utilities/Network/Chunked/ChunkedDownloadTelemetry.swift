//
//  ChunkedDownloadTelemetry.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Remembers hosts where chunking did not pay off, so later downloads skip it.
///
/// A slow chunked download is not proof that chunking is wrong — the network may
/// simply be slow. But if the throughput is below the usefulness threshold, a
/// single stream costs the same wall-clock time with fewer connections, so the
/// host is pinned to single-stream downloads from then on.
enum ChunkedDownloadTelemetry {
    private static let storageKey = "chunkedDownloadIneffectiveHosts"

    static func isChunkingDisabled(forHost host: String?) -> Bool {
        guard let host, !host.isEmpty else { return false }
        let hosts = UserDefaults.standard.array(forKey: storageKey) as? [String] ?? []
        return hosts.contains(host)
    }

    static func markIneffective(host: String?) {
        guard let host, !host.isEmpty else { return }
        var hosts = UserDefaults.standard.array(forKey: storageKey) as? [String] ?? []
        guard !hosts.contains(host) else { return }
        hosts.append(host)
        Defaults.save(hosts, forKey: storageKey)
    }

    static func reset() {
        Defaults.save([String](), forKey: storageKey)
    }
}
