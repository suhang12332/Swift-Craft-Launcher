//
//  ResourceFilterStateTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ResourceFilterStateTests: XCTestCase {
    func testInit_defaultValues() {
        let state = ResourceFilterState()

        XCTAssertTrue(state.selectedVersions.isEmpty)
        XCTAssertTrue(state.selectedLicenses.isEmpty)
        XCTAssertTrue(state.selectedCategories.isEmpty)
        XCTAssertTrue(state.selectedFeatures.isEmpty)
        XCTAssertTrue(state.selectedResolutions.isEmpty)
        XCTAssertTrue(state.selectedPerformanceImpact.isEmpty)
        XCTAssertTrue(state.selectedLoaders.isEmpty)
        XCTAssertEqual(state.sortIndex, AppConstants.modrinthIndex)
        XCTAssertEqual(state.versionCurrentPage, 1)
        XCTAssertEqual(state.versionTotal, 0)
        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertEqual(state.searchText, "")
        XCTAssertEqual(state.localResourceFilter, .all)
    }

    func testClearFiltersAndPagination() {
        let state = ResourceFilterState()

        state.selectedVersions = ["1.20.1", "1.19.4"]
        state.selectedLicenses = ["MIT"]
        state.selectedCategories = ["fabric"]
        state.selectedFeatures = ["server"]
        state.selectedResolutions = ["1080p"]
        state.selectedPerformanceImpact = ["low"]
        state.selectedLoaders = ["fabric"]
        state.sortIndex = "downloads"
        state.versionCurrentPage = 3
        state.versionTotal = 100
        state.selectedTab = 2

        state.clearFiltersAndPagination()

        XCTAssertTrue(state.selectedVersions.isEmpty)
        XCTAssertTrue(state.selectedLicenses.isEmpty)
        XCTAssertTrue(state.selectedCategories.isEmpty)
        XCTAssertTrue(state.selectedFeatures.isEmpty)
        XCTAssertTrue(state.selectedResolutions.isEmpty)
        XCTAssertTrue(state.selectedPerformanceImpact.isEmpty)
        XCTAssertTrue(state.selectedLoaders.isEmpty)
        XCTAssertEqual(state.sortIndex, AppConstants.modrinthIndex)
        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertEqual(state.versionCurrentPage, 1)
        XCTAssertEqual(state.versionTotal, 0)
    }

    func testClearSearchText() {
        let state = ResourceFilterState()
        state.searchText = "fabric api"

        state.clearSearchText()

        XCTAssertEqual(state.searchText, "")
    }

    func testBindingGetters_defaultValues() {
        let state = ResourceFilterState()

        XCTAssertEqual(state.selectedVersionsBinding.wrappedValue, [])
        XCTAssertEqual(state.sortIndexBinding.wrappedValue, AppConstants.modrinthIndex)
        XCTAssertEqual(state.searchTextBinding.wrappedValue, "")
        XCTAssertEqual(state.localResourceFilterBinding.wrappedValue, .all)
    }
}
