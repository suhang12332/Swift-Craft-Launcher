//
//  LoaderURLConfigTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class LoaderURLConfigTests: XCTestCase {
    func testModrinthLoaderManifest_fabric() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "fabric")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/fabric/v0/manifest.json")
    }

    func testModrinthLoaderManifest_forge() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "forge")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/forge/v0/manifest.json")
    }

    func testModrinthLoaderManifest_neoForge() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "neo")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/neo/v0/manifest.json")
    }

    func testModrinthLoaderManifest_quilt() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "quilt")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/quilt/v1/manifest.json")
    }

    func testModrinthLoaderProfile_fabric() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: "0.14.21")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/fabric/v0/versions/0.14.21.json")
    }

    func testModrinthLoaderProfile_forge() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "forge", version: "47.2.0")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/forge/v0/versions/47.2.0.json")
    }

    func testModrinthLoaderProfile_neoForge() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "neo", version: "21.0.1")
        XCTAssertEqual(url.absoluteString, "https://launcher-meta.modrinth.com/neo/v0/versions/21.0.1.json")
    }

    func testModrinthQuiltLoaderProfile() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: "0.26.0", versionGroup: "v1")
        XCTAssertEqual(
            url.absoluteString,
            "https://launcher-meta.modrinth.com/quilt/v1/version-group/v1/loader-version/0.26.0"
        )
    }

    func testModrinthQuiltLoaderProfile_otherGroup() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: "0.30.0", versionGroup: "v2")
        XCTAssertEqual(
            url.absoluteString,
            "https://launcher-meta.modrinth.com/quilt/v1/version-group/v2/loader-version/0.30.0"
        )
    }

    func testModrinthLoaderURLs_useHTTPS() {
        XCTAssertEqual(URLConfig.API.Modrinth.loaderManifest(loader: "quilt").scheme, "https")
        XCTAssertEqual(URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: "0.14.21").scheme, "https")
        XCTAssertEqual(URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: "0.26.0", versionGroup: "v1").scheme, "https")
    }
}
