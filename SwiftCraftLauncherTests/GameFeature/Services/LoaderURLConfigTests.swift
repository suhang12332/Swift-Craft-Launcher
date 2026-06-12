import XCTest
@testable import SwiftCraftLauncher

final class LoaderURLConfigTests: XCTestCase {

    // MARK: - Fabric

    func testFabricLoaderURL() {
        let url = URLConfig.API.Fabric.loader
        XCTAssertEqual(url.absoluteString, "https://meta.fabricmc.net/v2/versions/loader")
    }

    func testFabricLoaderURL_withVersion() {
        let url = URLConfig.API.Fabric.loader.appendingPathComponent("1.20.1")
        XCTAssertTrue(url.absoluteString.hasSuffix("1.20.1"))
    }

    // MARK: - Quilt

    func testQuiltLoaderBaseURL() {
        let url = URLConfig.API.Quilt.loaderBase
        XCTAssertEqual(url.absoluteString, "https://meta.quiltmc.org/v3/versions/loader/")
    }

    func testQuiltLoaderBaseURL_withVersion() {
        let url = URLConfig.API.Quilt.loaderBase.appendingPathComponent("1.20.1")
        XCTAssertTrue(url.absoluteString.contains("1.20.1"))
    }

    // MARK: - Modrinth Loader Profile

    func testModrinthLoaderProfile_fabric() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: "0.14.21")
        XCTAssertTrue(url.absoluteString.contains("fabric"))
        XCTAssertTrue(url.absoluteString.contains("0.14.21"))
        XCTAssertTrue(url.absoluteString.contains("launcher-meta.modrinth.com"))
    }

    func testModrinthLoaderProfile_forge() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "forge", version: "47.2.0")
        XCTAssertTrue(url.absoluteString.contains("forge"))
        XCTAssertTrue(url.absoluteString.contains("47.2.0"))
    }

    func testModrinthLoaderProfile_neoForge() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "neo", version: "21.0.1")
        XCTAssertTrue(url.absoluteString.contains("neo"))
        XCTAssertTrue(url.absoluteString.contains("21.0.1"))
    }

    func testModrinthLoaderProfile_quilt() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "quilt", version: "0.26.0")
        XCTAssertTrue(url.absoluteString.contains("quilt"))
        XCTAssertTrue(url.absoluteString.contains("0.26.0"))
    }

    // MARK: - Modrinth Loader Manifest

    func testModrinthLoaderManifest_fabric() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "fabric")
        XCTAssertTrue(url.absoluteString.contains("fabric"))
        XCTAssertTrue(url.absoluteString.contains("manifest.json"))
    }

    func testModrinthLoaderManifest_neoForge() {
        let url = URLConfig.API.Modrinth.loaderManifest(loader: "neo")
        XCTAssertTrue(url.absoluteString.contains("neo"))
        XCTAssertTrue(url.absoluteString.contains("manifest.json"))
    }

    // MARK: - URL Structure Validation

    func testLoaderProfileURL_hasCorrectScheme() {
        let url = URLConfig.API.Modrinth.loaderProfile(loader: "fabric", version: "0.14.21")
        XCTAssertEqual(url.scheme, "https")
    }

    func testFabricLoaderURL_hasCorrectScheme() {
        let url = URLConfig.API.Fabric.loader
        XCTAssertEqual(url.scheme, "https")
    }

    func testQuiltLoaderBaseURL_hasCorrectScheme() {
        let url = URLConfig.API.Quilt.loaderBase
        XCTAssertEqual(url.scheme, "https")
    }
}
