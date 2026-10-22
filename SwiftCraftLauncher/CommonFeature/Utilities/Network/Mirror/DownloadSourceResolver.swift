//
//  DownloadSourceResolver.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// How the launcher orders official and mirrored URLs for a single download.
enum DownloadSourcePreference: String, CaseIterable, Codable, Sendable {
    /// Mirror first, fall back to the official source, and temporarily demote
    /// hosts that keep failing. This is the default and the best choice for
    /// most users behind the Great Firewall.
    case automatic
    /// Always try the mirror first, falling back to the official source on failure.
    /// Unlike ``automatic``, a mirror that fails is never demoted.
    case mirror
    /// Prefer the official source, falling back to the mirror when it fails.
    case official
    /// Never contact a mirror.
    case officialOnly

    static var defaultValue: Self { .automatic }

    var localizedName: String {
        "settings.download_source.\(rawValue)".localized()
    }
}

/// Why a download failed on a particular source.
///
/// The distinction matters because a mirror legitimately lacks some files or
/// rate-limits bursts, neither of which means the host itself is unusable.
enum DownloadSourceFailure: Sendable, Equatable {
    /// The file is missing or access was refused on this host. Switch sources,
    /// but do not count the failure against the host.
    case content
    /// The host looks broken or unreachable. Counts toward demotion.
    case host

    /// Classifies a download error so the resolver knows whether to blame the host.
    ///
    /// Rate limiting (429) and forbidden (403) are treated as content failures:
    /// mirrors commonly return both under high concurrency, and disabling the
    /// mirror for them would defeat its purpose.
    static func classify(_ error: Error) -> Self {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return .content
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable,
                 .badServerResponse,
                 .secureConnectionFailed,
                 .serverCertificateUntrusted:
                return .host
            default:
                return .content
            }
        }

        if let statusCode = httpStatusCode(of: error) {
            if (500 ... 599).contains(statusCode) || statusCode == 408 {
                return .host
            }
            // 403/404/429 and anything else say nothing about host health.
            return .content
        }

        return .host
    }

    /// Pulls an HTTP status code out of the errors the download stack raises.
    private static func httpStatusCode(of error: Error) -> Int? {
        if let globalError = error as? GlobalError {
            return globalError.statusCode
        }
        if case let DownloadHTTPStatusError.httpStatus(statusCode) = error {
            return statusCode
        }
        return nil
    }
}

/// Builds the ordered list of URLs to try for one download and remembers which
/// hosts have been misbehaving.
///
/// Modeled on PCL's `NetSource`: every file carries a list of sources rather
/// than a single URL, and a source that fails repeatedly is demoted for a short
/// cooldown instead of being retried on every file.
actor DownloadSourceResolver {
    static let shared = DownloadSourceResolver()

    private struct HostHealth {
        var consecutiveFailures = 0
        var lastFailureAt: Date?
    }

    private var health: [String: HostHealth] = [:]

    /// Consecutive host-level failures before a host is demoted.
    private let failureThreshold = 3
    /// How long a demoted host stays demoted.
    private let cooldownInterval: TimeInterval = 5 * 60

    /// The ordered URLs to try for a download, best first.
    /// - Parameters:
    ///   - url: The official URL.
    ///   - preference: The user's source preference.
    /// - Returns: A de-duplicated list containing at least the official URL.
    func candidateURLs(for url: URL, preference: DownloadSourcePreference) -> [URL] {
        guard preference != .officialOnly,
              let mirror = DownloadMirror.bmclapi.mirroredURL(for: url) else {
            return [url]
        }

        switch preference {
        case .officialOnly:
            return [url]
        case .official:
            return Self.dedupe([url, mirror])
        case .mirror:
            return Self.dedupe([mirror, url])
        case .automatic:
            if isDemoted(mirror), !isDemoted(url) {
                return Self.dedupe([url, mirror])
            }
            return Self.dedupe([mirror, url])
        }
    }

    /// Records a successful download from a host, clearing its failure streak.
    func recordSuccess(host: String?) {
        guard let key = Self.key(for: host) else { return }
        health[key] = HostHealth()
    }

    /// Records a failed download from a host.
    /// - Parameters:
    ///   - host: The host that served the failed request.
    ///   - failure: Whether the failure reflects on the host's health.
    func recordFailure(host: String?, failure: DownloadSourceFailure) {
        guard let key = Self.key(for: host), failure == .host else { return }
        var entry = health[key] ?? HostHealth()
        entry.consecutiveFailures += 1
        entry.lastFailureAt = Date()
        health[key] = entry

        if entry.consecutiveFailures >= failureThreshold {
            AppLog.common.info("Demoting download host \(key) after \(entry.consecutiveFailures) consecutive failures")
        }
    }

    /// Whether a URL's host is inside its cooldown window.
    func isDemoted(_ url: URL) -> Bool {
        Self.isDemoted(url: url, health: health, threshold: failureThreshold, cooldown: cooldownInterval)
    }

    /// Resets all recorded host health.
    func resetHealth() {
        health.removeAll()
    }

    private static func isDemoted(
        url: URL,
        health: [String: HostHealth],
        threshold: Int,
        cooldown: TimeInterval,
    ) -> Bool {
        guard let key = key(for: url.host), let entry = health[key] else { return false }
        guard entry.consecutiveFailures >= threshold, let lastFailureAt = entry.lastFailureAt else {
            return false
        }
        return Date().timeIntervalSince(lastFailureAt) < cooldown
    }

    private static func key(for host: String?) -> String? {
        guard let host, !host.isEmpty else { return nil }
        return host.lowercased()
    }

    private static func dedupe(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            let identity = url.absoluteString
            guard !seen.contains(identity) else { continue }
            seen.insert(identity)
            result.append(url)
        }
        return result.isEmpty ? urls : result
    }
}
