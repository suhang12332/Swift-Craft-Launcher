import XCTest
@testable import SwiftCraftLauncher

final class CacheCalculatorTests: XCTestCase {

    func testCacheInfo_init() {
        let info = CacheInfo(fileCount: 10, totalSize: 1024)
        XCTAssertEqual(info.fileCount, 10)
        XCTAssertEqual(info.totalSize, 1024)
        XCTAssertFalse(info.formattedSize.isEmpty)
    }

    func testCacheInfo_equatable() {
        let a = CacheInfo(fileCount: 5, totalSize: 500)
        let b = CacheInfo(fileCount: 5, totalSize: 500)
        let c = CacheInfo(fileCount: 5, totalSize: 1000)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCacheInfo_formatFileSize_zero() {
        let result = CacheInfo.formatFileSize(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testCacheInfo_formatFileSize_nonZero() {
        let result = CacheInfo.formatFileSize(1024 * 1024)
        XCTAssertFalse(result.isEmpty)
    }
}
