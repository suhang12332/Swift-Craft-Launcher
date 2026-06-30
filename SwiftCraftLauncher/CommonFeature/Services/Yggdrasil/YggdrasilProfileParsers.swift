//
//  YggdrasilProfileParsers.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Defines the interface for parsing Yggdrasil profile list responses.
protocol YggdrasilProfileListParser {
    var id: YggdrasilProfileParserID { get }

    func parse(data: Data) async -> [YggdrasilProfileCandidate]?
}

/// Provides profile list parsers for different Yggdrasil server types.
protocol YggdrasilProfileParserProvider {
    func makeParser(
        for id: YggdrasilProfileParserID,
        baseURL: String,
    ) -> (any YggdrasilProfileListParser)?
}

/// Central registry for creating Yggdrasil profile parsers.
enum YggdrasilProfileParsers {
    private static var provider: YggdrasilProfileParserProvider?

    static func configure(provider: YggdrasilProfileParserProvider) {
        self.provider = provider
    }

    static func make(_ id: YggdrasilProfileParserID, baseURL: String) -> (any YggdrasilProfileListParser)? {
        provider?.makeParser(for: id, baseURL: baseURL)
    }
}
