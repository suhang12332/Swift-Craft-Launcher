import XCTest
@testable import SwiftCraftLauncher

final class PlayerAuthTests: XCTestCase {

    // MARK: - AuthCredential Codable Edge Cases

    func testAuthCredential_codable_nilExpiresAt() throws {
        let credential = AuthCredential(
            userId: "u1",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: nil,
            xuid: ""
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertEqual(decoded.userId, "u1")
        XCTAssertNil(decoded.expiresAt)
        XCTAssertEqual(decoded.xuid, "")
    }

    func testAuthCredential_codable_emptyTokens() throws {
        let credential = AuthCredential(
            userId: "u2",
            accessToken: "",
            refreshToken: "",
            expiresAt: nil,
            xuid: ""
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertEqual(decoded.accessToken, "")
        XCTAssertEqual(decoded.refreshToken, "")
    }

    func testAuthCredential_codable_specialCharacters() throws {
        let credential = AuthCredential(
            userId: "user/with=special&chars",
            accessToken: "at+with/special=chars",
            refreshToken: "rt&with%special",
            expiresAt: nil,
            xuid: "xuid-123"
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertEqual(decoded.userId, "user/with=special&chars")
        XCTAssertEqual(decoded.accessToken, "at+with/special=chars")
        XCTAssertEqual(decoded.refreshToken, "rt&with%special")
    }

    func testAuthCredential_codable_futureDate() throws {
        let futureDate = Date(timeIntervalSince1970: 4102444800) // 2100-01-01
        let credential = AuthCredential(
            userId: "u",
            accessToken: "at",
            refreshToken: "rt",
            expiresAt: futureDate,
            xuid: ""
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertNotNil(decoded.expiresAt)
        XCTAssertEqual(decoded.expiresAt!.timeIntervalSince1970, futureDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testAuthCredential_codable_pastDate() throws {
        let pastDate = Date(timeIntervalSince1970: 0)
        let credential = AuthCredential(
            userId: "u",
            accessToken: "at",
            refreshToken: "rt",
            expiresAt: pastDate,
            xuid: ""
        )

        let encoded = try JSONEncoder().encode(credential)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertEqual(decoded.expiresAt, pastDate)
    }

    // MARK: - AuthCredential Equatable

    func testAuthCredential_notEqual_differentUserId() {
        let a = AuthCredential(userId: "a", accessToken: "t", refreshToken: "r")
        let b = AuthCredential(userId: "b", accessToken: "t", refreshToken: "r")
        XCTAssertNotEqual(a, b)
    }

    func testAuthCredential_notEqual_differentAccessToken() {
        let a = AuthCredential(userId: "u", accessToken: "1", refreshToken: "r")
        let b = AuthCredential(userId: "u", accessToken: "2", refreshToken: "r")
        XCTAssertNotEqual(a, b)
    }

    func testAuthCredential_notEqual_differentRefreshToken() {
        let a = AuthCredential(userId: "u", accessToken: "t", refreshToken: "1")
        let b = AuthCredential(userId: "u", accessToken: "t", refreshToken: "2")
        XCTAssertNotEqual(a, b)
    }

    func testAuthCredential_notEqual_differentXuid() {
        let a = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", xuid: "x1")
        let b = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", xuid: "x2")
        XCTAssertNotEqual(a, b)
    }

    func testAuthCredential_notEqual_differentExpiresAt() {
        let a = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 0))
        let b = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 1000))
        XCTAssertNotEqual(a, b)
    }

    func testAuthCredential_notEqual_nilVsNonNilExpiresAt() {
        let a = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", expiresAt: nil)
        let b = AuthCredential(userId: "u", accessToken: "t", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 0))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Player with Auth Credential

    func testPlayer_onlineAccount_withCredential() {
        let profile = UserProfile(id: "uuid-1", name: "OnlinePlayer", avatar: "https://example.com/skin.png")
        let credential = AuthCredential(userId: "uuid-1", accessToken: "token123", refreshToken: "refresh456", xuid: "xuid-abc")
        let player = Player(profile: profile, credential: credential)

        XCTAssertTrue(player.isOnlineAccount)
        XCTAssertTrue(player.isRemote)
        XCTAssertEqual(player.authAccessToken, "token123")
        XCTAssertEqual(player.authRefreshToken, "refresh456")
        XCTAssertEqual(player.authXuid, "xuid-abc")
    }

    func testPlayer_offlineAccount_noCredential() {
        let profile = UserProfile(id: "uuid-2", name: "OfflinePlayer", avatar: "steve")
        let player = Player(profile: profile, credential: nil)

        XCTAssertFalse(player.isOnlineAccount)
        XCTAssertFalse(player.isRemote)
        XCTAssertEqual(player.authAccessToken, "")
        XCTAssertEqual(player.authRefreshToken, "")
        XCTAssertEqual(player.authXuid, "")
    }

    func testPlayer_onlineAccount_remoteAvatar_noCredential_noServerMap() {
        let profile = UserProfile(id: "uuid-3", name: "RemoteNoCred", avatar: "https://example.com/avatar.png")
        let player = Player(profile: profile, credential: nil)

        // Remote avatar with no server map entry → considered online account
        XCTAssertTrue(player.isOnlineAccount)
    }

    func testPlayer_offlineAccount_remoteAvatar_withServerMap() {
        let profile = UserProfile(id: "uuid-4", name: "OfflineThirdParty", avatar: "https://example.com/skin.png")
        let player = Player(profile: profile, credential: nil)

        // Simulate offline third-party server mapping
        OfflineUserServerMap.setServer("yggdrasil-server", for: "uuid-4")

        // With server map entry, remote avatar player is NOT considered online
        XCTAssertFalse(player.isOnlineAccount)

        // Cleanup
        OfflineUserServerMap.removeServer(for: "uuid-4")
    }

    func testPlayer_isRemote_httpPrefix() {
        let profile = UserProfile(id: "1", name: "Http", avatar: "http://example.com/skin.png")
        let player = Player(profile: profile)
        XCTAssertTrue(player.isRemote)
    }

    func testPlayer_isRemote_httpsPrefix() {
        let profile = UserProfile(id: "1", name: "Https", avatar: "https://example.com/skin.png")
        let player = Player(profile: profile)
        XCTAssertTrue(player.isRemote)
    }

    func testPlayer_isRemote_localPath() {
        let profile = UserProfile(id: "1", name: "Local", avatar: "steve")
        let player = Player(profile: profile)
        XCTAssertFalse(player.isRemote)
    }

    func testPlayer_isRemote_relativePath() {
        let profile = UserProfile(id: "1", name: "Relative", avatar: "skins/alex.png")
        let player = Player(profile: profile)
        XCTAssertFalse(player.isRemote)
    }

    func testPlayer_isCurrent_toggle() {
        let profile = UserProfile(id: "id", name: "P", avatar: "steve")
        var player = Player(profile: profile)
        XCTAssertFalse(player.isCurrent)

        player.isCurrent = true
        XCTAssertTrue(player.isCurrent)

        player.isCurrent = false
        XCTAssertFalse(player.isCurrent)
    }

    func testPlayer_lastPlayed_settable() {
        let profile = UserProfile(id: "id", name: "P", avatar: "steve")
        var player = Player(profile: profile)
        let original = player.lastPlayed

        let newDate = Date(timeIntervalSince1970: 999999)
        player.lastPlayed = newDate
        XCTAssertEqual(player.lastPlayed, newDate)
        XCTAssertNotEqual(player.lastPlayed, original)
    }

    // MARK: - Player Convenience Init with Auth

    func testPlayer_convenienceInit_offlineGeneratesUUID() throws {
        let player = try Player(name: "TestAuth")
        XCTAssertNotEqual(player.id, "")
        XCTAssertEqual(player.id.count, 32)
        XCTAssertNil(player.credential)
        XCTAssertFalse(player.isOnlineAccount)
    }

    func testPlayer_convenienceInit_withProvidedUUID() throws {
        let player = try Player(name: "TestUUID", uuid: "custom-uuid-value")
        XCTAssertEqual(player.id, "custom-uuid-value")
    }

    func testPlayer_convenienceInit_offlineDefaultAvatar() throws {
        let player = try Player(name: "DefaultAvatar")
        XCTAssertFalse(player.avatarName.isEmpty)
    }

    func testPlayer_convenienceInit_onlineEmptyAvatar() throws {
        let credential = AuthCredential(userId: "uid", accessToken: "at", refreshToken: "rt")
        let player = try Player(name: "Online", avatar: "https://skin.url/img.png", credential: credential)
        XCTAssertEqual(player.avatarName, "https://skin.url/img.png")
    }

    func testPlayer_convenienceInit_offlineCustomAvatar() throws {
        let player = try Player(name: "Custom", avatar: "alex")
        XCTAssertEqual(player.avatarName, "alex")
    }

    func testPlayer_convenienceInit_isCurrentDefaultFalse() throws {
        let player = try Player(name: "P")
        XCTAssertFalse(player.isCurrent)
    }

    func testPlayer_convenienceInit_isCurrentTrue() throws {
        let player = try Player(name: "P", isCurrent: true)
        XCTAssertTrue(player.isCurrent)
    }

    // MARK: - Player Init with Profile + Credential

    func testPlayer_init_profileAndCredential() {
        let profile = UserProfile(id: "id", name: "Name", avatar: "av")
        let credential = AuthCredential(userId: "id", accessToken: "at", refreshToken: "rt", xuid: "x1")
        let player = Player(profile: profile, credential: credential)

        XCTAssertEqual(player.id, "id")
        XCTAssertEqual(player.name, "Name")
        XCTAssertEqual(player.authXuid, "x1")
        XCTAssertTrue(player.isOnlineAccount)
    }

    func testPlayer_init_profileOnly() {
        let profile = UserProfile(id: "id", name: "Name", avatar: "av")
        let player = Player(profile: profile)

        XCTAssertNil(player.credential)
        XCTAssertFalse(player.isOnlineAccount)
        XCTAssertEqual(player.authAccessToken, "")
    }

    // MARK: - AuthCredential Codable JSON Validation

    func testAuthCredential_codable_jsonStructure() throws {
        let credential = AuthCredential(
            userId: "test-user",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1700000000),
            xuid: "test-xuid"
        )

        let encoded = try JSONEncoder().encode(credential)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["userId"] as? String, "test-user")
        XCTAssertEqual(json?["accessToken"] as? String, "access-token")
        XCTAssertEqual(json?["refreshToken"] as? String, "refresh-token")
        XCTAssertEqual(json?["xuid"] as? String, "test-xuid")
        XCTAssertNotNil(json?["expiresAt"])
    }

    func testAuthCredential_decode_invalidJSON() {
        let invalidJSON = "not valid json".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(AuthCredential.self, from: invalidJSON)
        XCTAssertNil(decoded)
    }

    func testAuthCredential_decode_missingRequiredField() {
        let json = """
        {"userId": "u", "accessToken": "a"}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(AuthCredential.self, from: json)
        XCTAssertNil(decoded)
    }

    func testAuthCredential_decode_emptyJSON() {
        let json = "{}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(AuthCredential.self, from: json)
        XCTAssertNil(decoded)
    }
}
