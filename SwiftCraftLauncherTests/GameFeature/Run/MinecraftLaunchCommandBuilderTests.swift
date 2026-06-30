//
//  MinecraftLaunchCommandBuilderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftLaunchCommandBuilderTests: XCTestCase {
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

    private func makeLibrary(
        name: String = "test:lib:1.0",
        artifactPath: String? = "org/example/lib-1.0.jar",
        downloadable: Bool = true,
        includeInClasspath: Bool = true,
        rules: [Rule]? = nil,
    ) throws -> Library {
        var artifactJson: [String: Any] = [
            "sha1": "abc",
            "size": 100,
            "url": "https://example.com/lib.jar",
        ]
        if let path = artifactPath {
            artifactJson["path"] = path
        }

        var json: [String: Any] = [
            "downloads": ["artifact": artifactJson],
            "name": name,
            "include_in_classpath": includeInClasspath,
            "downloadable": downloadable,
        ]
        if let rules {
            let ruleData = try JSONEncoder().encode(rules)
            let ruleObj = try JSONSerialization.jsonObject(with: ruleData)
            json["rules"] = ruleObj
        }

        let jsonData = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Library.self, from: jsonData)
    }

    func testLibraryFiltering_nonDownloadableExcluded() throws {
        let library = try makeLibrary(downloadable: false, includeInClasspath: true)
        XCTAssertFalse(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testLibraryFiltering_notInClasspathExcluded() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: false)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testLibraryFiltering_bothTrueIncluded() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: true)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertTrue(LibraryFilter.shouldIncludeInClasspath(library))
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
