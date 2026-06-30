//
//  DataPNGTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class DataPNGTests: XCTestCase {

    func testIsPNG_validPNGHeader_returnsTrue() {
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let data = Data(pngHeader)
        XCTAssertTrue(data.isPNG)
    }

    func testIsPNG_emptyData_returnsFalse() {
        let data = Data()
        XCTAssertFalse(data.isPNG)
    }

    func testIsPNG_jpegHeader_returnsFalse() {
        let jpegHeader: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0]
        let data = Data(jpegHeader)
        XCTAssertFalse(data.isPNG)
    }

    func testIsPNG_partialPNGHeader_returnsFalse() {
        let partialHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let data = Data(partialHeader)
        XCTAssertFalse(data.isPNG)
    }

    func testIsPNG_pngWithExtraData_returnsTrue() {
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        var data = Data(pngHeader)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x0D])
        XCTAssertTrue(data.isPNG)
    }

    func testIsPNG_singleByte_returnsFalse() {
        let data = Data([0x89])
        XCTAssertFalse(data.isPNG)
    }
}
