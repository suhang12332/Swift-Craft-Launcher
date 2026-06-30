//
//  MinecraftAuthTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftAuthTests: XCTestCase {
    func testAuthorizationCodeResponse_success() {
        let url = URL.require("swift-craft-launcher://callback?code=abc123")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.code, "abc123")
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.isSuccess, true)
    }

    func testAuthorizationCodeResponse_userDenied() {
        let url = URL.require("swift-craft-launcher://callback?error=access_denied")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertNil(response?.code)
        XCTAssertEqual(response?.error, "access_denied")
        XCTAssertEqual(response?.isUserDenied, true)
    }

    func testAuthorizationCodeResponse_errorWithDescription() {
        let url = URL.require("swift-craft-launcher://callback?error=server_error&error_description=Something%20went%20wrong")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.error, "server_error")
        XCTAssertNotNil(response?.errorDescription)
    }

    func testAuthorizationCodeResponse_noQueryParams() {
        let url = URL.require("swift-craft-launcher://callback?dummy=value")
        let response = AuthorizationCodeResponse(from: url)

        XCTAssertNotNil(response)
        XCTAssertNotEqual(response?.isSuccess, true)
    }

    func testTokenResponse_codable() throws {
        let json = """
        {"access_token": "at123", "refresh_token": "rt456"}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)

        XCTAssertEqual(decoded.accessToken, "at123")
        XCTAssertEqual(decoded.refreshToken, "rt456")
    }

    func testTokenResponse_codable_nilRefreshToken() throws {
        let json = """
        {"access_token": "at123"}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)

        XCTAssertEqual(decoded.accessToken, "at123")
        XCTAssertNil(decoded.refreshToken)
    }

    func testTokenResponse_roundTrip() throws {
        let original = TokenResponse(accessToken: "token", refreshToken: "refresh")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: encoded)

        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.refreshToken, original.refreshToken)
    }

    func testXboxLiveTokenResponse_codable() throws {
        let json = """
        {
            "Token": "xbox-token",
            "DisplayClaims": {
                "xui": [{"uhs": "user-hash"}]
            }
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: data)

        XCTAssertEqual(decoded.token, "xbox-token")
        XCTAssertEqual(decoded.displayClaims.xui.first?.uhs, "user-hash")
    }

    func testMinecraftProfileResponse_codable() throws {
        let json = """
        {
            "id": "player-uuid",
            "name": "TestPlayer",
            "skins": [{"state": "ACTIVE", "url": "https://example.com/skin.png", "variant": "classic"}],
            "capes": [{"id": "cape-1", "state": "ACTIVE", "url": "https://example.com/cape.png", "alias": "Minecon"}]
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)

        XCTAssertEqual(decoded.id, "player-uuid")
        XCTAssertEqual(decoded.name, "TestPlayer")
        XCTAssertEqual(decoded.skins.count, 1)
        XCTAssertEqual(decoded.capes?.count, 1)
        XCTAssertEqual(decoded.accessToken, "")
    }

    func testMinecraftProfileResponse_noCapes() throws {
        let json = """
        {
            "id": "uuid",
            "name": "Player",
            "skins": []
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)

        XCTAssertNil(decoded.capes)
    }

    func testSkin_equatable() {
        let skin1 = Skin(state: "ACTIVE", url: "url", variant: "classic")
        let skin2 = Skin(state: "ACTIVE", url: "url", variant: "classic")
        let skin3 = Skin(state: "INACTIVE", url: "url", variant: "classic")

        XCTAssertEqual(skin1, skin2)
        XCTAssertNotEqual(skin1, skin3)
    }

    func testMinecraftEntitlement_displayName() {
        XCTAssertEqual(MinecraftEntitlement.productMinecraft.displayName, "Minecraft Product License")
        XCTAssertEqual(MinecraftEntitlement.gameMinecraft.displayName, "Minecraft Game License")
    }

    func testAuthenticationState_equatable() {
        XCTAssertEqual(AuthenticationState.notAuthenticated, AuthenticationState.notAuthenticated)
        XCTAssertEqual(AuthenticationState.waitingForBrowserAuth, AuthenticationState.waitingForBrowserAuth)
        XCTAssertNotEqual(AuthenticationState.notAuthenticated, AuthenticationState.processingAuthCode)
    }
}
