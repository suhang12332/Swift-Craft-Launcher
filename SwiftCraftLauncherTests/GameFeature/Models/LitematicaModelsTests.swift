import XCTest
@testable import SwiftCraftLauncher

final class LitematicaModelsTests: XCTestCase {

    // MARK: - LitematicaInfo

    func testLitematicaInfo_init_defaults() {
        let info = LitematicaInfo(
            name: "Test Build",
            path: URL(fileURLWithPath: "/tmp/test.litematic")
        )
        XCTAssertEqual(info.name, "Test Build")
        XCTAssertEqual(info.id, "test.litematic")
        XCTAssertNil(info.createdDate)
        XCTAssertEqual(info.fileSize, 0)
        XCTAssertNil(info.author)
        XCTAssertNil(info.description)
        XCTAssertNil(info.version)
        XCTAssertNil(info.regionCount)
        XCTAssertNil(info.totalBlocks)
    }

    func testLitematicaInfo_init_allFields() {
        let date = Date()
        let info = LitematicaInfo(
            name: "My Build",
            path: URL(fileURLWithPath: "/tmp/build.litematic"),
            createdDate: date,
            fileSize: 1024,
            author: "Builder",
            description: "A test build",
            version: "1.0",
            regionCount: 5,
            totalBlocks: 1000
        )
        XCTAssertEqual(info.name, "My Build")
        XCTAssertEqual(info.fileSize, 1024)
        XCTAssertEqual(info.author, "Builder")
        XCTAssertEqual(info.description, "A test build")
        XCTAssertEqual(info.version, "1.0")
        XCTAssertEqual(info.regionCount, 5)
        XCTAssertEqual(info.totalBlocks, 1000)
    }

    func testLitematicaInfo_equatable() {
        let a = LitematicaInfo(name: "Test", path: URL(fileURLWithPath: "/tmp/a.litematic"))
        let b = LitematicaInfo(name: "Test", path: URL(fileURLWithPath: "/tmp/a.litematic"))
        XCTAssertEqual(a, b)
    }

    func testLitematicaInfo_idFromPath() {
        let info = LitematicaInfo(
            name: "Build",
            path: URL(fileURLWithPath: "/some/deep/path/MyProject.litematic")
        )
        XCTAssertEqual(info.id, "MyProject.litematic")
    }

    // MARK: - LitematicaMetadata

    func testLitematicaMetadata_init() {
        let meta = LitematicaMetadata(
            author: "Builder",
            description: "A build",
            version: "1.0",
            regionCount: 3,
            totalBlocks: 500
        )
        XCTAssertEqual(meta.author, "Builder")
        XCTAssertEqual(meta.description, "A build")
        XCTAssertEqual(meta.version, "1.0")
        XCTAssertEqual(meta.regionCount, 3)
        XCTAssertEqual(meta.totalBlocks, 500)
    }

    func testLitematicaMetadata_nilFields() {
        let meta = LitematicaMetadata(
            author: nil,
            description: nil,
            version: nil,
            regionCount: nil,
            totalBlocks: nil
        )
        XCTAssertNil(meta.author)
        XCTAssertNil(meta.description)
        XCTAssertNil(meta.version)
    }

    // MARK: - LitematicMetadata

    func testLitematicMetadata_init() {
        let meta = LitematicMetadata(
            name: "Castle",
            author: "Builder",
            description: "A castle",
            timeCreated: 1000000,
            timeModified: 2000000,
            totalVolume: 100,
            totalBlocks: 80,
            enclosingSize: Size(x: 10, y: 10, z: 1),
            regionCount: 1
        )
        XCTAssertEqual(meta.name, "Castle")
        XCTAssertEqual(meta.author, "Builder")
        XCTAssertEqual(meta.description, "A castle")
        XCTAssertEqual(meta.timeCreated, 1000000)
        XCTAssertEqual(meta.timeModified, 2000000)
        XCTAssertEqual(meta.totalVolume, 100)
        XCTAssertEqual(meta.totalBlocks, 80)
        XCTAssertEqual(meta.enclosingSize.x, 10)
        XCTAssertEqual(meta.regionCount, 1)
    }

    // MARK: - Size

    func testSize_init() {
        let size = Size(x: 10, y: 20, z: 30)
        XCTAssertEqual(size.x, 10)
        XCTAssertEqual(size.y, 20)
        XCTAssertEqual(size.z, 30)
    }
}
