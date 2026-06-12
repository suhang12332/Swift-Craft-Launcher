import XCTest
@testable import SwiftCraftLauncher

final class ResourceTypeTests: XCTestCase {

    func testResourceType_allCases() {
        XCTAssertEqual(ResourceType.allCases.count, 6)
    }

    func testResourceType_rawValues() {
        XCTAssertEqual(ResourceType.mod.rawValue, "mod")
        XCTAssertEqual(ResourceType.datapack.rawValue, "datapack")
        XCTAssertEqual(ResourceType.shader.rawValue, "shader")
        XCTAssertEqual(ResourceType.resourcepack.rawValue, "resourcepack")
        XCTAssertEqual(ResourceType.modpack.rawValue, "modpack")
        XCTAssertEqual(ResourceType.minecraftJavaServer.rawValue, "minecraft_java_server")
    }

    func testResourceType_initFromRawValue() {
        XCTAssertEqual(ResourceType(rawValue: "mod"), .mod)
        XCTAssertEqual(ResourceType(rawValue: "datapack"), .datapack)
        XCTAssertEqual(ResourceType(rawValue: "shader"), .shader)
        XCTAssertEqual(ResourceType(rawValue: "resourcepack"), .resourcepack)
        XCTAssertEqual(ResourceType(rawValue: "modpack"), .modpack)
        XCTAssertEqual(ResourceType(rawValue: "minecraft_java_server"), .minecraftJavaServer)
        XCTAssertNil(ResourceType(rawValue: "invalid"))
    }

    func testResourceType_systemImage() {
        XCTAssertEqual(ResourceType.mod.systemImage, "puzzlepiece.extension")
        XCTAssertEqual(ResourceType.datapack.systemImage, "doc.on.doc")
        XCTAssertEqual(ResourceType.shader.systemImage, "sparkles")
        XCTAssertEqual(ResourceType.resourcepack.systemImage, "photo.stack")
        XCTAssertEqual(ResourceType.modpack.systemImage, "cube.box")
        XCTAssertEqual(ResourceType.minecraftJavaServer.systemImage, "server.rack")
    }

    func testResourceType_overridesSubdirectory() {
        XCTAssertEqual(ResourceType.mod.overridesSubdirectory, "mods")
        XCTAssertEqual(ResourceType.datapack.overridesSubdirectory, "datapacks")
        XCTAssertEqual(ResourceType.shader.overridesSubdirectory, "shaderpacks")
        XCTAssertEqual(ResourceType.resourcepack.overridesSubdirectory, "resourcepacks")
        XCTAssertEqual(ResourceType.modpack.overridesSubdirectory, "modpack")
        XCTAssertEqual(ResourceType.minecraftJavaServer.overridesSubdirectory, "minecraft_java_server")
    }
}
