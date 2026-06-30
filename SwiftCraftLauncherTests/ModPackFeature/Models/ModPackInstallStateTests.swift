//
//  ModPackInstallStateTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class ModPackInstallStateTests: XCTestCase {

    func testReset_clearsAllProperties() {
        let state = ModPackInstallState()
        state.isInstalling = true
        state.filesProgress = 0.5
        state.dependenciesProgress = 0.3
        state.overridesProgress = 0.7
        state.currentFile = "test.jar"
        state.currentDependency = "dep1"
        state.currentOverride = "override1"
        state.filesTotal = 10
        state.dependenciesTotal = 5
        state.overridesTotal = 3
        state.filesCompleted = 5
        state.dependenciesCompleted = 2
        state.overridesCompleted = 1

        state.reset()

        XCTAssertFalse(state.isInstalling)
        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.overridesProgress, 0)
        XCTAssertEqual(state.currentFile, "")
        XCTAssertEqual(state.currentDependency, "")
        XCTAssertEqual(state.currentOverride, "")
        XCTAssertEqual(state.filesTotal, 0)
        XCTAssertEqual(state.dependenciesTotal, 0)
        XCTAssertEqual(state.overridesTotal, 0)
        XCTAssertEqual(state.filesCompleted, 0)
        XCTAssertEqual(state.dependenciesCompleted, 0)
        XCTAssertEqual(state.overridesCompleted, 0)
    }

    func testStartInstallation_setsProperties() {
        let state = ModPackInstallState()

        state.startInstallation(filesTotal: 10, dependenciesTotal: 5, overridesTotal: 3)

        XCTAssertTrue(state.isInstalling)
        XCTAssertEqual(state.filesTotal, 10)
        XCTAssertEqual(state.dependenciesTotal, 5)
        XCTAssertEqual(state.overridesTotal, 3)
        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.overridesProgress, 0)
        XCTAssertEqual(state.filesCompleted, 0)
        XCTAssertEqual(state.dependenciesCompleted, 0)
    }

    func testStartInstallation_preservesOverridesTotal() {
        let state = ModPackInstallState()
        state.overridesTotal = 5

        state.startInstallation(filesTotal: 10, dependenciesTotal: 5, overridesTotal: 0)

        XCTAssertEqual(state.overridesTotal, 5)
    }

    func testUpdateFilesProgress() {
        let state = ModPackInstallState()

        state.updateFilesProgress(fileName: "mod.jar", completed: 5, total: 10)

        XCTAssertEqual(state.currentFile, "mod.jar")
        XCTAssertEqual(state.filesCompleted, 5)
        XCTAssertEqual(state.filesTotal, 10)
        XCTAssertEqual(state.filesProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateDependenciesProgress() {
        let state = ModPackInstallState()

        state.updateDependenciesProgress(dependencyName: "dep1", completed: 3, total: 5)

        XCTAssertEqual(state.currentDependency, "dep1")
        XCTAssertEqual(state.dependenciesCompleted, 3)
        XCTAssertEqual(state.dependenciesTotal, 5)
        XCTAssertEqual(state.dependenciesProgress, 0.6, accuracy: 0.001)
    }

    func testUpdateOverridesProgress() {
        let state = ModPackInstallState()

        state.updateOverridesProgress(overrideName: "override1", completed: 2, total: 4)

        XCTAssertEqual(state.currentOverride, "override1")
        XCTAssertEqual(state.overridesCompleted, 2)
        XCTAssertEqual(state.overridesTotal, 4)
        XCTAssertEqual(state.overridesProgress, 0.5, accuracy: 0.001)
    }

    func testDefaultValues() {
        let state = ModPackInstallState()

        XCTAssertFalse(state.isInstalling)
        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.overridesProgress, 0)
    }
}
