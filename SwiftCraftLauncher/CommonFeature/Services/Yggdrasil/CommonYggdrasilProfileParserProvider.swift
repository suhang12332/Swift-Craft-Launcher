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
            // 自定义密码服务器不经 OAuth 角色列表接口,无需解析器。
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
