import XCTest
@testable import SwiftCraftLauncher

final class GameCreationGameLoaderTests: XCTestCase {

    func testDisplayName_allCases() {
        XCTAssertEqual(GameLoader.vanilla.displayName, "vanilla")
        XCTAssertEqual(GameLoader.fabric.displayName, "fabric")
        XCTAssertEqual(GameLoader.forge.displayName, "forge")
        XCTAssertEqual(GameLoader.neoforge.displayName, "neoforge")
        XCTAssertEqual(GameLoader.quilt.displayName, "quilt")
    }

    func testRawValue_allCases() {
        XCTAssertEqual(GameLoader.vanilla.rawValue, "vanilla")
        XCTAssertEqual(GameLoader.fabric.rawValue, "fabric")
        XCTAssertEqual(GameLoader.forge.rawValue, "forge")
        XCTAssertEqual(GameLoader.neoforge.rawValue, "neoforge")
        XCTAssertEqual(GameLoader.quilt.rawValue, "quilt")
    }

    func testId_matchesRawValue() {
        for loader in GameLoader.allCases {
            XCTAssertEqual(loader.id, loader.rawValue)
        }
    }

    func testAllCases_hasFiveElements() {
        XCTAssertEqual(GameLoader.allCases.count, 5)
    }

    func testCodable_roundTrip() throws {
        let original = GameLoader.fabric
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GameLoader.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCodable_allCases() throws {
        for loader in GameLoader.allCases {
            let encoded = try JSONEncoder().encode(loader)
            let decoded = try JSONDecoder().decode(GameLoader.self, from: encoded)
            XCTAssertEqual(decoded, loader)
        }
    }

    func testInit_fromRawValue_valid() {
        XCTAssertEqual(GameLoader(rawValue: "vanilla"), .vanilla)
        XCTAssertEqual(GameLoader(rawValue: "fabric"), .fabric)
        XCTAssertEqual(GameLoader(rawValue: "forge"), .forge)
        XCTAssertEqual(GameLoader(rawValue: "neoforge"), .neoforge)
        XCTAssertEqual(GameLoader(rawValue: "quilt"), .quilt)
    }

    func testInit_fromRawValue_invalid() {
        XCTAssertNil(GameLoader(rawValue: "invalid"))
        XCTAssertNil(GameLoader(rawValue: ""))
        XCTAssertNil(GameLoader(rawValue: "Fabric"))
    }
}
