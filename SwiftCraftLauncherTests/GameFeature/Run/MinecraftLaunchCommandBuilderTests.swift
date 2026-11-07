//
//  MinecraftLaunchCommandBuilderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftLaunchCommandBuilderTests: XCTestCase {
    func testBuildExpandsLegacyForgeAssetArguments() throws {
        let arguments = [
            "--username", "${auth_player_name}",
            "--version", "${version_name}",
            "--assetsDir", "${assets_root}",
            "--assetIndex", "${assets_index_name}",
            "--tweakClass", "net.minecraftforge.fml.common.launcher.FMLTweaker",
        ]

        let command = try buildCommand(loaderArguments: arguments)

        XCTAssertEqual(Array(command.suffix(arguments.count)), [
            "--username", "${auth_player_name}",
            "--version", "1.8.9",
            "--assetsDir", AppPaths.assetsDirectory.path,
            "--assetIndex", "1.8",
            "--tweakClass", "net.minecraftforge.fml.common.launcher.FMLTweaker",
        ])
        XCTAssertEqual(command.filter { $0 == "--assetsDir" }.count, 1)
        XCTAssertTrue(command.contains("-Xms${xms}M"))
        XCTAssertTrue(command.contains("net.minecraft.launchwrapper.Launch"))
    }

    func testBuildExpandsLoaderArgumentsAlongsideManifestArguments() throws {
        let command = try buildCommand(
            loaderArguments: ["--assetsDir", "${assets_root}", "--assetIndex", "${assets_index_name}"],
            modernArguments: true,
        )

        XCTAssertEqual(Array(command.suffix(6)), [
            "--width", "854",
            "--assetsDir", AppPaths.assetsDirectory.path,
            "--assetIndex", "1.8",
        ])
    }

    func testBuildPreservesLegacyVanillaAssetArguments() throws {
        let command = try buildCommand(loaderArguments: [])

        XCTAssertEqual(Array(command.suffix(4)), [
            "--assetsDir", AppPaths.assetsDirectory.path,
            "--assetIndex", "1.8",
        ])
    }

    private func buildCommand(
        loaderArguments: [String],
        modernArguments: Bool = false,
    ) throws -> [String] {
        let version = "asset-arguments-test-\(UUID().uuidString)"
        let directory = AppPaths.versionsDirectory.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory.appendingPathComponent("\(version).jar"))

        var json: [String: Any] = [
            "id": version,
            "assetIndex": ["id": "1.8", "sha1": "", "size": 0, "totalSize": 0, "url": "https://example.com/index.json"],
            "assets": "1.8",
            "downloads": ["client": ["sha1": "", "size": 0, "url": "https://example.com/client.jar"]],
            "javaVersion": ["component": "jre-legacy", "majorVersion": 8],
            "libraries": [],
            "logging": ["client": ["argument": "", "file": ["id": "log.xml", "sha1": "", "size": 0, "url": "https://example.com/log.xml"], "type": "log4j2-xml"]],
            "mainClass": "net.minecraft.client.main.Main",
            "minimumLauncherVersion": 18,
            "minecraftArguments": "--assetsDir ${assets_root} --assetIndex ${assets_index_name}",
            "releaseTime": "2015-12-09T09:24:39+00:00",
            "time": "2015-12-09T09:24:39+00:00",
            "type": "release",
        ]
        if modernArguments {
            json["arguments"] = ["game": ["--width", "854"]]
        }
        let manifest = try JSONDecoder().decode(
            MinecraftVersionManifest.self,
            from: JSONSerialization.data(withJSONObject: json),
        )
        let game = GameVersionInfo(
            gameName: "Asset Arguments Test",
            gameIcon: "",
            gameVersion: "1.8.9",
            assetIndex: "1.8",
            modLoader: loaderArguments.isEmpty ? "vanilla" : "forge",
            mainClass: loaderArguments.isEmpty ? manifest.mainClass : "net.minecraft.launchwrapper.Launch",
            gameArguments: loaderArguments,
        )

        return try MinecraftLaunchCommandBuilder.buildThrowing(
            manifest: manifest,
            gameInfo: game,
            launcherVersion: "test",
        )
    }

    private func makeGameInfo(
        id: String = "test-game-id",
        gameName: String = "TestGame",
        gameVersion: String = "1.20.1",
        assetIndex: String = "17",
        mainClass: String = "net.minecraft.client.main.Main",
        modClassPath: String = "",
        modJvm _: [String] = [],
        gameArguments: [String] = [],
        xms: Int = 0,
        xmx: Int = 0,
        jvmArguments: String = "",
        javaPath: String = "/usr/bin/java",
    ) -> GameVersionInfo {
        GameVersionInfo(
            id: UUID(uuidString: id) ?? UUID(),
            gameName: gameName,
            gameIcon: "",
            gameVersion: gameVersion,
            modClassPath: modClassPath,
            assetIndex: assetIndex,
            modLoader: "vanilla",
            javaPath: javaPath,
            jvmArguments: jvmArguments,
            xms: xms,
            xmx: xmx,
            mainClass: mainClass,
            gameArguments: gameArguments,
        )
    }

    func testRemoveDuplicatePaths_removesExactDuplicates() {
        let paths = ["/a/b.jar", "/a/b.jar", "/c/d.jar"]
        let unique = Array(Set(paths))
        XCTAssertEqual(unique.count, 2)
    }

    func testRemoveDuplicatePaths_preservesOrder() {
        let paths = ["/a/b.jar", "/c/d.jar", "/a/b.jar"]
        var seen = Set<String>()
        let filtered = paths.filter { seen.insert($0).inserted }
        XCTAssertEqual(filtered, ["/a/b.jar", "/c/d.jar"])
    }

    func testCommandStructure_jvmArgsBeforeMainClass() {
        let jvmArgs = ["-Xmx4G", "-Djava.class.path=/path/to/jar"]
        let mainClass = "net.minecraft.client.main.Main"
        let gameArgs = ["--width", "854"]

        let command = jvmArgs + [mainClass] + gameArgs

        XCTAssertEqual(command.count, 5)
        XCTAssertEqual(command[0], "-Xmx4G")
        XCTAssertEqual(command[2], mainClass)
        XCTAssertEqual(command[3], "--width")
        XCTAssertEqual(command[4], "854")
    }

    func testCommandStructure_macOSArgsFirst() {
        var jvmArgs = ["-Xmx4G"]
        jvmArgs.insert("-XstartOnFirstThread", at: 0)

        XCTAssertEqual(jvmArgs.first, "-XstartOnFirstThread")
    }

    func testCommandStructure_memoryArgsBeforeOtherJvmArgs() {
        var jvmArgs = ["-Djava.class.path=/path/to/jar"]
        let xmsArg = "-Xms${xms}M"
        let xmxArg = "-Xmx${xmx}M"
        jvmArgs.insert(contentsOf: [xmsArg, xmxArg], at: 0)

        XCTAssertEqual(jvmArgs[0], "-Xms${xms}M")
        XCTAssertEqual(jvmArgs[1], "-Xmx${xmx}M")
        XCTAssertEqual(jvmArgs[2], "-Djava.class.path=/path/to/jar")
    }

    func testModJvmArgs_appendedToEnd() {
        var jvmArgs = ["-Xmx4G", "-XstartOnFirstThread"]
        let modJvm = ["-Dfabric.classPath=/mods", "-Dforge.enabled=true"]

        jvmArgs.append(contentsOf: modJvm)

        XCTAssertEqual(jvmArgs.count, 4)
        XCTAssertEqual(jvmArgs[2], "-Dfabric.classPath=/mods")
        XCTAssertEqual(jvmArgs[3], "-Dforge.enabled=true")
    }

    func testGameArgs_appendedToEnd() {
        var gameArgs = ["--width", "854"]
        let extraGameArgs = ["--launchTarget", "forge_client"]

        gameArgs.append(contentsOf: extraGameArgs)

        XCTAssertEqual(gameArgs.count, 4)
        XCTAssertEqual(gameArgs[2], "--launchTarget")
        XCTAssertEqual(gameArgs[3], "forge_client")
    }

    func testInjectingLibraryDirectory_forgeWithoutProperty() {
        let jvmArgs = ["-Xmx4G", "-Djava.net.preferIPv6Addresses=system"]

        let result = MinecraftLaunchCommandBuilder.injectingLibraryDirectoryIfNeeded(
            into: jvmArgs,
            modLoader: GameLoader.forge.displayName,
        )

        XCTAssertEqual(result.first, "-DlibraryDirectory=\(AppPaths.librariesDirectory.path)")
        XCTAssertEqual(Array(result.dropFirst()), jvmArgs)
    }

    func testInjectingLibraryDirectory_notAddedForNeoForge() {
        // NeoForge profiles always declare `-DlibraryDirectory` themselves.
        let jvmArgs = ["-Xmx4G"]

        let result = MinecraftLaunchCommandBuilder.injectingLibraryDirectoryIfNeeded(
            into: jvmArgs,
            modLoader: GameLoader.neoforge.displayName,
        )

        XCTAssertEqual(result, jvmArgs)
    }

    func testInjectingLibraryDirectory_existingPropertyIsPreserved() {
        let jvmArgs = ["-DlibraryDirectory=/custom/libraries", "-Xmx4G"]

        let result = MinecraftLaunchCommandBuilder.injectingLibraryDirectoryIfNeeded(
            into: jvmArgs,
            modLoader: GameLoader.forge.displayName,
        )

        XCTAssertEqual(result, jvmArgs)
    }

    func testInjectingLibraryDirectory_notAddedForOtherLoaders() {
        for loader in [GameLoader.vanilla, .fabric, .quilt] {
            let jvmArgs = ["-Xmx4G"]

            let result = MinecraftLaunchCommandBuilder.injectingLibraryDirectoryIfNeeded(
                into: jvmArgs,
                modLoader: loader.displayName,
            )

            XCTAssertEqual(result, jvmArgs, "Unexpected injection for \(loader.displayName)")
        }
    }

    func testVariableMap_containsRequiredKeys() {
        let gameInfo = makeGameInfo(
            gameName: "TestGame",
            gameVersion: "1.20.1",
            assetIndex: "17",
        )

        let variableMap: [String: String] = [
            "auth_player_name": "${auth_player_name}",
            "version_name": gameInfo.gameVersion,
            "game_directory": "/path/to/game",
            "assets_root": "/path/to/assets",
            "assets_index_name": gameInfo.assetIndex,
            "auth_uuid": "${auth_uuid}",
            "auth_access_token": "${auth_access_token}",
            "clientid": "client-id",
            "auth_xuid": "${auth_xuid}",
            "user_type": "msa",
            "version_type": "SwiftCraft",
            "natives_directory": "/path/to/natives",
            "launcher_name": "SwiftCraft",
            "launcher_version": "1.0",
            "classpath": "/path/to/classpath",
        ]

        XCTAssertEqual(variableMap["version_name"], "1.20.1")
        XCTAssertEqual(variableMap["assets_index_name"], "17")
        XCTAssertEqual(variableMap["user_type"], "msa")
        XCTAssertEqual(variableMap["auth_player_name"], "${auth_player_name}")
    }
}
