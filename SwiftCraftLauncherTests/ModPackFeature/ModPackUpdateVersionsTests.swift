//
//  ModPackUpdateVersionsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ModPackUpdateVersionsTests: XCTestCase {
    private func version(
        _ id: String,
        date: TimeInterval,
        minecraft: String = "26.3",
        loader: String = "fabric",
        channel: String = "release",
        project: String = "pack-id",
    ) -> ModrinthProjectDetailVersion {
        ModrinthProjectDetailVersion(
            gameVersions: [minecraft],
            loaders: [loader],
            id: id,
            projectId: project,
            authorId: "author",
            featured: false,
            name: id,
            versionNumber: id,
            changelog: nil,
            changelogUrl: nil,
            datePublished: Date(timeIntervalSince1970: date),
            downloads: 0,
            versionType: channel,
            status: "listed",
            requestedStatus: nil,
            files: [.init(hashes: .init(sha512: "", sha1: ""), url: "https://example.com/pack.mrpack", filename: "pack.mrpack", primary: true, size: 1, fileType: nil)],
            dependencies: [],
        )
    }

    func testOnlyNewerCompatibleReleasesForStablePack() {
        let game = GameVersionInfo(gameName: "test", gameIcon: "", gameVersion: "26.3", assetIndex: "", modLoader: "fabric")
        let installed = InstalledModPack(
            projectId: "pack-id",
            versionId: "current",
            versionName: "current",
            publishedAt: Date(timeIntervalSince1970: 10),
            versionType: "release",
            files: [:],
        )
        let versions = [
            version("old", date: 1), version("current", date: 10),
            version("new", date: 20), version("newest", date: 30),
            version("beta", date: 40, channel: "beta"),
            version("other-game", date: 40, minecraft: "26.4"),
            version("other-loader", date: 40, loader: "neoforge"),
            version("other-project", date: 40, project: "other"),
        ]
        XCTAssertEqual(ModPackUpdateViewModel.eligibleVersions(versions, game: game, installed: installed).map(\.id), ["newest", "new"])
    }

    func testLegacyLinkCanSelectOlderInstalledVersion() {
        let game = GameVersionInfo(gameName: "test", gameIcon: "", gameVersion: "26.3", assetIndex: "", modLoader: "fabric")
        let versions = [version("old", date: 1), version("new", date: 20)]
        XCTAssertEqual(ModPackUpdateViewModel.eligibleVersions(versions, game: game, installed: nil).map(\.id), ["new", "old"])
    }

    func testProfileLockBlocksMutationsUntilUpdateEnds() throws {
        let profile = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: profile) }
        let status = GameStatusManager()
        let id = UUID().uuidString
        try status.beginModPackUpdate(gameId: id, profile: profile)
        XCTAssertTrue(status.isModPackUpdating(gameId: id))
        XCTAssertThrowsError(try status.withProfileWrite(at: profile.appendingPathComponent("mods/test.jar")) { })
        XCTAssertNoThrow(try status.withProfileWrite(at: profile.deletingLastPathComponent().appendingPathComponent("unrelated")) { })
        status.endModPackUpdate(gameId: id)
        XCTAssertNoThrow(try status.withProfileWrite(at: profile) { })
        XCTAssertFalse(status.isModPackUpdating(gameId: id))
    }
}
