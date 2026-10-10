//
//  ModPackUpdateFilesTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest
import ZIPFoundation

final class ModPackUpdateFilesTests: XCTestCase {
    private var root = FileManager.default.temporaryDirectory.appendingPathComponent("scl-pack-tests-\(UUID().uuidString)")
    private var profile: URL { root.appendingPathComponent("profile") }
    private var payload: URL { root.appendingPathComponent("payload") }

    override func setUpWithError() throws {
        root = try TestSupport.makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, path: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func read(_ path: String, in directory: URL) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(path), encoding: .utf8)
    }

    private func pack(_ files: [String: String], version: String = "old") -> InstalledModPack {
        InstalledModPack(
            projectId: "pack-id",
            versionId: version,
            versionName: version,
            publishedAt: Date(),
            versionType: "release",
            files: files.mapValues { SHA1Calculator.sha1(of: Data($0.utf8)) },
        )
    }

    func testUpdateReplacesAndRemovesOwnedFilesButPreservesWorldsAndAddedMods() throws {
        try write("old", path: "mods/old.jar", in: profile)
        try write("removed", path: "mods/removed.jar", in: profile)
        try write("custom", path: "mods/custom.jar", in: profile)
        try write("world", path: "saves/world/level.dat", in: profile)
        try write("servers", path: "servers.dat", in: profile)
        try write("new", path: "mods/new.jar", in: payload)
        let replacement = root.appendingPathComponent("replacement")
        try FileManager.default.copyItem(at: profile, to: replacement)
        let old = pack(["mods/old.jar": "old", "mods/removed.jar": "removed"])
        let new = pack(["mods/new.jar": "new"], version: "new")

        try ModPackUpdateFiles.merge(old: old, new: new, payload: payload, replacement: replacement)

        XCTAssertFalse(FileManager.default.fileExists(atPath: replacement.appendingPathComponent("mods/old.jar").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: replacement.appendingPathComponent("mods/removed.jar").path))
        XCTAssertEqual(try read("mods/new.jar", in: replacement), "new")
        XCTAssertEqual(try read("mods/custom.jar", in: replacement), "custom")
        XCTAssertEqual(try read("saves/world/level.dat", in: replacement), "world")
        XCTAssertEqual(try read("servers.dat", in: replacement), "servers")
        XCTAssertEqual(try read("mods/old.jar", in: profile), "old")
        XCTAssertEqual(try InstalledModPack.load(from: replacement).versionId, "new")
    }

    func testModifiedSettingsArePreservedWhileUnmodifiedSettingsUpdate() throws {
        try write("user", path: "config/user.json", in: profile)
        try write("default", path: "config/default.json", in: profile)
        try write("new", path: "config/user.json", in: payload)
        try write("new", path: "config/default.json", in: payload)

        try ModPackUpdateFiles.merge(
            old: pack(["config/user.json": "default", "config/default.json": "default"]),
            new: pack(["config/user.json": "new", "config/default.json": "new"]),
            payload: payload,
            replacement: profile,
        )

        XCTAssertEqual(try read("config/user.json", in: profile), "user")
        XCTAssertEqual(try read("config/default.json", in: profile), "new")
    }

    func testModifiedModRejectsUpdate() throws {
        try write("modified", path: "mods/mod.jar", in: profile)
        try write("new", path: "mods/mod.jar", in: payload)
        XCTAssertThrowsError(try ModPackUpdateFiles.merge(
            old: pack(["mods/mod.jar": "old"]),
            new: pack(["mods/mod.jar": "new"]),
            payload: payload,
            replacement: profile,
        ))
        XCTAssertEqual(try read("mods/mod.jar", in: profile), "modified")
    }

    func testUserAddedModAtTargetPathRejectsUpdate() throws {
        try write("custom", path: "mods/new.jar", in: profile)
        try write("upstream", path: "mods/new.jar", in: payload)
        XCTAssertThrowsError(try ModPackUpdateFiles.merge(
            old: pack([:]), new: pack(["mods/new.jar": "upstream"]), payload: payload, replacement: profile,
        ))
        XCTAssertEqual(try read("mods/new.jar", in: profile), "custom")
    }

    func testDisabledModRemainsDisabledWhenItsContentsChange() throws {
        try write("old", path: "mods/mod.jar.disable", in: profile)
        try write("new", path: "mods/mod.jar", in: payload)
        try ModPackUpdateFiles.merge(
            old: pack(["mods/mod.jar": "old"]),
            new: pack(["mods/mod.jar": "new"]),
            payload: payload,
            replacement: profile,
        )
        XCTAssertEqual(try read("mods/mod.jar.disable", in: profile), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.appendingPathComponent("mods/mod.jar").path))
    }

    func testHashMismatchDoesNotReplaceInstalledFile() throws {
        try write("old", path: "mods/mod.jar", in: profile)
        try write("corrupt", path: "mods/mod.jar", in: payload)
        XCTAssertThrowsError(try ModPackUpdateFiles.merge(
            old: pack(["mods/mod.jar": "old"]),
            new: pack(["mods/mod.jar": "expected"]),
            payload: payload,
            replacement: profile,
        ))
        XCTAssertEqual(try read("mods/mod.jar", in: profile), "old")
    }

    func testLinkRequiresExactPackModsAndAcceptsDisabledMods() throws {
        try write("old", path: "mods/mod.jar.disable", in: profile)
        XCTAssertNoThrow(try ModPackUpdateFiles.validateLink(pack(["mods/mod.jar": "old"]), profile: profile))
        XCTAssertThrowsError(try ModPackUpdateFiles.validateLink(pack(["mods/mod.jar": "different"]), profile: profile))
        XCTAssertThrowsError(try ModPackUpdateFiles.validateLink(pack(["mods/missing.jar": "old"]), profile: profile))
    }

    func testRejectsTraversalAndProtectedUserPaths() {
        for path in ["../outside", "/tmp/outside", "mods/../../outside", "mods\\outside", "mods//mod.jar", "saves/world/level.dat", "logs/latest.log", "servers.dat", InstalledModPack.fileName] {
            XCTAssertThrowsError(try InstalledModPack.fileURL(path, in: profile), path)
        }
    }

    func testRejectsSymlinksIncludingAliasesInsideProfile() throws {
        try write("world", path: "saves/world/level.dat", in: profile)
        try FileManager.default.createSymbolicLink(
            at: profile.appendingPathComponent("config"),
            withDestinationURL: profile.appendingPathComponent("saves/world"),
        )
        XCTAssertThrowsError(try InstalledModPack.fileURL("config/level.dat", in: profile))
        XCTAssertEqual(try read("saves/world/level.dat", in: profile), "world")
    }

    func testReplacementKeepsBackupAndCanRestoreOriginal() throws {
        try write("old", path: "mods/mod.jar", in: profile)
        let backup = root.appendingPathComponent("backup")
        let replacement = root.appendingPathComponent("replacement")
        try FileManager.default.copyItem(at: profile, to: backup)
        try FileManager.default.copyItem(at: profile, to: replacement)
        try write("new", path: "mods/mod.jar", in: replacement)
        _ = try FileManager.default.replaceItemAt(profile, withItemAt: replacement)
        XCTAssertEqual(try read("mods/mod.jar", in: profile), "new")
        XCTAssertEqual(try read("mods/mod.jar", in: backup), "old")
        let restore = root.appendingPathComponent("restore")
        try FileManager.default.copyItem(at: backup, to: restore)
        _ = try FileManager.default.replaceItemAt(profile, withItemAt: restore)
        XCTAssertEqual(try read("mods/mod.jar", in: profile), "old")
    }

    func testUserAddedSettingNeverBecomesOwnedByLaterPacks() throws {
        try write("same", path: "config/user.json", in: profile)
        try write("same", path: "config/user.json", in: payload)
        try ModPackUpdateFiles.merge(
            old: pack([:]), new: pack(["config/user.json": "same"]), payload: payload, replacement: profile,
        )
        let installed = try InstalledModPack.load(from: profile)
        XCTAssertNil(installed.files["config/user.json"])
        try ModPackUpdateFiles.merge(old: installed, new: pack([:]), payload: payload, replacement: profile)
        XCTAssertEqual(try read("config/user.json", in: profile), "same")
    }

    func testDisabledFabricModStaysDisabledWhenJarNameChanges() throws {
        let source = root.appendingPathComponent("jar-content")
        try write("{\"id\":\"test-mod\",\"version\":\"1\"}", path: "fabric.mod.json", in: source)
        try FileManager.default.createDirectory(at: profile.appendingPathComponent("mods"), withIntermediateDirectories: true)
        let oldJar = profile.appendingPathComponent("mods/test-1.jar.disable")
        try FileManager.default.zipItem(at: source, to: oldJar, shouldKeepParent: false)
        try write("{\"id\":\"test-mod\",\"version\":\"2\"}", path: "fabric.mod.json", in: source)
        try FileManager.default.createDirectory(at: payload.appendingPathComponent("mods"), withIntermediateDirectories: true)
        let newJar = payload.appendingPathComponent("mods/test-2.jar")
        try FileManager.default.zipItem(at: source, to: newJar, shouldKeepParent: false)
        var old = pack([:])
        old.files["mods/test-1.jar"] = try SHA1Calculator.sha1(ofFileAt: oldJar)
        var new = pack([:])
        new.files["mods/test-2.jar"] = try SHA1Calculator.sha1(ofFileAt: newJar)

        try ModPackUpdateFiles.merge(old: old, new: new, payload: payload, replacement: profile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: profile.appendingPathComponent("mods/test-2.jar.disable").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.appendingPathComponent("mods/test-2.jar").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldJar.path))
    }

    func testProfileFingerprintDetectsAddedDeletedAndChangedFiles() throws {
        try write("original", path: "config/test.json", in: profile)
        let original = try ModPackUpdateFiles.profileFingerprint(profile)
        try write("added", path: "mods/new.jar", in: profile)
        XCTAssertNotEqual(try ModPackUpdateFiles.profileFingerprint(profile), original)
        try FileManager.default.removeItem(at: profile.appendingPathComponent("mods/new.jar"))
        try write("changed and longer", path: "config/test.json", in: profile)
        XCTAssertNotEqual(try ModPackUpdateFiles.profileFingerprint(profile), original)
    }
}
