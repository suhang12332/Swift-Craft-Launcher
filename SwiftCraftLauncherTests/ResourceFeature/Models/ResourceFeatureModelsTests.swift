import XCTest
@testable import SwiftCraftLauncher

final class ResourceFeatureModelsTests: XCTestCase {

    // MARK: - LocalResourceFilter

    func testLocalResourceFilter_allCases() {
        XCTAssertEqual(LocalResourceFilter.allCases.count, 2)
    }

    func testLocalResourceFilter_rawValues() {
        XCTAssertEqual(LocalResourceFilter.all.rawValue, "all")
        XCTAssertEqual(LocalResourceFilter.disabled.rawValue, "disabled")
    }

    func testLocalResourceFilter_id() {
        XCTAssertEqual(LocalResourceFilter.all.id, "all")
        XCTAssertEqual(LocalResourceFilter.disabled.id, "disabled")
    }

    func testLocalResourceFilter_icon() {
        XCTAssertEqual(LocalResourceFilter.all.icon, "list.bullet")
        XCTAssertEqual(LocalResourceFilter.disabled.icon, "nosign")
    }
}
