import XCTest
@testable import SwiftCraftLauncher

final class CommonFeatureModelsTests: XCTestCase {

    // MARK: - AuthCredential

    func testAuthCredential_init_defaults() {
        let credential = AuthCredential(
            userId: "user-1",
            accessToken: "at",
            refreshToken: "rt"
        )

        XCTAssertEqual(credential.userId, "user-1")
        XCTAssertEqual(credential.accessToken, "at")
        XCTAssertEqual(credential.refreshToken, "rt")
        XCTAssertNil(credential.expiresAt)
        XCTAssertEqual(credential.xuid, "")
    }

    func testAuthCredential_init_allParams() {
        let date = Date()
        let credential = AuthCredential(
            userId: "user-2",
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: date,
            xuid: "xbox-id"
        )

        XCTAssertEqual(credential.userId, "user-2")
        XCTAssertEqual(credential.accessToken, "token")
        XCTAssertEqual(credential.refreshToken, "refresh")
        XCTAssertEqual(credential.expiresAt, date)
        XCTAssertEqual(credential.xuid, "xbox-id")
    }

    func testAuthCredential_equatable() {
        let a = AuthCredential(userId: "u", accessToken: "a", refreshToken: "r")
        let b = AuthCredential(userId: "u", accessToken: "a", refreshToken: "r")
        let c = AuthCredential(userId: "u", accessToken: "different", refreshToken: "r")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testAuthCredential_codable_roundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let original = AuthCredential(
            userId: "uid",
            accessToken: "at123",
            refreshToken: "rt456",
            expiresAt: date,
            xuid: "xuid789"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)

        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.refreshToken, original.refreshToken)
        XCTAssertEqual(decoded.xuid, original.xuid)
    }

    // MARK: - UserProfile

    func testUserProfile_init_defaults() {
        let profile = UserProfile(id: "id-1", name: "Steve", avatar: "steve")

        XCTAssertEqual(profile.id, "id-1")
        XCTAssertEqual(profile.name, "Steve")
        XCTAssertEqual(profile.avatar, "steve")
        XCTAssertFalse(profile.isCurrent)
        XCTAssertNotNil(profile.lastPlayed)
    }

    func testUserProfile_init_allParams() {
        let date = Date(timeIntervalSince1970: 1000)
        let profile = UserProfile(id: "id-2", name: "Alex", avatar: "alex", lastPlayed: date, isCurrent: true)

        XCTAssertEqual(profile.isCurrent, true)
        XCTAssertEqual(profile.lastPlayed, date)
    }

    func testUserProfile_equatable() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = UserProfile(id: "id", name: "A", avatar: "av", lastPlayed: date)
        let b = UserProfile(id: "id", name: "A", avatar: "av", lastPlayed: date)
        let c = UserProfile(id: "id", name: "B", avatar: "av", lastPlayed: date)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testUserProfile_codable_roundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let original = UserProfile(id: "uid", name: "Player", avatar: "skin.png", lastPlayed: date, isCurrent: true)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.avatar, original.avatar)
        XCTAssertEqual(decoded.isCurrent, original.isCurrent)
    }

    // MARK: - IPLocationResponse

    func testIPLocationResponse_success() throws {
        let json = """
        {"country_code": "US", "error": false}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(IPLocationResponse.self, from: data)

        XCTAssertEqual(response.countryCode, "US")
        XCTAssertFalse(response.error)
        XCTAssertTrue(response.isSuccess)
        XCTAssertFalse(response.isChina)
        XCTAssertTrue(response.isForeign)
    }

    func testIPLocationResponse_china() throws {
        let json = """
        {"country_code": "CN", "error": false}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(IPLocationResponse.self, from: data)

        XCTAssertTrue(response.isChina)
        XCTAssertFalse(response.isForeign)
        XCTAssertTrue(response.isSuccess)
    }

    func testIPLocationResponse_error() throws {
        let json = """
        {"error": true, "reason": "Rate limited"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(IPLocationResponse.self, from: data)

        XCTAssertTrue(response.error)
        XCTAssertFalse(response.isSuccess)
        XCTAssertFalse(response.isChina)
        XCTAssertFalse(response.isForeign)
        XCTAssertEqual(response.reason, "Rate limited")
    }

    func testIPLocationResponse_missingFields() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(IPLocationResponse.self, from: data)

        XCTAssertNil(response.countryCode)
        XCTAssertFalse(response.error)
        XCTAssertFalse(response.isSuccess)
    }

    // MARK: - GitHubContributor

    func testGitHubContributor_codable() throws {
        let json = """
        {
            "id": 123,
            "login": "suhang",
            "avatar_url": "https://example.com/avatar.png",
            "html_url": "https://github.com/suhang",
            "contributions": 42
        }
        """
        let data = json.data(using: .utf8)!
        let contributor = try JSONDecoder().decode(GitHubContributor.self, from: data)

        XCTAssertEqual(contributor.id, 123)
        XCTAssertEqual(contributor.login, "suhang")
        XCTAssertEqual(contributor.avatarUrl, "https://example.com/avatar.png")
        XCTAssertEqual(contributor.htmlUrl, "https://github.com/suhang")
        XCTAssertEqual(contributor.contributions, 42)
    }

    func testGitHubContributor_codable_roundTrip() throws {
        let original = GitHubContributor(
            id: 1,
            login: "test",
            avatarUrl: "https://example.com/a.png",
            htmlUrl: "https://github.com/test",
            contributions: 10
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GitHubContributor.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.login, original.login)
    }

    // MARK: - GitHubRelease

    func testGitHubRelease_codable() throws {
        let json = """
        {"tag_name": "v1.0.0"}
        """
        let data = json.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        XCTAssertEqual(release.tagName, "v1.0.0")
    }

    func testGitHubRelease_codable_roundTrip() throws {
        let original = GitHubRelease(tagName: "v2.1.0")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GitHubRelease.self, from: encoded)

        XCTAssertEqual(decoded.tagName, original.tagName)
    }
}
