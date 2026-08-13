//
//  NetworkSession.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides configured URLSession instances with shared timeout and connection settings.
enum NetworkSession {
    static let sharedConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return configuration
    }()

    /// Creates a new URLSession with an optional delegate.
    /// The per-host connection limit follows the user's concurrent download setting,
    /// so it never caps the configured concurrency below its intended value.
    /// - Parameters:
    ///   - delegate: The session delegate.
    /// - Returns: A configured URLSession instance.
    static func makeSession(delegate: URLSessionDelegate? = nil) -> URLSession {
        let configuration = newConfiguration()
        configuration.httpMaximumConnectionsPerHost = max(
            1,
            DIContainer.shared.ui.generalSettingsManager.concurrentDownloads,
        )
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private static func newConfiguration() -> URLSessionConfiguration {
        guard let configuration = sharedConfiguration.copy() as? URLSessionConfiguration else {
            return URLSessionConfiguration.default
        }
        return configuration
    }
}
