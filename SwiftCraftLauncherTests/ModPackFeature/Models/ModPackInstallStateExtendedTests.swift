import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class ModPackInstallStateExtendedTests: XCTestCase {

    // MARK: - calculateProgress edge cases

    func testUpdateFilesProgress_zeroTotal() {
        let state = ModPackInstallState()

        state.updateFilesProgress(fileName: "file", completed: 5, total: 0)

        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.filesCompleted, 5)
    }

    func testUpdateFilesProgress_completedExceedsTotal() {
        let state = ModPackInstallState()

        state.updateFilesProgress(fileName: "file", completed: 15, total: 10)

        XCTAssertEqual(state.filesProgress, 1.0, accuracy: 0.001)
    }

    func testUpdateFilesProgress_negativeCompleted() {
        let state = ModPackInstallState()

        state.updateFilesProgress(fileName: "file", completed: -1, total: 10)

        XCTAssertEqual(state.filesProgress, 0.0, accuracy: 0.001)
    }

    func testUpdateDependenciesProgress_zeroTotal() {
        let state = ModPackInstallState()

        state.updateDependenciesProgress(dependencyName: "dep", completed: 3, total: 0)

        XCTAssertEqual(state.dependenciesProgress, 0)
    }

    func testUpdateDependenciesProgress_completedExceedsTotal() {
        let state = ModPackInstallState()

        state.updateDependenciesProgress(dependencyName: "dep", completed: 10, total: 5)

        XCTAssertEqual(state.dependenciesProgress, 1.0, accuracy: 0.001)
    }

    func testUpdateOverridesProgress_zeroTotal() {
        let state = ModPackInstallState()

        state.updateOverridesProgress(overrideName: "ov", completed: 2, total: 0)

        XCTAssertEqual(state.overridesProgress, 0)
    }

    func testUpdateOverridesProgress_completedExceedsTotal() {
        let state = ModPackInstallState()

        state.updateOverridesProgress(overrideName: "ov", completed: 10, total: 3)

        XCTAssertEqual(state.overridesProgress, 1.0, accuracy: 0.001)
    }

    // MARK: - startInstallation edge cases

    func testStartInstallation_zeroTotals() {
        let state = ModPackInstallState()

        state.startInstallation(filesTotal: 0, dependenciesTotal: 0, overridesTotal: 0)

        XCTAssertTrue(state.isInstalling)
        XCTAssertEqual(state.filesTotal, 0)
        XCTAssertEqual(state.dependenciesTotal, 0)
        XCTAssertEqual(state.overridesTotal, 0)
    }

    func testStartInstallation_preservesPreviousOverridesTotal() {
        let state = ModPackInstallState()
        state.overridesTotal = 10

        state.startInstallation(filesTotal: 5, dependenciesTotal: 3, overridesTotal: 0)

        XCTAssertEqual(state.overridesTotal, 10)
    }

    func testStartInstallation_overridesTotalGreaterThanZero() {
        let state = ModPackInstallState()

        state.startInstallation(filesTotal: 5, dependenciesTotal: 3, overridesTotal: 7)

        XCTAssertEqual(state.overridesTotal, 7)
    }

    func testStartInstallation_overridesCompletedNonZeroPreservesProgress() {
        let state = ModPackInstallState()
        state.overridesCompleted = 3
        state.overridesProgress = 0.5

        state.startInstallation(filesTotal: 5, dependenciesTotal: 3, overridesTotal: 0)

        XCTAssertEqual(state.overridesProgress, 0.5, accuracy: 0.001)
    }

    // MARK: - reset after multiple updates

    func testReset_afterMultipleUpdates() {
        let state = ModPackInstallState()
        state.startInstallation(filesTotal: 10, dependenciesTotal: 5, overridesTotal: 3)
        state.updateFilesProgress(fileName: "f.jar", completed: 5, total: 10)
        state.updateDependenciesProgress(dependencyName: "d.jar", completed: 2, total: 5)
        state.updateOverridesProgress(overrideName: "o.jar", completed: 1, total: 3)

        state.reset()

        XCTAssertFalse(state.isInstalling)
        XCTAssertEqual(state.filesProgress, 0)
        XCTAssertEqual(state.dependenciesProgress, 0)
        XCTAssertEqual(state.overridesProgress, 0)
        XCTAssertEqual(state.filesCompleted, 0)
        XCTAssertEqual(state.dependenciesCompleted, 0)
        XCTAssertEqual(state.overridesCompleted, 0)
        XCTAssertEqual(state.currentFile, "")
        XCTAssertEqual(state.currentDependency, "")
        XCTAssertEqual(state.currentOverride, "")
    }

    // MARK: - Progress values

    func testFilesProgress_half() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "f.jar", completed: 5, total: 10)
        XCTAssertEqual(state.filesProgress, 0.5, accuracy: 0.001)
    }

    func testFilesProgress_complete() {
        let state = ModPackInstallState()
        state.updateFilesProgress(fileName: "f.jar", completed: 10, total: 10)
        XCTAssertEqual(state.filesProgress, 1.0, accuracy: 0.001)
    }

    func testDependenciesProgress_half() {
        let state = ModPackInstallState()
        state.updateDependenciesProgress(dependencyName: "d.jar", completed: 5, total: 10)
        XCTAssertEqual(state.dependenciesProgress, 0.5, accuracy: 0.001)
    }

    func testOverridesProgress_half() {
        let state = ModPackInstallState()
        state.updateOverridesProgress(overrideName: "o.jar", completed: 5, total: 10)
        XCTAssertEqual(state.overridesProgress, 0.5, accuracy: 0.001)
    }
}
