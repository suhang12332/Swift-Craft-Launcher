//
//  AccountCredential.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// 账号的认证方式,同时作为凭据存储的命名空间隔离键。
///
/// 不同认证方式的凭据在钥匙串中互不可见,防止恶意认证服务器
/// 签发与正版账号相同 UUID 时覆写已有凭据。
enum AccountAuthMethod: String, Codable, CaseIterable, Equatable {
    /// 微软正版 OAuth(XBL → XSTS → Minecraft 令牌链)。
    case microsoft
    /// Yggdrasil 兼容服务器的 OAuth2 授权码登录(LittleSkin / Mua / Ely.By 预设)。
    case yggdrasilOAuth
    /// Yggdrasil classic authserver 用户名密码登录(自定义皮肤站)。
    case yggdrasilPassword
}

/// 统一账号凭据:三种认证方式共用一套 Keychain 存储逻辑。
///
/// 存储层只负责 CRUD,不感知令牌刷新语义。"续期凭据"(`renewalSecret`)
/// 的含义由 `authMethod` 决定:
/// - `.microsoft` / `.yggdrasilOAuth`:OAuth refresh_token。
/// - `.yggdrasilPassword`:用户明确勾选记住的登录密码,未勾选时为 `nil`
///   (classic Yggdrasil 协议没有 refresh_token,记住的密码即续期凭据)。
struct AccountCredential: Codable, Equatable {
    let userId: String
    var authMethod: AccountAuthMethod

    /// 当前可用的访问令牌(微软 MC 令牌 / Yggdrasil OAuth accessToken / authserver accessToken)。
    var accessToken: String

    /// 长期续期凭据,语义由 `authMethod` 决定,可为空。
    var renewalSecret: String?

    /// Yggdrasil classic 协议的 clientToken,仅密码登录使用;
    /// 由启动器安装级生成并全程保持一致。
    var clientToken: String?

    /// 密码登录的登录名(邮箱或角色名),自动重登时与密码成对使用。
    var loginUsername: String?

    /// 微软 Xbox Live 用户标识,仅微软账号使用。
    var xuid: String?

    init(
        userId: String,
        authMethod: AccountAuthMethod,
        accessToken: String,
        renewalSecret: String? = nil,
        clientToken: String? = nil,
        loginUsername: String? = nil,
        xuid: String? = nil,
    ) {
        self.userId = userId
        self.authMethod = authMethod
        self.accessToken = accessToken
        self.renewalSecret = renewalSecret
        self.clientToken = clientToken
        self.loginUsername = loginUsername
        self.xuid = xuid
    }

    /// OAuth refresh_token;非 OAuth 形状的凭据访问时返回 nil,避免错形读取。
    var oauthRefreshToken: String? {
        guard authMethod == .microsoft || authMethod == .yggdrasilOAuth else { return nil }
        return renewalSecret
    }

    /// 已记住的登录密码;仅密码登录且用户勾选记住时非 nil。
    var savedPassword: String? {
        guard authMethod == .yggdrasilPassword else { return nil }
        return renewalSecret
    }

    /// Xbox 用户标识;非微软凭据返回空串,与旧 `AuthCredential.xuid` 语义一致。
    var microsoftXuid: String {
        guard authMethod == .microsoft else { return "" }
        return xuid ?? ""
    }

    /// 钥匙串 account 索引:`{authMethod}.{userId}` 复合键。
    var keychainAccount: String {
        Self.keychainAccount(userId: userId, authMethod: authMethod)
    }

    static func keychainAccount(userId: String, authMethod: AccountAuthMethod) -> String {
        "\(authMethod.rawValue).\(userId)"
    }
}
