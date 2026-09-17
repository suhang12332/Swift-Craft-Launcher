//
//  PlayerAuthTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class PlayerAuthTests: XCTestCase {
    // MARK: - AccountCredential Codable

    func testAccountCredential_codable_roundtrip() throws {
        let credential = AccountCredential(
            userId: "u1",
            authMethod: .microsoft,
            accessToken: "access",
            renewalSecret: "refresh",
            xuid: "xuid-123",
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AccountCredential.self, from: encoded)

        XCTAssertEqual(decoded, credential)
    }

    func testAccountCredential_codable_optionalFieldsDefaultToNil() throws {
        let credential = AccountCredential(
            userId: "u2",
            authMethod: .yggdrasilPassword,
            accessToken: "at",
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AccountCredential.self, from: encoded)

        XCTAssertNil(decoded.renewalSecret)
        XCTAssertNil(decoded.clientToken)
        XCTAssertNil(decoded.loginUsername)
        XCTAssertNil(decoded.xuid)
    }

    func testAccountCredential_codable_specialCharacters() throws {
        let credential = AccountCredential(
            userId: "user/with=special&chars",
            authMethod: .yggdrasilOAuth,
            accessToken: "at+with/special=chars",
            renewalSecret: "rt&with%special",
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AccountCredential.self, from: encoded)

        XCTAssertEqual(decoded.userId, "user/with=special&chars")
        XCTAssertEqual(decoded.accessToken, "at+with/special=chars")
        XCTAssertEqual(decoded.oauthRefreshToken, "rt&with%special")
    }

    // MARK: - AccountCredential 错形访问防护

    func testAccountCredential_oauthRefreshToken_shapeGuard() {
        let ms = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "a", renewalSecret: "r")
        let yggOAuth = AccountCredential(userId: "u", authMethod: .yggdrasilOAuth, accessToken: "a", renewalSecret: "r")
        let yggPassword = AccountCredential(userId: "u", authMethod: .yggdrasilPassword, accessToken: "a", renewalSecret: "p")

        XCTAssertEqual(ms.oauthRefreshToken, "r")
        XCTAssertEqual(yggOAuth.oauthRefreshToken, "r")
        XCTAssertNil(yggPassword.oauthRefreshToken)
        XCTAssertEqual(yggPassword.savedPassword, "p")
        XCTAssertNil(ms.savedPassword)
        XCTAssertNil(yggOAuth.savedPassword)
    }

    func testAccountCredential_microsoftXuid_shapeGuard() {
        let ms = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "a", xuid: "x1")
        let ygg = AccountCredential(userId: "u", authMethod: .yggdrasilOAuth, accessToken: "a", xuid: "x1")

        XCTAssertEqual(ms.microsoftXuid, "x1")
        // 非微软凭据即使误存了 xuid 也不外泄
        XCTAssertEqual(ygg.microsoftXuid, "")
    }

    // MARK: - AccountCredential 钥匙串复合索引

    func testAccountCredential_keychainAccount_namespacesByAuthMethod() {
        let ms = AccountCredential.keychainAccount(userId: "uuid-1", authMethod: .microsoft)
        let ygg = AccountCredential.keychainAccount(userId: "uuid-1", authMethod: .yggdrasilOAuth)

        XCTAssertEqual(ms, "microsoft.uuid-1")
        XCTAssertEqual(ygg, "yggdrasilOAuth.uuid-1")
        XCTAssertNotEqual(ms, ygg)
    }

    // MARK: - AccountCredential 相等性

    func testAccountCredential_notEqual_differentUserId() {
        let a = AccountCredential(userId: "a", authMethod: .microsoft, accessToken: "t", renewalSecret: "r")
        let b = AccountCredential(userId: "b", authMethod: .microsoft, accessToken: "t", renewalSecret: "r")
        XCTAssertNotEqual(a, b)
    }

    func testAccountCredential_notEqual_differentAccessToken() {
        let a = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "1")
        let b = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "2")
        XCTAssertNotEqual(a, b)
    }

    func testAccountCredential_notEqual_differentRenewalSecret() {
        let a = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "t", renewalSecret: "1")
        let b = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "t", renewalSecret: "2")
        XCTAssertNotEqual(a, b)
    }

    func testAccountCredential_notEqual_differentXuid() {
        let a = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "t", renewalSecret: "r", xuid: "x1")
        let b = AccountCredential(userId: "u", authMethod: .microsoft, accessToken: "t", renewalSecret: "r", xuid: "x2")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Player 认证语义

    func testPlayer_microsoftAccount_isOnline() {
        let profile = UserProfile(id: "uuid-1", name: "OnlinePlayer", avatar: "https://example.com/skin.png", authMethod: .microsoft)
        let credential = AccountCredential(userId: "uuid-1", authMethod: .microsoft, accessToken: "token123", renewalSecret: "refresh456", xuid: "xuid-abc")
        let player = Player(profile: profile, credential: credential)

        XCTAssertTrue(player.isOnlineAccount)
        XCTAssertFalse(player.isYggdrasilAccount)
        XCTAssertTrue(player.isRemote)
        XCTAssertEqual(player.authAccessToken, "token123")
        XCTAssertEqual(player.authRefreshToken, "refresh456")
        XCTAssertEqual(player.authXuid, "xuid-abc")
    }

    func testPlayer_offlineAccount_noCredential() {
        let profile = UserProfile(id: "uuid-2", name: "OfflinePlayer", avatar: "steve")
        let player = Player(profile: profile, credential: nil)

        XCTAssertFalse(player.isOnlineAccount)
        XCTAssertFalse(player.isYggdrasilAccount)
        XCTAssertNil(player.authMethod)
        XCTAssertEqual(player.authAccessToken, "")
        XCTAssertEqual(player.authRefreshToken, "")
        XCTAssertEqual(player.authXuid, "")
    }

    func testPlayer_yggdrasilOAuthAccount_isNotMicrosoftOnline() {
        let profile = UserProfile(
            id: "uuid-3",
            name: "YggPlayer",
            avatar: "https://example.com/skin.png",
            authMethod: .yggdrasilOAuth,
            yggdrasilServerBaseURL: "https://littleskin.cn",
        )
        let credential = AccountCredential(
            userId: "uuid-3",
            authMethod: .yggdrasilOAuth,
            accessToken: "ygg-token",
            renewalSecret: "ygg-refresh",
        )
        let player = Player(profile: profile, credential: credential)

        XCTAssertFalse(player.isOnlineAccount, "Yggdrasil 账号不应触发微软令牌刷新链")
        XCTAssertTrue(player.isYggdrasilAccount)
        XCTAssertEqual(player.authAccessToken, "ygg-token")
        XCTAssertEqual(player.authRefreshToken, "ygg-refresh")
        XCTAssertEqual(player.authXuid, "", "Yggdrasil 账号不应有 XUID")
        XCTAssertEqual(player.yggdrasilServerBaseURL, "https://littleskin.cn")
    }

    func testPlayer_yggdrasilPasswordAccount_isNotMicrosoftOnline() {
        let profile = UserProfile(id: "uuid-4", name: "CustomServerPlayer", avatar: "steve", authMethod: .yggdrasilPassword)
        let credential = AccountCredential(
            userId: "uuid-4",
            authMethod: .yggdrasilPassword,
            accessToken: "classic-token",
            renewalSecret: nil,
            clientToken: "client-token",
            loginUsername: "user@example.com",
        )
        let player = Player(profile: profile, credential: credential)

        XCTAssertFalse(player.isOnlineAccount)
        XCTAssertTrue(player.isYggdrasilAccount)
        XCTAssertEqual(player.authAccessToken, "classic-token")
        XCTAssertEqual(player.authRefreshToken, "", "密码登录无 OAuth refresh_token")
    }

    func testPlayer_isRemote_httpPrefix() {
        let profile = UserProfile(id: "1", name: "Http", avatar: "http://example.com/skin.png")
        let player = Player(profile: profile)
        XCTAssertTrue(player.isRemote)
    }
}
