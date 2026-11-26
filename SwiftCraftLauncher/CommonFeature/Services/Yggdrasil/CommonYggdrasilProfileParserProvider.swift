//
//  CommonYggdrasilProfileParserProvider.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides profile list parsers for LittleSkin, MUA, and Ely.by authentication servers.
struct CommonYggdrasilProfileParserProvider: YggdrasilProfileParserProvider {
    func makeParser(
        for id: YggdrasilProfileParserID,
    ) -> (any YggdrasilProfileListParser)? {
        switch id {
        case .littleskin, .mua:
            return CommonYggdrasilStyleProfileListParser()
        case .ely:
            return ElyflyProfileStyleProfileListParser()
        }
    }
}

/// Configures the shared Yggdrasil profile parser provider.
enum CommonYggdrasilProfileParsersConfigurator {
    static func bootstrap() {
        YggdrasilProfileParsers.configure(provider: CommonYggdrasilProfileParserProvider())
    }
}
