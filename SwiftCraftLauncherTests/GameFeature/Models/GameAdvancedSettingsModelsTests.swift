//
//  GameAdvancedSettingsModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameAdvancedSettingsModelsTests: XCTestCase {

    func testGarbageCollector_allCases() {
        XCTAssertEqual(GarbageCollector.allCases.count, 5)
    }

    func testGarbageCollector_minimumJavaVersion() {
        XCTAssertEqual(GarbageCollector.g1gc.minimumJavaVersion, 7)
        XCTAssertEqual(GarbageCollector.parallel.minimumJavaVersion, 1)
        XCTAssertEqual(GarbageCollector.serial.minimumJavaVersion, 1)
        XCTAssertEqual(GarbageCollector.zgc.minimumJavaVersion, 11)
        XCTAssertEqual(GarbageCollector.shenandoah.minimumJavaVersion, 12)
    }

    func testGarbageCollector_isSupported() {
        XCTAssertTrue(GarbageCollector.g1gc.isSupported(by: 8))
        XCTAssertFalse(GarbageCollector.g1gc.isSupported(by: 6))
        XCTAssertTrue(GarbageCollector.zgc.isSupported(by: 11))
        XCTAssertFalse(GarbageCollector.zgc.isSupported(by: 10))
        XCTAssertTrue(GarbageCollector.shenandoah.isSupported(by: 12))
        XCTAssertFalse(GarbageCollector.shenandoah.isSupported(by: 11))
        XCTAssertTrue(GarbageCollector.parallel.isSupported(by: 8))
        XCTAssertTrue(GarbageCollector.serial.isSupported(by: 8))
    }

    func testGarbageCollector_arguments() {
        XCTAssertEqual(GarbageCollector.g1gc.arguments, ["-XX:+UseG1GC"])
        XCTAssertEqual(GarbageCollector.zgc.arguments, ["-XX:+UseZGC"])
        XCTAssertEqual(GarbageCollector.shenandoah.arguments, ["-XX:+UseShenandoahGC"])
        XCTAssertEqual(GarbageCollector.parallel.arguments, ["-XX:+UseParallelGC"])
        XCTAssertEqual(GarbageCollector.serial.arguments, ["-XX:+UseSerialGC"])
    }

    func testGarbageCollector_rawValues() {
        XCTAssertEqual(GarbageCollector.g1gc.rawValue, "g1gc")
        XCTAssertEqual(GarbageCollector.zgc.rawValue, "zgc")
        XCTAssertEqual(GarbageCollector.shenandoah.rawValue, "shenandoah")
        XCTAssertEqual(GarbageCollector.parallel.rawValue, "parallel")
        XCTAssertEqual(GarbageCollector.serial.rawValue, "serial")
    }

    func testOptimizationPreset_allCases() {
        XCTAssertEqual(OptimizationPreset.allCases.count, 4)
    }

    func testOptimizationPreset_rawValues() {
        XCTAssertEqual(OptimizationPreset.disabled.rawValue, "disabled")
        XCTAssertEqual(OptimizationPreset.basic.rawValue, "basic")
        XCTAssertEqual(OptimizationPreset.balanced.rawValue, "balanced")
        XCTAssertEqual(OptimizationPreset.maximum.rawValue, "maximum")
    }
}
