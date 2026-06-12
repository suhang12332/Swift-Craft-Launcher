import XCTest
@testable import SwiftCraftLauncher

final class MinecraftAuthExtendedTests: XCTestCase {

    // MARK: - AuthorizationCodeResponse Edge Cases

    func testAuthorizationCodeResponse_invalidURL() {
        let response = AuthorizationCodeResponse(from: URL(fileURLWithPath: "/dev/null"))
        XCTAssertNil(response)
    }

    func testAuthorizationCodeResponse_codeAndErrorBothPresent() {
        let url = URL.require("swift-craft-launcher://callback?code=abc&error=some_error")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.code, "abc")
        XCTAssertEqual(response?.error, "some_error")
        XCTAssertFalse(response?.isSuccess ?? true)
        XCTAssertFalse(response?.isUserDenied ?? true)
    }

    func testAuthorizationCodeResponse_emptyCode() {
        let url = URL.require("swift-craft-launcher://callback?code=")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.code, "")
        XCTAssertTrue(response?.isSuccess ?? false)
    }

    func testAuthorizationCodeResponse_percentEncodedDescription() {
        let url = URL.require("swift-craft-launcher://callback?error=err&error_description=Hello%20World%21")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertEqual(response?.errorDescription, "Hello World!")
    }

    func testAuthorizationCodeResponse_nonAccessDeniedError() {
        let url = URL.require("swift-craft-launcher://callback?error=invalid_request")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertEqual(response?.error, "invalid_request")
        XCTAssertFalse(response?.isUserDenied ?? true)
    }

    // MARK: - TokenResponse

    func testTokenResponse_codable_withRefreshToken() throws {
        let json = """
        {"access_token": "at", "refresh_token": "rt"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: json)

        XCTAssertEqual(decoded.accessToken, "at")
        XCTAssertEqual(decoded.refreshToken, "rt")
    }

    func testTokenResponse_codable_withoutRefreshToken() throws {
        let json = """
        {"access_token": "at"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: json)

        XCTAssertEqual(decoded.accessToken, "at")
        XCTAssertNil(decoded.refreshToken)
    }

    func testTokenResponse_codable_invalidJSON() {
        let json = "not json".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(TokenResponse.self, from: json)
        XCTAssertNil(decoded)
    }

    func testTokenResponse_codable_missingAccessToken() {
        let json = """
        {"refresh_token": "rt"}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(TokenResponse.self, from: json)
        XCTAssertNil(decoded)
    }

    // MARK: - XboxLiveTokenResponse

    func testXboxLiveTokenResponse_codable_roundTrip() throws {
        let original = XboxLiveTokenResponse(
            token: "xbox-tok",
            displayClaims: DisplayClaims(xui: [XUI(uhs: "hash1"), XUI(uhs: "hash2")])
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: encoded)

        XCTAssertEqual(decoded.token, "xbox-tok")
        XCTAssertEqual(decoded.displayClaims.xui.count, 2)
        XCTAssertEqual(decoded.displayClaims.xui[0].uhs, "hash1")
        XCTAssertEqual(decoded.displayClaims.xui[1].uhs, "hash2")
    }

    func testXboxLiveTokenResponse_codable_emptyXui() throws {
        let json = """
        {"Token": "tok", "DisplayClaims": {"xui": []}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: json)

        XCTAssertEqual(decoded.token, "tok")
        XCTAssertTrue(decoded.displayClaims.xui.isEmpty)
    }

    // MARK: - MinecraftProfileResponse

    func testMinecraftProfileResponse_codable_withSkinsAndCapes() throws {
        let json = """
        {
            "id": "uuid-123",
            "name": "TestPlayer",
            "skins": [
                {"state": "ACTIVE", "url": "https://example.com/skin1.png", "variant": "classic"},
                {"state": "INACTIVE", "url": "https://example.com/skin2.png", "variant": "slim"}
            ],
            "capes": [
                {"id": "cape-1", "state": "ACTIVE", "url": "https://example.com/cape.png", "alias": "minecon"}
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MinecraftProfileResponse.self, from: json)

        XCTAssertEqual(decoded.id, "uuid-123")
        XCTAssertEqual(decoded.name, "TestPlayer")
        XCTAssertEqual(decoded.skins.count, 2)
        XCTAssertEqual(decoded.skins[0].state, "ACTIVE")
        XCTAssertEqual(decoded.skins[0].variant, "classic")
        XCTAssertEqual(decoded.skins[1].variant, "slim")
        XCTAssertEqual(decoded.capes?.count, 1)
        XCTAssertEqual(decoded.capes?.first?.alias, "minecon")
    }

    func testMinecraftProfileResponse_codable_noSkins() throws {
        let json = """
        {
            "id": "uuid",
            "name": "NoSkin",
            "skins": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MinecraftProfileResponse.self, from: json)

        XCTAssertTrue(decoded.skins.isEmpty)
        XCTAssertNil(decoded.capes)
    }

    func testMinecraftProfileResponse_init_directValues() {
        let skins = [Skin(state: "ACTIVE", url: "url", variant: "classic")]
        let capes = [Cape(id: "c1", state: "ACTIVE", url: "cape-url", alias: nil)]
        let profile = MinecraftProfileResponse(
            id: "id",
            name: "Name",
            skins: skins,
            capes: capes,
            accessToken: "my-token",
            authXuid: "my-xuid",
            refreshToken: "my-refresh"
        )

        XCTAssertEqual(profile.accessToken, "my-token")
        XCTAssertEqual(profile.authXuid, "my-xuid")
        XCTAssertEqual(profile.refreshToken, "my-refresh")
    }

    func testMinecraftProfileResponse_equatable() {
        let skins = [Skin(state: "ACTIVE", url: "url", variant: nil)]
        let a = MinecraftProfileResponse(id: "id", name: "A", skins: skins, capes: nil, accessToken: "", authXuid: "")
        let b = MinecraftProfileResponse(id: "id", name: "A", skins: skins, capes: nil, accessToken: "", authXuid: "")
        let c = MinecraftProfileResponse(id: "id", name: "B", skins: skins, capes: nil, accessToken: "", authXuid: "")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Skin & Cape Equatable

    func testSkin_equatable_allFieldsEqual() {
        let a = Skin(state: "ACTIVE", url: "url", variant: "classic")
        let b = Skin(state: "ACTIVE", url: "url", variant: "classic")
        XCTAssertEqual(a, b)
    }

    func testSkin_equatable_differentState() {
        let a = Skin(state: "ACTIVE", url: "url", variant: nil)
        let b = Skin(state: "INACTIVE", url: "url", variant: nil)
        XCTAssertNotEqual(a, b)
    }

    func testSkin_equatable_differentURL() {
        let a = Skin(state: "ACTIVE", url: "url1", variant: nil)
        let b = Skin(state: "ACTIVE", url: "url2", variant: nil)
        XCTAssertNotEqual(a, b)
    }

    func testSkin_equatable_differentVariant() {
        let a = Skin(state: "ACTIVE", url: "url", variant: "classic")
        let b = Skin(state: "ACTIVE", url: "url", variant: "slim")
        XCTAssertNotEqual(a, b)
    }

    func testCape_equatable() {
        let a = Cape(id: "c1", state: "ACTIVE", url: "url", alias: "minecon")
        let b = Cape(id: "c1", state: "ACTIVE", url: "url", alias: "minecon")
        let c = Cape(id: "c2", state: "ACTIVE", url: "url", alias: nil)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCape_equatable_differentAlias() {
        let a = Cape(id: "c1", state: "ACTIVE", url: "url", alias: "alias1")
        let b = Cape(id: "c1", state: "ACTIVE", url: "url", alias: "alias2")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - MinecraftEntitlement

    func testMinecraftEntitlement_allCases() {
        XCTAssertEqual(MinecraftEntitlement.allCases.count, 2)
    }

    func testMinecraftEntitlement_rawValues() {
        XCTAssertEqual(MinecraftEntitlement.productMinecraft.rawValue, "product_minecraft")
        XCTAssertEqual(MinecraftEntitlement.gameMinecraft.rawValue, "game_minecraft")
    }

    func testMinecraftEntitlement_initFromRawValue() {
        XCTAssertEqual(MinecraftEntitlement(rawValue: "product_minecraft"), .productMinecraft)
        XCTAssertEqual(MinecraftEntitlement(rawValue: "game_minecraft"), .gameMinecraft)
        XCTAssertNil(MinecraftEntitlement(rawValue: "invalid"))
    }

    // MARK: - MinecraftEntitlementsResponse

    func testMinecraftEntitlementsResponse_codable() throws {
        let json = """
        {
            "items": [
                {"name": "product_minecraft", "signature": "sig1"},
                {"name": "game_minecraft", "signature": "sig2"}
            ],
            "signature": "main-sig",
            "keyId": "key-1"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MinecraftEntitlementsResponse.self, from: json)

        XCTAssertEqual(decoded.items.count, 2)
        XCTAssertEqual(decoded.items[0].name, "product_minecraft")
        XCTAssertEqual(decoded.signature, "main-sig")
        XCTAssertEqual(decoded.keyId, "key-1")
    }

    func testMinecraftEntitlementsResponse_emptyItems() throws {
        let json = """
        {"items": [], "signature": "sig", "keyId": "k"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MinecraftEntitlementsResponse.self, from: json)
        XCTAssertTrue(decoded.items.isEmpty)
    }

    // MARK: - AuthenticationState

    func testAuthenticationState_allDistinct() {
        let states: [AuthenticationState] = [
            .notAuthenticated,
            .waitingForBrowserAuth,
            .processingAuthCode,
            .error("err"),
        ]

        for i in 0..<states.count {
            for j in (i + 1)..<states.count {
                XCTAssertNotEqual(states[i], states[j])
            }
        }
    }

    func testAuthenticationState_error_sameMessage() {
        XCTAssertEqual(
            AuthenticationState.error("same"),
            AuthenticationState.error("same")
        )
    }

    func testAuthenticationState_error_differentMessage() {
        XCTAssertNotEqual(
            AuthenticationState.error("a"),
            AuthenticationState.error("b")
        )
    }

    func testAuthenticationState_authenticated_equatable() {
        let profile1 = MinecraftProfileResponse(
            id: "id", name: "A", skins: [], capes: nil,
            accessToken: "", authXuid: ""
        )
        let profile2 = MinecraftProfileResponse(
            id: "id", name: "A", skins: [], capes: nil,
            accessToken: "", authXuid: ""
        )

        XCTAssertEqual(
            AuthenticationState.authenticated(profile: profile1),
            AuthenticationState.authenticated(profile: profile2)
        )
    }

    func testAuthenticationState_authenticated_notEqual_differentProfile() {
        let profile1 = MinecraftProfileResponse(
            id: "id1", name: "A", skins: [], capes: nil,
            accessToken: "", authXuid: ""
        )
        let profile2 = MinecraftProfileResponse(
            id: "id2", name: "B", skins: [], capes: nil,
            accessToken: "", authXuid: ""
        )

        XCTAssertNotEqual(
            AuthenticationState.authenticated(profile: profile1),
            AuthenticationState.authenticated(profile: profile2)
        )
    }
}
