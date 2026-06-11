import XCTest
@testable import SwiftCraftLauncher

final class PlayerSkinServiceTests: XCTestCase {

    // MARK: - hasSkinChanges

    func testHasSkinChanges_withSelectedData_alwaysTrue() {
        let data = "skin".data(using: .utf8)!
        XCTAssertTrue(PlayerSkinService.hasSkinChanges(
            selectedSkinData: data,
            currentModel: .classic,
            originalModel: .classic
        ))
    }

    func testHasSkinChanges_noData_sameModel_returnsFalse() {
        XCTAssertFalse(PlayerSkinService.hasSkinChanges(
            selectedSkinData: nil,
            currentModel: .classic,
            originalModel: .classic
        ))
    }

    func testHasSkinChanges_noData_differentModel_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasSkinChanges(
            selectedSkinData: nil,
            currentModel: .slim,
            originalModel: .classic
        ))
    }

    func testHasSkinChanges_noData_noOriginal_modelIsSlim_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasSkinChanges(
            selectedSkinData: nil,
            currentModel: .slim,
            originalModel: nil
        ))
    }

    func testHasSkinChanges_noData_noOriginal_modelIsClassic_returnsFalse() {
        XCTAssertFalse(PlayerSkinService.hasSkinChanges(
            selectedSkinData: nil,
            currentModel: .classic,
            originalModel: nil
        ))
    }

    func testHasSkinChanges_slimToClassic_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasSkinChanges(
            selectedSkinData: nil,
            currentModel: .classic,
            originalModel: .slim
        ))
    }

    // MARK: - hasCapeChanges

    func testHasCapeChanges_bothNil_returnsFalse() {
        XCTAssertFalse(PlayerSkinService.hasCapeChanges(
            selectedCapeId: nil,
            currentActiveCapeId: nil
        ))
    }

    func testHasCapeChanges_sameValue_returnsFalse() {
        XCTAssertFalse(PlayerSkinService.hasCapeChanges(
            selectedCapeId: "cape-1",
            currentActiveCapeId: "cape-1"
        ))
    }

    func testHasCapeChanges_differentValues_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasCapeChanges(
            selectedCapeId: "cape-1",
            currentActiveCapeId: "cape-2"
        ))
    }

    func testHasCapeChanges_selectedNil_currentNot_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasCapeChanges(
            selectedCapeId: nil,
            currentActiveCapeId: "cape-1"
        ))
    }

    func testHasCapeChanges_selectedNot_currentNil_returnsTrue() {
        XCTAssertTrue(PlayerSkinService.hasCapeChanges(
            selectedCapeId: "cape-1",
            currentActiveCapeId: nil
        ))
    }

    // MARK: - getActiveCapeId

    func testGetActiveCapeId_nilProfile_returnsNil() {
        XCTAssertNil(PlayerSkinService.getActiveCapeId(from: nil))
    }

    func testGetActiveCapeId_noCapes_returnsNil() {
        let profile = MinecraftProfileResponse(
            id: "uuid",
            name: "Test",
            skins: [],
            capes: [],
            accessToken: "token",
            authXuid: "xuid"
        )
        XCTAssertNil(PlayerSkinService.getActiveCapeId(from: profile))
    }

    func testGetActiveCapeId_noActiveCape_returnsNil() {
        let capes = [
            Cape(id: "cape-1", state: "INACTIVE", url: "url1", alias: nil),
            Cape(id: "cape-2", state: "INACTIVE", url: "url2", alias: nil),
        ]
        let profile = MinecraftProfileResponse(
            id: "uuid",
            name: "Test",
            skins: [],
            capes: capes,
            accessToken: "token",
            authXuid: "xuid"
        )
        XCTAssertNil(PlayerSkinService.getActiveCapeId(from: profile))
    }

    func testGetActiveCapeId_withActiveCape_returnsId() {
        let capes = [
            Cape(id: "cape-1", state: "INACTIVE", url: "url1", alias: nil),
            Cape(id: "cape-active", state: "ACTIVE", url: "url2", alias: "minecon"),
        ]
        let profile = MinecraftProfileResponse(
            id: "uuid",
            name: "Test",
            skins: [],
            capes: capes,
            accessToken: "token",
            authXuid: "xuid"
        )
        XCTAssertEqual(PlayerSkinService.getActiveCapeId(from: profile), "cape-active")
    }

    func testGetActiveCapeId_multipleCapes_returnsFirstActive() {
        let capes = [
            Cape(id: "cape-active-1", state: "ACTIVE", url: "url1", alias: nil),
            Cape(id: "cape-active-2", state: "ACTIVE", url: "url2", alias: nil),
        ]
        let profile = MinecraftProfileResponse(
            id: "uuid",
            name: "Test",
            skins: [],
            capes: capes,
            accessToken: "token",
            authXuid: "xuid"
        )
        XCTAssertEqual(PlayerSkinService.getActiveCapeId(from: profile), "cape-active-1")
    }

    // MARK: - PublicSkinInfo Codable

    func testPublicSkinInfo_codable_roundTrip() throws {
        let info = PlayerSkinService.PublicSkinInfo(
            skinURL: "https://example.com/skin.png",
            model: .slim,
            capeURL: "https://example.com/cape.png",
            fetchedAt: Date(timeIntervalSince1970: 1000000)
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(PlayerSkinService.PublicSkinInfo.self, from: data)
        XCTAssertEqual(decoded.skinURL, info.skinURL)
        XCTAssertEqual(decoded.model, info.model)
        XCTAssertEqual(decoded.capeURL, info.capeURL)
    }

    func testPublicSkinInfo_codable_nilURLs() throws {
        let info = PlayerSkinService.PublicSkinInfo(
            skinURL: nil,
            model: .classic,
            capeURL: nil,
            fetchedAt: Date()
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(PlayerSkinService.PublicSkinInfo.self, from: data)
        XCTAssertNil(decoded.skinURL)
        XCTAssertNil(decoded.capeURL)
        XCTAssertEqual(decoded.model, .classic)
    }

    func testPublicSkinInfo_equatable() {
        let date = Date()
        let a = PlayerSkinService.PublicSkinInfo(
            skinURL: "url", model: .classic, capeURL: nil, fetchedAt: date
        )
        let b = PlayerSkinService.PublicSkinInfo(
            skinURL: "url", model: .classic, capeURL: nil, fetchedAt: date
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - SkinModel CaseIterable

    func testSkinModel_allCases() {
        XCTAssertEqual(PlayerSkinService.PublicSkinInfo.SkinModel.allCases.count, 2)
    }

    func testSkinModel_rawValues() {
        XCTAssertEqual(PlayerSkinService.PublicSkinInfo.SkinModel.classic.rawValue, "classic")
        XCTAssertEqual(PlayerSkinService.PublicSkinInfo.SkinModel.slim.rawValue, "slim")
    }

    func testSkinModel_initFromRawValue() {
        XCTAssertEqual(PlayerSkinService.PublicSkinInfo.SkinModel(rawValue: "classic"), .classic)
        XCTAssertEqual(PlayerSkinService.PublicSkinInfo.SkinModel(rawValue: "slim"), .slim)
        XCTAssertNil(PlayerSkinService.PublicSkinInfo.SkinModel(rawValue: "invalid"))
    }
}
