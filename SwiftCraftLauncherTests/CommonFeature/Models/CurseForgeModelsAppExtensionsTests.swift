import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeModelsAppExtensionsTests: XCTestCase {

    // MARK: - ResourceType.overridesSubdirectory

    func testResourceType_overridesSubdirectory_mod() {
        XCTAssertEqual(ResourceType.mod.overridesSubdirectory, "mods")
    }

    func testResourceType_overridesSubdirectory_datapack() {
        XCTAssertEqual(ResourceType.datapack.overridesSubdirectory, "datapacks")
    }

    func testResourceType_overridesSubdirectory_shader() {
        XCTAssertEqual(ResourceType.shader.overridesSubdirectory, "shaderpacks")
    }

    func testResourceType_overridesSubdirectory_resourcepack() {
        XCTAssertEqual(ResourceType.resourcepack.overridesSubdirectory, "resourcepacks")
    }

    func testResourceType_overridesSubdirectory_modpack() {
        XCTAssertEqual(ResourceType.modpack.overridesSubdirectory, "modpack")
    }

    func testResourceType_overridesSubdirectory_minecraftJavaServer() {
        XCTAssertEqual(ResourceType.minecraftJavaServer.overridesSubdirectory, "minecraft_java_server")
    }
}
