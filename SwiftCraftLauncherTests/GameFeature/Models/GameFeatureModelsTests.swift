import XCTest
@testable import SwiftCraftLauncher

final class GameFeatureModelsTests: XCTestCase {

    // MARK: - ServerAddress

    func testServerAddress_init_defaults() {
        let server = ServerAddress(name: "My Server", address: "play.example.com")

        XCTAssertFalse(server.id.isEmpty)
        XCTAssertEqual(server.name, "My Server")
        XCTAssertEqual(server.address, "play.example.com")
        XCTAssertEqual(server.port, 25565)
        XCTAssertFalse(server.hidden)
        XCTAssertNil(server.icon)
        XCTAssertFalse(server.acceptTextures)
    }

    func testServerAddress_init_allParams() {
        let server = ServerAddress(
            id: "custom-id",
            name: "Test",
            address: "1.2.3.4",
            port: 25566,
            hidden: true,
            icon: "server-icon.png",
            acceptTextures: true
        )

        XCTAssertEqual(server.id, "custom-id")
        XCTAssertEqual(server.port, 25566)
        XCTAssertTrue(server.hidden)
        XCTAssertEqual(server.icon, "server-icon.png")
        XCTAssertTrue(server.acceptTextures)
    }

    func testServerAddress_fullAddress() {
        let server = ServerAddress(name: "S", address: "mc.example.com", port: 25565)
        XCTAssertEqual(server.fullAddress, "mc.example.com:25565")

        let customPort = ServerAddress(name: "S", address: "mc.example.com", port: 19132)
        XCTAssertEqual(customPort.fullAddress, "mc.example.com:19132")
    }

    func testServerAddress_codable_roundTrip() throws {
        let original = ServerAddress(
            id: "id-1",
            name: "Server",
            address: "1.2.3.4",
            port: 25566,
            hidden: true,
            icon: "icon.png",
            acceptTextures: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerAddress.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.hidden, original.hidden)
        XCTAssertEqual(decoded.acceptTextures, original.acceptTextures)
    }

    func testServerAddress_hashable() {
        let a = ServerAddress(id: "same-id", name: "A", address: "1.2.3.4")
        let b = ServerAddress(id: "same-id", name: "A", address: "1.2.3.4")
        let c = ServerAddress(id: "different-id", name: "A", address: "1.2.3.4")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - SidebarItem

    func testSidebarItem_game_id() {
        let item = SidebarItem.game("test-game-id")
        XCTAssertEqual(item.id, "game_test-game-id")
    }

    func testSidebarItem_resource_id() {
        let item = SidebarItem.resource(.mod)
        XCTAssertEqual(item.id, "resource_mod")
    }

    func testSidebarItem_resource_allTypes() {
        let types: [ResourceType] = [.mod, .datapack, .shader, .resourcepack, .modpack, .minecraftJavaServer]
        for type in types {
            let item = SidebarItem.resource(type)
            XCTAssertEqual(item.id, "resource_\(type.rawValue)")
        }
    }

    func testSidebarItem_hashable() {
        let a = SidebarItem.game("id1")
        let b = SidebarItem.game("id1")
        let c = SidebarItem.game("id2")

        XCTAssertEqual(a.hashValue, b.hashValue)
        var set = Set<SidebarItem>()
        set.insert(a)
        set.insert(b)
        set.insert(c)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - ResourceType

    func testResourceType_rawValues() {
        XCTAssertEqual(ResourceType.mod.rawValue, "mod")
        XCTAssertEqual(ResourceType.datapack.rawValue, "datapack")
        XCTAssertEqual(ResourceType.shader.rawValue, "shader")
        XCTAssertEqual(ResourceType.resourcepack.rawValue, "resourcepack")
        XCTAssertEqual(ResourceType.modpack.rawValue, "modpack")
        XCTAssertEqual(ResourceType.minecraftJavaServer.rawValue, "minecraft_java_server")
    }

    func testResourceType_allCases_count() {
        XCTAssertEqual(ResourceType.allCases.count, 6)
    }

    func testResourceType_systemImage() {
        XCTAssertEqual(ResourceType.mod.systemImage, "puzzlepiece.extension")
        XCTAssertEqual(ResourceType.datapack.systemImage, "doc.on.doc")
        XCTAssertEqual(ResourceType.shader.systemImage, "sparkles")
        XCTAssertEqual(ResourceType.resourcepack.systemImage, "photo.stack")
        XCTAssertEqual(ResourceType.modpack.systemImage, "cube.box")
        XCTAssertEqual(ResourceType.minecraftJavaServer.systemImage, "server.rack")
    }

    // MARK: - WorldInfo

    func testWorldInfo_init_defaults() {
        let url = URL(fileURLWithPath: "/tmp/MyWorld")
        let world = WorldInfo(name: "My World", path: url)

        XCTAssertEqual(world.id, "MyWorld")
        XCTAssertEqual(world.name, "My World")
        XCTAssertNil(world.lastPlayed)
        XCTAssertNil(world.gameMode)
        XCTAssertNil(world.difficulty)
        XCTAssertFalse(world.hardcore)
        XCTAssertFalse(world.cheats)
        XCTAssertNil(world.version)
        XCTAssertNil(world.seed)
    }

    func testWorldInfo_init_allParams() {
        let url = URL(fileURLWithPath: "/tmp/TestWorld")
        let world = WorldInfo(
            name: "Test",
            path: url,
            lastPlayed: Date(),
            gameMode: "survival",
            difficulty: "hard",
            hardcore: true,
            cheats: true,
            version: "1.20.1",
            seed: 12345
        )

        XCTAssertTrue(world.hardcore)
        XCTAssertTrue(world.cheats)
        XCTAssertEqual(world.version, "1.20.1")
        XCTAssertEqual(world.seed, 12345)
    }

    func testWorldInfo_equatable() {
        let url = URL(fileURLWithPath: "/tmp/W")
        let a = WorldInfo(name: "A", path: url)
        let b = WorldInfo(name: "A", path: url)

        XCTAssertEqual(a, b)
    }

    // MARK: - ScreenshotInfo

    func testScreenshotInfo_init_defaults() {
        let url = URL(fileURLWithPath: "/tmp/screenshot.png")
        let screenshot = ScreenshotInfo(name: "screenshot.png", path: url)

        XCTAssertEqual(screenshot.id, "screenshot.png")
        XCTAssertEqual(screenshot.name, "screenshot.png")
        XCTAssertEqual(screenshot.fileSize, 0)
        XCTAssertNil(screenshot.createdDate)
    }

    func testScreenshotInfo_init_allParams() {
        let date = Date()
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let screenshot = ScreenshotInfo(name: "test.png", path: url, createdDate: date, fileSize: 1024)

        XCTAssertEqual(screenshot.fileSize, 1024)
        XCTAssertEqual(screenshot.createdDate, date)
    }

    // MARK: - LogInfo

    func testLogInfo_init_defaults() {
        let url = URL(fileURLWithPath: "/tmp/latest.log")
        let log = LogInfo(name: "latest.log", path: url)

        XCTAssertEqual(log.id, "latest.log")
        XCTAssertFalse(log.isCrashLog)
        XCTAssertEqual(log.fileSize, 0)
    }

    func testLogInfo_crashLog() {
        let url = URL(fileURLWithPath: "/tmp/crash.log")
        let log = LogInfo(name: "crash.log", path: url, fileSize: 2048, isCrashLog: true)

        XCTAssertTrue(log.isCrashLog)
        XCTAssertEqual(log.fileSize, 2048)
    }

    // MARK: - FabricLoader

    func testFabricLoader_codable() throws {
        let json = """
        {"loader": {"version": "0.14.21"}}
        """
        let data = json.data(using: .utf8)!
        let loader = try JSONDecoder().decode(FabricLoader.self, from: data)

        XCTAssertEqual(loader.loader.version, "0.14.21")
    }

    func testFabricLoader_codable_roundTrip() throws {
        let original = FabricLoader(loader: FabricLoader.LoaderInfo(version: "0.15.3"))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FabricLoader.self, from: encoded)

        XCTAssertEqual(decoded.loader.version, "0.15.3")
    }

    // MARK: - QuiltLoaderResponse

    func testQuiltLoaderResponse_codable() throws {
        let json = """
        {"loader": {"version": "0.22.0"}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(QuiltLoaderResponse.self, from: data)

        XCTAssertEqual(response.loader.version, "0.22.0")
    }

    func testQuiltLoaderResponse_codable_roundTrip() throws {
        let original = QuiltLoaderResponse(loader: QuiltLoaderResponse.Loader(version: "0.23.0"))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QuiltLoaderResponse.self, from: encoded)

        XCTAssertEqual(decoded.loader.version, "0.23.0")
    }

    // MARK: - ModrinthLoader

    func testModrinthLoader_codable() throws {
        let json = """
        {
            "mainClass": "net.fabricmc.loader.impl.launch.knot.KnotClient",
            "arguments": {"game": ["--username", "test"], "jvm": ["-Xmx1G"]},
            "libraries": [
                {
                    "name": "net.fabricmc:fabric-loader:0.14.21",
                    "include_in_classpath": true,
                    "downloadable": true
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)

        XCTAssertEqual(loader.mainClass, "net.fabricmc.loader.impl.launch.knot.KnotClient")
        XCTAssertNil(loader.version)
        XCTAssertNil(loader.processors)
        XCTAssertNil(loader.data)
        XCTAssertEqual(loader.libraries.count, 1)
        XCTAssertEqual(loader.libraries.first?.name, "net.fabricmc:fabric-loader:0.14.21")
        XCTAssertTrue(loader.libraries.first?.includeInClasspath ?? false)
        XCTAssertTrue(loader.libraries.first?.downloadable ?? false)
    }

    func testModrinthLoader_withOptionalFields() throws {
        let json = """
        {
            "mainClass": "Main",
            "arguments": {"game": [], "jvm": []},
            "libraries": [],
            "version": "0.14.21",
            "processors": [{"jar": "processor.jar", "args": ["--output"]}],
            "data": {"mappings": {"client": "mapped", "server": "mapped"}}
        }
        """
        let data = json.data(using: .utf8)!
        let loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)

        XCTAssertEqual(loader.version, "0.14.21")
        XCTAssertEqual(loader.processors?.count, 1)
        XCTAssertEqual(loader.data?["mappings"]?.client, "mapped")
    }

    // MARK: - ModrinthLoaderLibrary

    func testModrinthLoaderLibrary_init() {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "test:lib:1.0",
            includeInClasspath: true,
            downloadable: true
        )

        XCTAssertEqual(lib.name, "test:lib:1.0")
        XCTAssertTrue(lib.includeInClasspath)
        XCTAssertTrue(lib.downloadable)
        XCTAssertNil(lib.downloads)
    }

    func testModrinthLoaderLibrary_codable() throws {
        let json = """
        {
            "name": "org.example:lib:1.0",
            "include_in_classpath": false,
            "downloadable": false,
            "url": "https://example.com/lib.jar"
        }
        """
        let data = json.data(using: .utf8)!
        let lib = try JSONDecoder().decode(ModrinthLoaderLibrary.self, from: data)

        XCTAssertEqual(lib.name, "org.example:lib:1.0")
        XCTAssertFalse(lib.includeInClasspath)
        XCTAssertFalse(lib.downloadable)
        XCTAssertEqual(lib.url?.absoluteString, "https://example.com/lib.jar")
    }

    // MARK: - Processor

    func testProcessor_codable() throws {
        let json = """
        {
            "sides": ["client"],
            "jar": "processor.jar",
            "classpath": ["lib1.jar"],
            "args": ["--input", "{INPUT}", "--output", "{OUTPUT}"],
            "outputs": {"output.jar": "sha1:abc"}
        }
        """
        let data = json.data(using: .utf8)!
        let processor = try JSONDecoder().decode(Processor.self, from: data)

        XCTAssertEqual(processor.sides, ["client"])
        XCTAssertEqual(processor.jar, "processor.jar")
        XCTAssertEqual(processor.classpath, ["lib1.jar"])
        XCTAssertEqual(processor.args?.count, 4)
        XCTAssertEqual(processor.outputs?["output.jar"], "sha1:abc")
    }

    func testProcessor_allNilOptionals() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let processor = try JSONDecoder().decode(Processor.self, from: data)

        XCTAssertNil(processor.sides)
        XCTAssertNil(processor.jar)
        XCTAssertNil(processor.classpath)
        XCTAssertNil(processor.args)
        XCTAssertNil(processor.outputs)
    }

    // MARK: - SidedDataEntry

    func testSidedDataEntry_codable() throws {
        let json = """
        {"client": "mapped-client", "server": "mapped-server"}
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(SidedDataEntry.self, from: data)

        XCTAssertEqual(entry.client, "mapped-client")
        XCTAssertEqual(entry.server, "mapped-server")
    }

    // MARK: - LoaderVersion

    func testLoaderVersion_codable() throws {
        let json = """
        {
            "id": "0.14.21",
            "stable": true,
            "loaders": [{"id": "fabric", "url": "https://example.com", "stable": true}]
        }
        """
        let data = json.data(using: .utf8)!
        let version = try JSONDecoder().decode(LoaderVersion.self, from: data)

        XCTAssertEqual(version.id, "0.14.21")
        XCTAssertTrue(version.stable)
        XCTAssertEqual(version.loaders.count, 1)
    }

    // MARK: - GameVersionInfo Codable

    func testGameVersionInfo_codable_roundTrip() throws {
        let original = GameVersionInfo(
            id: UUID(),
            gameName: "TestGame",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: "0.14.21",
            assetIndex: "17",
            modLoader: "fabric",
            mainClass: "net.minecraft.client.main.Main"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GameVersionInfo.self, from: encoded)

        XCTAssertEqual(decoded.gameName, original.gameName)
        XCTAssertEqual(decoded.gameVersion, original.gameVersion)
        XCTAssertEqual(decoded.modVersion, original.modVersion)
        XCTAssertEqual(decoded.modLoader, original.modLoader)
    }
}
