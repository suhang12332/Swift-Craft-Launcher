import XCTest
@testable import SwiftCraftLauncher

final class YggdrasilModelsTests: XCTestCase {

    // MARK: - YggdrasilProfileParserID

    func testParserID_rawValues() {
        XCTAssertEqual(YggdrasilProfileParserID.littleskin.rawValue, "littleskin")
        XCTAssertEqual(YggdrasilProfileParserID.mua.rawValue, "mua")
        XCTAssertEqual(YggdrasilProfileParserID.ely.rawValue, "ely")
    }

    func testParserID_allCases() {
        XCTAssertEqual(YggdrasilProfileParserID.allCases.count, 3)
    }

    func testParserID_id() {
        XCTAssertEqual(YggdrasilProfileParserID.littleskin.id, "littleskin")
        XCTAssertEqual(YggdrasilProfileParserID.mua.id, "mua")
        XCTAssertEqual(YggdrasilProfileParserID.ely.id, "ely")
    }

    func testParserID_codable_roundTrip() throws {
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        for parserID in YggdrasilProfileParserID.allCases {
            let data = try enc.encode(parserID)
            let decoded = try dec.decode(YggdrasilProfileParserID.self, from: data)
            XCTAssertEqual(decoded, parserID)
        }
    }

    // MARK: - YggdrasilServerConfig

    func testServerConfig_init_defaults() {
        let config = YggdrasilServerConfig(
            baseURL: URL(string: "https://littleskin.cn")!,
            redirectURI: "https://example.com/callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "openid",
            parserId: .littleskin
        )

        XCTAssertNil(config.name)
        XCTAssertNil(config.clientId)
        XCTAssertNil(config.clientSecret)
        XCTAssertEqual(config.scope, "openid")
    }

    func testServerConfig_init_allParams() {
        let config = YggdrasilServerConfig(
            name: "LittleSkin",
            baseURL: URL(string: "https://littleskin.cn")!,
            clientId: "1181",
            clientSecret: "secret",
            redirectURI: "https://example.com/callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "openid",
            parserId: .littleskin
        )

        XCTAssertEqual(config.name, "LittleSkin")
        XCTAssertEqual(config.clientId, "1181")
        XCTAssertEqual(config.clientSecret, "secret")
        XCTAssertEqual(config.parserId, .littleskin)
    }

    func testServerConfig_scope_trimsWhitespace() {
        let config = YggdrasilServerConfig(
            baseURL: URL(string: "https://example.com")!,
            redirectURI: "https://example.com/callback",
            authorizePath: "/auth",
            tokenPath: "/token",
            profilePath: "/profile",
            scope: "  openid  ",
            parserId: .mua
        )

        XCTAssertEqual(config.scope, "openid")
    }

    func testServerConfig_authorizeURL() {
        let config = YggdrasilServerConfig(
            baseURL: URL(string: "https://littleskin.cn")!,
            redirectURI: "https://example.com/callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "openid",
            parserId: .littleskin
        )

        let url = config.authorizeURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("/oauth/authorize"))
    }

    func testServerConfig_tokenURL() {
        let config = YggdrasilServerConfig(
            baseURL: URL(string: "https://littleskin.cn")!,
            redirectURI: "https://example.com/callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "openid",
            parserId: .littleskin
        )

        let url = config.tokenURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("/oauth/token"))
    }

    func testServerConfig_profileURL() {
        let config = YggdrasilServerConfig(
            baseURL: URL(string: "https://littleskin.cn")!,
            redirectURI: "https://example.com/callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "openid",
            parserId: .littleskin
        )

        let url = config.profileURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("/api/profile"))
    }

    func testServerConfig_equatable() {
        let a = YggdrasilServerConfig(
            baseURL: URL(string: "https://a.com")!,
            redirectURI: "r",
            authorizePath: "/a",
            tokenPath: "/t",
            profilePath: "/p",
            scope: "s",
            parserId: .littleskin
        )
        let b = YggdrasilServerConfig(
            baseURL: URL(string: "https://a.com")!,
            redirectURI: "r",
            authorizePath: "/a",
            tokenPath: "/t",
            profilePath: "/p",
            scope: "s",
            parserId: .littleskin
        )
        let c = YggdrasilServerConfig(
            baseURL: URL(string: "https://b.com")!,
            redirectURI: "r",
            authorizePath: "/a",
            tokenPath: "/t",
            profilePath: "/p",
            scope: "s",
            parserId: .littleskin
        )

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testServerConfig_codable_roundTrip() throws {
        let original = YggdrasilServerConfig(
            name: "Test",
            baseURL: URL(string: "https://test.com")!,
            clientId: "id",
            clientSecret: "secret",
            redirectURI: "https://test.com/callback",
            authorizePath: "/auth",
            tokenPath: "/token",
            profilePath: "/profile",
            scope: "openid",
            parserId: .ely
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YggdrasilServerConfig.self, from: data)

        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.clientId, "id")
        XCTAssertEqual(decoded.parserId, .ely)
    }

    func testServerConfig_hashable() {
        let a = YggdrasilServerConfig(
            baseURL: URL(string: "https://a.com")!,
            redirectURI: "r",
            authorizePath: "/a",
            tokenPath: "/t",
            profilePath: "/p",
            scope: "s",
            parserId: .littleskin
        )
        let b = a
        var set = Set<YggdrasilServerConfig>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - YggdrasilProfile

    func testYggdrasilProfile_codable_roundTrip() throws {
        let original = YggdrasilProfile(
            id: "uuid-123",
            name: "TestPlayer",
            skins: [],
            capes: nil,
            accessToken: "token123",
            refreshToken: "refresh456",
            serverBaseURL: "https://littleskin.cn"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YggdrasilProfile.self, from: data)

        XCTAssertEqual(decoded.id, "uuid-123")
        XCTAssertEqual(decoded.name, "TestPlayer")
        XCTAssertEqual(decoded.accessToken, "token123")
        XCTAssertEqual(decoded.serverBaseURL, "https://littleskin.cn")
    }

    func testYggdrasilProfile_equatable() {
        let a = YggdrasilProfile(
            id: "id", name: "A", skins: [], capes: nil,
            accessToken: "at", refreshToken: "rt", serverBaseURL: "url"
        )
        let b = YggdrasilProfile(
            id: "id", name: "A", skins: [], capes: nil,
            accessToken: "at", refreshToken: "rt", serverBaseURL: "url"
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - YggdrasilProfileCandidate

    func testYggdrasilProfileCandidate_equatable() {
        let a = YggdrasilProfileCandidate(id: "id", name: "A", skins: [], capes: nil)
        let b = YggdrasilProfileCandidate(id: "id", name: "A", skins: [], capes: nil)
        let c = YggdrasilProfileCandidate(id: "other", name: "A", skins: [], capes: nil)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - YggdrasilAuthState

    func testAuthState_idle() {
        let state = YggdrasilAuthState.idle
        XCTAssertEqual(state, .idle)
    }

    func testAuthState_waitingForBrowser() {
        let state = YggdrasilAuthState.waitingForBrowser
        XCTAssertEqual(state, .waitingForBrowser)
    }

    func testAuthState_exchangingCode() {
        let state = YggdrasilAuthState.exchangingCode
        XCTAssertEqual(state, .exchangingCode)
    }

    func testAuthState_authenticated() {
        let profile = YggdrasilProfile(
            id: "id", name: "A", skins: [], capes: nil,
            accessToken: "at", refreshToken: "rt", serverBaseURL: "url"
        )
        let state = YggdrasilAuthState.authenticated(profile: profile)
        if case .authenticated(let p) = state {
            XCTAssertEqual(p.id, "id")
        } else {
            XCTFail("Expected authenticated state")
        }
    }

    func testAuthState_failed() {
        let state = YggdrasilAuthState.failed("error message")
        XCTAssertEqual(state, .failed("error message"))
    }

    func testAuthState_notEqual_differentCases() {
        XCTAssertNotEqual(YggdrasilAuthState.idle, YggdrasilAuthState.failed("err"))
        XCTAssertNotEqual(YggdrasilAuthState.waitingForBrowser, YggdrasilAuthState.exchangingCode)
    }

    // MARK: - YggdrasilServerPresets

    func testPresets_count() {
        XCTAssertEqual(YggdrasilServerPresets.servers.count, 3)
    }

    func testPresets_hasLittleSkin() {
        let names = YggdrasilServerPresets.servers.compactMap { $0.name }
        XCTAssertTrue(names.contains("LittleSkin"))
    }

    func testPresets_hasMua() {
        let names = YggdrasilServerPresets.servers.compactMap { $0.name }
        XCTAssertTrue(names.contains("Mua"))
    }

    func testPresets_hasEly() {
        let names = YggdrasilServerPresets.servers.compactMap { $0.name }
        XCTAssertTrue(names.contains("Ely.By"))
    }

    func testPresets_parserIds() {
        let parserIds = YggdrasilServerPresets.servers.map { $0.parserId }
        XCTAssertTrue(parserIds.contains(.littleskin))
        XCTAssertTrue(parserIds.contains(.mua))
        XCTAssertTrue(parserIds.contains(.ely))
    }
}
