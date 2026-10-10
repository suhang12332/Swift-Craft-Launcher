//
//  CommonYggdrasilProfileParserProvider.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides profile list parsers for LittleSkin, MUA, and Ely.by authentication servers.
struct CommonYggdrasilProfileParserProvider: YggdrasilProfileParserProvider {
    func makeParser(
        for id: YggdrasilProfileParserID,
        baseURL: String,
    ) -> (any YggdrasilProfileListParser)? {
        switch id {
        case .littleskin:
            return CommonYggdrasilStyleProfileListParser(baseURL: baseURL)
        case .mua:
            return CommonBlessingSkinStyleProfileListParser(baseURL: baseURL)
        case .ely:
            return ElyflyProfileStyleProfileListParser(baseURL: baseURL)
        case .custom:
            // Custom password servers return profiles from authenticate; no list parser is needed.
            return nil
        }
    }
}

/// Configures the shared Yggdrasil profile parser provider.
enum CommonYggdrasilProfileParsersConfigurator {
    static func bootstrap() {
        YggdrasilProfileParsers.configure(provider: CommonYggdrasilProfileParserProvider())
    }
}
