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
        configuration.httpMaximumConnectionsPerHost = 16
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return configuration
    }()

    /// Creates a new URLSession with optional delegate and configuration overrides.
    /// - Parameters:
    ///   - delegate: The session delegate.
    ///   - configure: A closure to modify the default configuration before the session is created.
    /// - Returns: A configured URLSession instance.
    static func makeSession(
        delegate: URLSessionDelegate? = nil,
        configure: ((URLSessionConfiguration) -> Void)? = nil
    ) -> URLSession {
        let configuration = newConfiguration()
        configure?(configuration)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private static func newConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = sharedConfiguration.timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = sharedConfiguration.timeoutIntervalForResource
        configuration.httpMaximumConnectionsPerHost = sharedConfiguration.httpMaximumConnectionsPerHost
        configuration.waitsForConnectivity = sharedConfiguration.waitsForConnectivity
        configuration.requestCachePolicy = sharedConfiguration.requestCachePolicy
        return configuration
    }
}
