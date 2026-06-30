//
//  GameVersionInfoExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameVersionInfoExtendedTests: XCTestCase {

    func testGameVersionInfo_codable_allFields() throws {
        let original = GameVersionInfo(
            id: UUID(),
            gameName: "MyGame",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: "0.14.21",
            modJvm: ["-Xmx2G"],
            modClassPath: "/path/to/libs",
            assetIndex: "17",
            modLoader: "fabric",
            javaPath: "/usr/bin/java",
            jvmArguments: "-XX:+UseG1GC",
            launchCommand: ["--launch"],
            xms: 1024,
            xmx: 4096,
            javaVersion: 17,
            mainClass: "net.minecraft.client.main.Main",
            gameArguments: ["--username", "Test"],
            environmentVariables: "JAVA_HOME=/usr"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GameVersionInfo.self, from: encoded)

        XCTAssertEqual(decoded.gameName, "MyGame")
        XCTAssertEqual(decoded.gameVersion, "1.20.1")
        XCTAssertEqual(decoded.modVersion, "0.14.21")
        XCTAssertEqual(decoded.modJvm, ["-Xmx2G"])
        XCTAssertEqual(decoded.modClassPath, "/path/to/libs")
        XCTAssertEqual(decoded.modLoader, "fabric")
        XCTAssertEqual(decoded.javaPath, "/usr/bin/java")
        XCTAssertEqual(decoded.jvmArguments, "-XX:+UseG1GC")
        XCTAssertEqual(decoded.launchCommand, ["--launch"])
        XCTAssertEqual(decoded.xms, 1024)
        XCTAssertEqual(decoded.xmx, 4096)
        XCTAssertEqual(decoded.javaVersion, 17)
        XCTAssertEqual(decoded.mainClass, "net.minecraft.client.main.Main")
        XCTAssertEqual(decoded.gameArguments, ["--username", "Test"])
        XCTAssertEqual(decoded.environmentVariables, "JAVA_HOME=/usr")
    }

    func testGameVersionInfo_hashable() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1000)
        let a = GameVersionInfo(id: id, gameName: "G", gameIcon: "i", gameVersion: "1.0", modVersion: "", assetIndex: "1", modLoader: "vanilla", lastPlayed: date)
        let b = GameVersionInfo(id: id, gameName: "G", gameIcon: "i", gameVersion: "1.0", modVersion: "", assetIndex: "1", modLoader: "vanilla", lastPlayed: date)

        XCTAssertEqual(a, b)
    }

    func testGameVersionInfo_identifiable() {
        let id = UUID()
        let game = GameVersionInfo(id: id, gameName: "G", gameIcon: "i", gameVersion: "1.0", assetIndex: "1", modLoader: "vanilla")
        XCTAssertEqual(game.id, id.uuidString)
    }
}
