//
//  ModrinthIndexFilteringTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModrinthIndexFilteringTests: XCTestCase {
    func testIsClientInstallable_missingEnvironment_isInstallable() {
        let file = makeFile(path: "mods/a.jar", env: nil)
        XCTAssertTrue(file.isClientInstallable)
    }

    func testIsClientInstallable_missingClientValue_isInstallable() {
        let file = makeFile(path: "mods/a.jar", env: ModrinthIndexFileEnv(client: nil, server: "required"))
        XCTAssertTrue(file.isClientInstallable)
    }

    func testIsClientInstallable_requiredClient_isInstallable() {
        let file = makeFile(path: "mods/a.jar", env: ModrinthIndexFileEnv(client: "required", server: nil))
        XCTAssertTrue(file.isClientInstallable)
    }

    func testIsClientInstallable_unsupportedClient_isExcluded_caseInsensitive() {
        let file = makeFile(path: "mods/a.jar", env: ModrinthIndexFileEnv(client: "Unsupported", server: nil))
        XCTAssertFalse(file.isClientInstallable)
    }

    func testClientFiles_filtersUnsupportedAndPreservesOrder() {
        let index = makeIndex(
            files: [
                makeFile(path: "mods/a.jar", env: nil),
                makeFile(path: "mods/server-only.jar", env: ModrinthIndexFileEnv(client: "unsupported", server: "required")),
                makeFile(path: "mods/b.jar", env: ModrinthIndexFileEnv(client: "required", server: nil)),
            ],
            dependencies: [],
        )

        XCTAssertEqual(index.clientFiles.map(\.path), ["mods/a.jar", "mods/b.jar"])
    }

    func testRequiredDependencies_filtersOptional() {
        let index = makeIndex(
            files: [],
            dependencies: [
                ModrinthIndexProjectDependency(projectId: "required", versionId: nil, dependencyType: "required"),
                ModrinthIndexProjectDependency(projectId: "optional", versionId: nil, dependencyType: "optional"),
                ModrinthIndexProjectDependency(projectId: "incompatible", versionId: nil, dependencyType: "incompatible"),
            ],
        )

        XCTAssertEqual(index.requiredDependencies.map(\.projectId), ["required"])
    }

    private func makeIndex(
        files: [ModrinthIndexFile],
        dependencies: [ModrinthIndexProjectDependency],
    ) -> ModrinthIndexInfo {
        ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "fabric",
            loaderVersion: "0.14.0",
            modPackName: "Test Pack",
            modPackVersion: "1.0.0",
            summary: nil,
            files: files,
            dependencies: dependencies,
        )
    }

    private func makeFile(path: String, env: ModrinthIndexFileEnv?) -> ModrinthIndexFile {
        ModrinthIndexFile(
            path: path,
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: ["https://example.com/\(path)"],
            fileSize: 1,
            env: env,
        )
    }
}
