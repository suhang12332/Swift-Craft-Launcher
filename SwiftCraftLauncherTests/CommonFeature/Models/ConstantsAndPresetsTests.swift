import XCTest
@testable import SwiftCraftLauncher

final class ConstantsAndPresetsTests: XCTestCase {

    // MARK: - YggdrasilServerPresets

    func testYggdrasilServerPresets_hasThreeServers() {
        XCTAssertEqual(Self.makeTestServers().count, 3)
    }

    func testYggdrasilServerPresets_littleSkin() {
        let littleSkin = Self.makeTestServers().first { $0.name == "LittleSkin" }
        XCTAssertNotNil(littleSkin)
        XCTAssertEqual(littleSkin?.clientId, "1181")
        XCTAssertEqual(littleSkin?.parserId, .littleskin)
        XCTAssertEqual(littleSkin?.scope, "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read")
    }

    func testYggdrasilServerPresets_mua() {
        let mua = Self.makeTestServers().first { $0.name == "Mua" }
        XCTAssertNotNil(mua)
        XCTAssertEqual(mua?.clientId, "34")
        XCTAssertEqual(mua?.parserId, .mua)
    }

    func testYggdrasilServerPresets_ely() {
        let ely = Self.makeTestServers().first { $0.name == "Ely.By" }
        XCTAssertNotNil(ely)
        XCTAssertEqual(ely?.clientId, "swift-craft-launcher")
        XCTAssertEqual(ely?.parserId, .ely)
    }

    func testYggdrasilServerPresets_allHaveRedirectURI() {
        for server in Self.makeTestServers() {
            XCTAssertFalse(server.redirectURI.isEmpty, "\(server.name) should have redirectURI")
            XCTAssertFalse(server.authorizePath.isEmpty, "\(server.name) should have authorizePath")
            XCTAssertFalse(server.tokenPath.isEmpty, "\(server.name) should have tokenPath")
            XCTAssertFalse(server.profilePath.isEmpty, "\(server.name) should have profilePath")
        }
    }

    private static func makeTestServers() -> [YggdrasilServerConfig] {
        [
            YggdrasilServerConfig(
                name: "LittleSkin",
                baseURL: URL.require("https://littleskin.cn"),
                clientId: "1181",
                clientSecret: nil,
                redirectURI: "swift-craft-launcher://auth",
                authorizePath: "/oauth/authorize",
                tokenPath: "/oauth/token",
                profilePath: "/api/yggdrasil/sessionserver/session/minecraft/profile",
                scope: "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read",
                parserId: .littleskin
            ),
            YggdrasilServerConfig(
                name: "Mua",
                baseURL: URL.require("https://skin.mualliance.ltd"),
                clientId: "34",
                clientSecret: nil,
                redirectURI: "swift-craft-launcher://auth",
                authorizePath: "/oauth/authorize",
                tokenPath: "/oauth/token",
                profilePath: "/api/players",
                scope: "Player.Read User.Read",
                parserId: .mua
            ),
            YggdrasilServerConfig(
                name: "Ely.By",
                baseURL: URL.require("https://account.ely.by"),
                clientId: "swift-craft-launcher",
                clientSecret: nil,
                redirectURI: "swift-craft-launcher://auth",
                authorizePath: "/oauth2/v1",
                tokenPath: "/api/oauth2/v1/token",
                profilePath: "/api/account/v1/info",
                scope: "account_info",
                parserId: .ely
            ),
        ]
    }

    // MARK: - YggdrasilProfileParserID

    func testYggdrasilProfileParserID_allCases() {
        XCTAssertEqual(YggdrasilProfileParserID.allCases.count, 3)
    }

    func testYggdrasilProfileParserID_rawValues() {
        XCTAssertEqual(YggdrasilProfileParserID.littleskin.rawValue, "littleskin")
        XCTAssertEqual(YggdrasilProfileParserID.mua.rawValue, "mua")
        XCTAssertEqual(YggdrasilProfileParserID.ely.rawValue, "ely")
    }

    // MARK: - MinecraftSkinConstants

    func testMinecraftSkinConstants_values() {
        XCTAssertEqual(MinecraftSkinConstants.padding, 6)
        XCTAssertEqual(MinecraftSkinConstants.networkTimeout, 10.0)
        XCTAssertEqual(MinecraftSkinConstants.maxCacheSize, 100)
        XCTAssertEqual(MinecraftSkinConstants.maxCacheMemory, 2 * 1024 * 1024)
    }

    func testMinecraftSkinConstants_headDimensions() {
        XCTAssertEqual(MinecraftSkinConstants.headStartX, 8)
        XCTAssertEqual(MinecraftSkinConstants.headStartY, 8)
        XCTAssertEqual(MinecraftSkinConstants.headWidth, 8)
        XCTAssertEqual(MinecraftSkinConstants.headHeight, 8)
    }

    func testMinecraftSkinConstants_layerDimensions() {
        XCTAssertEqual(MinecraftSkinConstants.layerStartX, 40)
        XCTAssertEqual(MinecraftSkinConstants.layerStartY, 8)
        XCTAssertEqual(MinecraftSkinConstants.layerWidth, 8)
        XCTAssertEqual(MinecraftSkinConstants.layerHeight, 8)
    }

    // MARK: - SkinType

    func testSkinType_allCases() {
        let types: [SkinType] = [.url, .asset, .local]
        XCTAssertEqual(types.count, 3)
    }

    // MARK: - YggdrasilServerConfig

    func testYggdrasilServerConfig_authorizeURL() {
        let config = YggdrasilServerConfig(
            name: "Test",
            baseURL: URL.require("https://example.com"),
            redirectURI: "test://callback",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/profile",
            scope: "read",
            parserId: .littleskin
        )

        XCTAssertEqual(config.authorizeURL?.absoluteString, "https://example.com/oauth/authorize")
        XCTAssertEqual(config.tokenURL?.absoluteString, "https://example.com/oauth/token")
        XCTAssertEqual(config.profileURL?.absoluteString, "https://example.com/api/profile")
    }

    func testYggdrasilServerConfig_scopeTrimmed() {
        let config = YggdrasilServerConfig(
            baseURL: URL.require("https://example.com"),
            redirectURI: "test://callback",
            authorizePath: "/auth",
            tokenPath: "/token",
            profilePath: "/profile",
            scope: "  read write  ",
            parserId: .littleskin
        )

        XCTAssertEqual(config.scope, "read write")
    }
}
