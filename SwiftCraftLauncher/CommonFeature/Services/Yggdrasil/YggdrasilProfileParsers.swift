//
//  YggdrasilProfileParsers.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Defines the interface for parsing Yggdrasil profile list responses.
protocol YggdrasilProfileListParser: Sendable {
    var id: YggdrasilProfileParserID { get }

    func parse(data: Data) async -> [YggdrasilProfileCandidate]?
}

/// Provides profile list parsers for different Yggdrasil server types.
protocol YggdrasilProfileParserProvider: Sendable {
    func makeParser(
        for id: YggdrasilProfileParserID,
        baseURL: String,
    ) -> (any YggdrasilProfileListParser)?
}

/// Central registry for creating Yggdrasil profile parsers.
enum YggdrasilProfileParsers {
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var provider: (any YggdrasilProfileParserProvider)?

        func configure(provider: any YggdrasilProfileParserProvider) {
            lock.withLock {
                self.provider = provider
            }
        }

        func make(
            _ id: YggdrasilProfileParserID,
            baseURL: String,
        ) -> (any YggdrasilProfileListParser)? {
            lock.withLock {
                provider?.makeParser(for: id, baseURL: baseURL)
            }
        }
    }

    private static let registry = Registry()

    static func configure(provider: any YggdrasilProfileParserProvider) {
        registry.configure(provider: provider)
    }

    static func make(_ id: YggdrasilProfileParserID, baseURL: String) -> (any YggdrasilProfileListParser)? {
        registry.make(id, baseURL: baseURL)
    }
}
