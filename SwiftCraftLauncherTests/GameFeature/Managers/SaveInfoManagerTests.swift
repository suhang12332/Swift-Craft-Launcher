//
//  SaveInfoManagerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class SaveInfoManagerTests: XCTestCase {
    private enum TestError: Error, Sendable {
        case failed
    }

    private static let emptyServerLoader: ServerAddressLoader = { _ in [] }
    private static let emptyLitematicaLoader: LitematicaLoader = { _ in [] }

    private func makeProfileDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveInfoManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(
        _ name: String,
        in subdirectory: String,
        profileDirectory: URL,
    ) throws {
        let directory = profileDirectory.appendingPathComponent(subdirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent(name))
    }

    private func makeManager(
        profileDirectory: URL,
        modLoader: String = "fabric",
    ) -> SaveInfoManager {
        SaveInfoManager(
            gameName: "TestGame",
            modLoader: modLoader,
            profileDirectory: profileDirectory,
            serverAddressLoader: Self.emptyServerLoader,
            litematicaLoader: Self.emptyLitematicaLoader,
        )
    }

    private func makeManagerWithLitematica(
        profileDirectory: URL,
        litematicaLoader: @escaping LitematicaLoader,
    ) -> SaveInfoManager {
        SaveInfoManager(
            gameName: "TestGame",
            modLoader: "fabric",
            profileDirectory: profileDirectory,
            serverAddressLoader: Self.emptyServerLoader,
            litematicaLoader: litematicaLoader,
        )
    }

    private func makeManagerWithServerLoader(
        profileDirectory: URL,
        serverAddressLoader: @escaping ServerAddressLoader,
    ) -> SaveInfoManager {
        SaveInfoManager(
            gameName: "TestGame",
            modLoader: "fabric",
            profileDirectory: profileDirectory,
            serverAddressLoader: serverAddressLoader,
            litematicaLoader: Self.emptyLitematicaLoader,
        )
    }

    private func item(
        _ kind: GameOverviewItem.Kind,
        in manager: SaveInfoManager,
    ) -> GameOverviewItem? {
        manager.resourceCounts.first { $0.kind == kind }
    }

    func testEmptyProfileYieldsZeroCounts() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }
        let manager = makeManager(profileDirectory: profile)

        await manager.loadData().value

        XCTAssertFalse(manager.isLoading)
        XCTAssertFalse(manager.hasWorldsType)
        XCTAssertFalse(manager.hasScreenshotsType)
        XCTAssertFalse(manager.hasLogsType)
        XCTAssertFalse(manager.hasLitematicaType)
        XCTAssertEqual(item(.mod, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.world, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.screenshot, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.log, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.server, in: manager)?.itemCount, 0)
        XCTAssertEqual(
            Set(manager.resourceCounts.map(\.kind)).count,
            manager.resourceCounts.count,
        )
    }

    func testOverviewKindMetadataMatchesResourceTypes() {
        XCTAssertEqual(GameOverviewItem.Kind.mod.resourceType, .mod)
        XCTAssertEqual(GameOverviewItem.Kind.datapack.resourceType, .datapack)
        XCTAssertEqual(GameOverviewItem.Kind.resourcepack.resourceType, .resourcepack)
        XCTAssertEqual(GameOverviewItem.Kind.shader.resourceType, .shader)
        XCTAssertEqual(GameOverviewItem.Kind.server.resourceType, .minecraftJavaServer)
        XCTAssertNil(GameOverviewItem.Kind.world.resourceType)
        XCTAssertEqual(GameOverviewItem.Kind.world.titleKey, "saveinfo.worlds")
        XCTAssertEqual(GameOverviewItem.Kind.litematica.systemImage, "square.stack.3d.up")
    }

    func testArchiveCountsUseJarZipDisableOnly() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        try writeFile("a.jar", in: "mods", profileDirectory: profile)
        try writeFile("ignored.txt", in: "mods", profileDirectory: profile)
        try writeFile("b.zip", in: "datapacks", profileDirectory: profile)
        try writeFile("c.disable", in: "datapacks", profileDirectory: profile)
        try writeFile("ignored.txt", in: "datapacks", profileDirectory: profile)
        try writeFile("d.jar", in: "shaderpacks", profileDirectory: profile)
        try writeFile("e.zip", in: "resourcepacks", profileDirectory: profile)

        let manager = makeManager(profileDirectory: profile)
        await manager.loadData().value

        XCTAssertEqual(item(.mod, in: manager)?.itemCount, 1)
        XCTAssertEqual(item(.datapack, in: manager)?.itemCount, 2)
        XCTAssertEqual(item(.shader, in: manager)?.itemCount, 1)
        XCTAssertEqual(item(.resourcepack, in: manager)?.itemCount, 1)
    }

    func testArchiveReadFailureMarksOverviewError() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        try Data().write(to: profile.appendingPathComponent("mods"))

        let manager = makeManager(profileDirectory: profile)
        await manager.loadData().value

        XCTAssertEqual(item(.mod, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.mod, in: manager)?.hasError, true)
    }

    func testSectionReadFailureMarksOverviewErrors() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        for name in ["saves", "screenshots", "logs"] {
            try Data().write(to: profile.appendingPathComponent(name))
        }

        let manager = makeManager(profileDirectory: profile)
        await manager.loadData().value

        XCTAssertEqual(item(.world, in: manager)?.hasError, true)
        XCTAssertEqual(item(.screenshot, in: manager)?.hasError, true)
        XCTAssertEqual(item(.log, in: manager)?.hasError, true)
    }

    func testVanillaHidesModsShadersAndLitematica() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        try writeFile("a.jar", in: "mods", profileDirectory: profile)
        try writeFile("b.zip", in: "shaderpacks", profileDirectory: profile)
        try writeFile("c.zip", in: "datapacks", profileDirectory: profile)

        let manager = makeManager(profileDirectory: profile, modLoader: "vanilla")
        await manager.loadData().value

        XCTAssertNil(item(.mod, in: manager))
        XCTAssertNil(item(.shader, in: manager))
        XCTAssertNil(item(.litematica, in: manager))
        XCTAssertEqual(item(.datapack, in: manager)?.itemCount, 1)
    }

    func testScreenshotAndLogExtensionFiltering() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        try writeFile("a.png", in: "screenshots", profileDirectory: profile)
        try writeFile("b.jpg", in: "screenshots", profileDirectory: profile)
        try writeFile("c.jpeg", in: "screenshots", profileDirectory: profile)
        try writeFile("d.PNG", in: "screenshots", profileDirectory: profile)
        try writeFile("ignored.txt", in: "screenshots", profileDirectory: profile)

        try writeFile("latest.log", in: "logs", profileDirectory: profile)
        try writeFile("rotated.log.gz", in: "logs", profileDirectory: profile)
        try writeFile("ignored.txt", in: "logs", profileDirectory: profile)
        try writeFile("crash-2024-01-01.txt", in: "crash-reports", profileDirectory: profile)

        let manager = makeManager(profileDirectory: profile)
        await manager.loadData().value

        XCTAssertEqual(manager.screenshots.count, 4)
        XCTAssertEqual(manager.logs.count, 2)
        XCTAssertEqual(item(.screenshot, in: manager)?.itemCount, 4)
        XCTAssertEqual(item(.log, in: manager)?.itemCount, 2)
        XCTAssertEqual(item(.log, in: manager)?.directories.count, 2)
        XCTAssertFalse(manager.logs.contains { $0.name.lowercased().hasSuffix(".log.gz") })
        XCTAssertEqual(manager.logs.first?.isCrashLog, true)
    }

    func testLitematicaInsertedBeforeWorlds() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        let schematics = profile.appendingPathComponent("schematics", isDirectory: true)
        let files = [
            LitematicaInfo(name: "a.litematic", path: schematics.appendingPathComponent("a.litematic")),
            LitematicaInfo(name: "b.litematic", path: schematics.appendingPathComponent("b.litematic")),
        ]
        let manager = makeManagerWithLitematica(profileDirectory: profile) { _ in
            files
        }
        await manager.loadData().value

        XCTAssertEqual(item(.litematica, in: manager)?.itemCount, 2)
        let kinds = manager.resourceCounts.map(\.kind)
        guard let litematicaIndex = kinds.firstIndex(of: .litematica),
              let worldIndex = kinds.firstIndex(of: .world) else {
            return XCTFail("Missing litematica or world overview item")
        }
        XCTAssertEqual(litematicaIndex, worldIndex - 1)
    }

    func testServerLoadFailureStillYieldsZeroCount() async throws {
        let profile = try makeProfileDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }

        let manager = makeManagerWithServerLoader(profileDirectory: profile) { _ in
            throw TestError.failed
        }
        await manager.loadData().value

        XCTAssertEqual(item(.server, in: manager)?.itemCount, 0)
        XCTAssertEqual(item(.server, in: manager)?.hasError, true)
    }
}
