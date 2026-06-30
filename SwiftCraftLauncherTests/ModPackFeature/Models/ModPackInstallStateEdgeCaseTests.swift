//
//  ModPackInstallStateEdgeCaseTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ModPackInstallStateEdgeCaseTests: XCTestCase {
    func testUpdateFilesProgress_zeroTotal_progressZero() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "mod.jar", completed: 5, total: 0)
        XCTAssertEqual(state.filesProgress, 0)
    }

    func testUpdateFilesProgress_completedExceedsTotal_clampedToOne() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "mod.jar", completed: 20, total: 10)
        XCTAssertEqual(state.filesProgress, 1.0)
    }

    func testUpdateFilesProgress_negativeCompleted_clampedToZero() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "mod.jar", completed: -1, total: 10)
        XCTAssertEqual(state.filesProgress, 0)
    }

    func testUpdateFilesProgress_zeroCompleted() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "mod.jar", completed: 0, total: 10)
        XCTAssertEqual(state.filesProgress, 0)
    }

    func testUpdateFilesProgress_exactHalf() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "mod.jar", completed: 5, total: 10)
        XCTAssertEqual(state.filesProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateDependenciesProgress_zeroTotal() {
        let state = ModPackInstallState()
        state.updateDependenciesProgress(dependencyName: "dep", completed: 3, total: 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
    }

    func testUpdateDependenciesProgress_completedExceedsTotal() {
        let state = ModPackInstallState()
        state.updateDependenciesProgress(dependencyName: "dep", completed: 10, total: 5)
        XCTAssertEqual(state.dependenciesProgress, 1.0)
    }

    func testUpdateDependenciesProgress_negativeCompleted() {
        let state = ModPackInstallState()
        state.updateDependenciesProgress(dependencyName: "dep", completed: -5, total: 10)
        XCTAssertEqual(state.dependenciesProgress, 0)
    }

    func testUpdateOverridesProgress_zeroTotal() {
        let state = ModPackInstallState()
        state.updateOverridesProgress(overrideName: "file", completed: 1, total: 0)
        XCTAssertEqual(state.overridesProgress, 0)
    }

    func testUpdateOverridesProgress_completedExceedsTotal() {
        let state = ModPackInstallState()
        state.updateOverridesProgress(overrideName: "file", completed: 100, total: 10)
        XCTAssertEqual(state.overridesProgress, 1.0)
    }

    func testStartInstallation_setsInstallingTrue() {
        let state = ModPackInstallState()
        XCTAssertFalse(state.isInstalling)
        state.startInstallation(filesTotal: 5, dependenciesTotal: 3)
        XCTAssertTrue(state.isInstalling)
    }

    func testStartInstallation_resetsProgressToZero() {
        let state = ModPackInstallState()
        state.filesProgress = 0.9
        state.dependenciesProgress = 0.8
        state.filesCompleted = 9
        state.dependenciesCompleted = 8

        state.startInstallation(filesTotal: 10, dependenciesTotal: 10)

        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.filesCompleted, 0)
        XCTAssertEqual(state.dependenciesCompleted, 0)
    }

    func testStartInstallation_doesNotResetOverridesTotalIfNonZero() {
        let state = ModPackInstallState()
        state.overridesTotal = 10

        // When overridesTotal is already non-zero, it's preserved regardless of parameter
        state.startInstallation(filesTotal: 5, dependenciesTotal: 3, overridesTotal: 0)
        XCTAssertEqual(state.overridesTotal, 10)

        state.overridesTotal = 10
        state.startInstallation(filesTotal: 5, dependenciesTotal: 3, overridesTotal: 5)
        // Non-zero overridesTotal is NOT updated because it was already non-zero
        XCTAssertEqual(state.overridesTotal, 10)
    }

    func testReset_afterProgress() {
        let state = ModPackInstallState()
        state.startInstallation(filesTotal: 10, dependenciesTotal: 5, overridesTotal: 3)
        state.updateFilesProgress(fileName: "a.jar", completed: 5, total: 10)
        state.updateDependenciesProgress(dependencyName: "dep1", completed: 2, total: 5)
        state.updateOverridesProgress(overrideName: "ov1", completed: 1, total: 3)

        state.reset()

        XCTAssertFalse(state.isInstalling)
        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.overridesProgress, 0)
        XCTAssertEqual(state.filesCompleted, 0)
        XCTAssertEqual(state.dependenciesCompleted, 0)
        XCTAssertEqual(state.overridesCompleted, 0)
        XCTAssertEqual(state.filesTotal, 0)
        XCTAssertEqual(state.dependenciesTotal, 0)
        XCTAssertEqual(state.overridesTotal, 0)
    }
}
