//
//  GameVersionInfoCreationTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameVersionInfoCreationTests: XCTestCase {

    func testInit_defaultValues() {
        let info = GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "icon",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla"
        )

        XCTAssertFalse(info.id.isEmpty)
        XCTAssertEqual(info.gameName, "TestGame")
        XCTAssertEqual(info.gameIcon, "icon")
        XCTAssertEqual(info.gameVersion, "1.20.1")
        XCTAssertEqual(info.modVersion, "")
        XCTAssertTrue(info.modJvm.isEmpty)
        XCTAssertEqual(info.modClassPath, "")
        XCTAssertEqual(info.assetIndex, "17")
        XCTAssertEqual(info.modLoader, "vanilla")
        XCTAssertEqual(info.javaPath, "")
        XCTAssertEqual(info.jvmArguments, "")
        XCTAssertTrue(info.launchCommand.isEmpty)
        XCTAssertEqual(info.xms, 0)
        XCTAssertEqual(info.xmx, 0)
        XCTAssertEqual(info.javaVersion, 8)
        XCTAssertEqual(info.mainClass, "")
        XCTAssertTrue(info.gameArguments.isEmpty)
        XCTAssertEqual(info.environmentVariables, "")
    }

    func testInit_customValues() {
        let info = GameVersionInfo(
            gameName: "ModdedGame",
            gameIcon: "custom.png",
            gameVersion: "1.21.1",
            modVersion: "4.0.0",
            modJvm: ["-Xmx4G"],
            modClassPath: "/mods/lib.jar",
            assetIndex: "18",
            modLoader: "fabric",
            javaPath: "/usr/bin/java",
            jvmArguments: "-XX:+UseG1GC",
            launchCommand: ["--launch"],
            xms: 2048,
            xmx: 8192,
            javaVersion: 21,
            mainClass: "net.minecraft.client.main.Main",
            gameArguments: ["--username", "Player"],
            environmentVariables: "JAVA_HOME=/usr"
        )

        XCTAssertEqual(info.gameName, "ModdedGame")
        XCTAssertEqual(info.modVersion, "4.0.0")
        XCTAssertEqual(info.modJvm, ["-Xmx4G"])
        XCTAssertEqual(info.modClassPath, "/mods/lib.jar")
        XCTAssertEqual(info.assetIndex, "18")
        XCTAssertEqual(info.modLoader, "fabric")
        XCTAssertEqual(info.javaPath, "/usr/bin/java")
        XCTAssertEqual(info.jvmArguments, "-XX:+UseG1GC")
        XCTAssertEqual(info.launchCommand, ["--launch"])
        XCTAssertEqual(info.xms, 2048)
        XCTAssertEqual(info.xmx, 8192)
        XCTAssertEqual(info.javaVersion, 21)
        XCTAssertEqual(info.mainClass, "net.minecraft.client.main.Main")
        XCTAssertEqual(info.gameArguments, ["--username", "Player"])
        XCTAssertEqual(info.environmentVariables, "JAVA_HOME=/usr")
    }

    func testCodable_roundTrip() throws {
        let original = GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: "1.0",
            modJvm: ["-Xmx2G"],
            modClassPath: "/libs",
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

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.gameName, original.gameName)
        XCTAssertEqual(decoded.gameVersion, original.gameVersion)
        XCTAssertEqual(decoded.modLoader, original.modLoader)
        XCTAssertEqual(decoded.modJvm, original.modJvm)
        XCTAssertEqual(decoded.xms, original.xms)
        XCTAssertEqual(decoded.xmx, original.xmx)
        XCTAssertEqual(decoded.mainClass, original.mainClass)
    }

    func testHashable_equalValuesHashEqual() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1000000)
        let a = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla",
            lastPlayed: date
        )
        let b = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla",
            lastPlayed: date
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashable_differentNames_notEqual() {
        let a = GameVersionInfo(
            gameName: "GameA",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla"
        )
        let b = GameVersionInfo(
            gameName: "GameB",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla"
        )
        XCTAssertNotEqual(a, b)
    }

    func testHashable_differentVersions_notEqual() {
        let id = UUID()
        let a = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla"
        )
        let b = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.21.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla"
        )
        XCTAssertNotEqual(a, b)
    }

    func testHashable_intoSet() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1000000)
        let a = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla",
            lastPlayed: date
        )
        let b = GameVersionInfo(
            id: id,
            gameName: "Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            modClassPath: "",
            assetIndex: "17",
            modLoader: "vanilla",
            lastPlayed: date
        )
        var set = Set<GameVersionInfo>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }
}
