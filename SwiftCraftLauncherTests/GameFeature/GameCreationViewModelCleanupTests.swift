//
//  GameCreationViewModelCleanupTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import SwiftUI
import XCTest

@MainActor
final class GameCreationViewModelCleanupTests: XCTestCase {
    private func makeViewModel() -> GameCreationViewModel {
        let config = GameFormConfiguration(
            isDownloading: .constant(false),
            isFormValid: .constant(false),
            triggerConfirm: .constant(false),
            triggerCancel: .constant(false),
            onCancel: { },
            onConfirm: { },
        )
        return GameCreationViewModel(configuration: config)
    }

    func testClearLoadedVersionsOnClose_resetsAllVersionState() {
        let vm = makeViewModel()
        vm.availableVersions = ["1.20.1", "1.21.1"]
        vm.availableLoaderVersions = ["0.14.0", "0.15.0"]
        vm.selectedGameVersion = "1.20.1"
        vm.selectedLoaderVersion = "0.14.0"
        vm.versionTime = "2024-01-01"
        vm.didInit = true

        vm.clearLoadedVersionsOnClose()

        XCTAssertTrue(vm.availableVersions.isEmpty)
        XCTAssertTrue(vm.availableLoaderVersions.isEmpty)
        XCTAssertEqual(vm.selectedGameVersion, "")
        XCTAssertEqual(vm.selectedLoaderVersion, "")
        XCTAssertEqual(vm.versionTime, "")
        XCTAssertFalse(vm.didInit)
    }

    func testClearLoadedVersionsOnClose_fromEmptyState_succeeds() {
        let vm = makeViewModel()
        vm.clearLoadedVersionsOnClose()
        XCTAssertTrue(vm.availableVersions.isEmpty)
        XCTAssertTrue(vm.availableLoaderVersions.isEmpty)
    }
}
