//
//  ModPackExportFormatTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModPackExportFormatTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(ModPackExportFormat.modrinth.rawValue, "modrinth")
        XCTAssertEqual(ModPackExportFormat.curseforge.rawValue, "curseforge")
    }

    func testAllCases_count() {
        XCTAssertEqual(ModPackExportFormat.allCases.count, 2)
    }

    func testAllCases_containsBoth() {
        XCTAssertTrue(ModPackExportFormat.allCases.contains(.modrinth))
        XCTAssertTrue(ModPackExportFormat.allCases.contains(.curseforge))
    }

    func testDisplayName_modrinth() {
        XCTAssertEqual(ModPackExportFormat.modrinth.displayName, "Modrinth (.mrpack)")
    }

    func testDisplayName_curseforge() {
        XCTAssertEqual(ModPackExportFormat.curseforge.displayName, "CurseForge (.zip)")
    }

    func testFileExtension_modrinth() {
        XCTAssertFalse(ModPackExportFormat.modrinth.fileExtension.isEmpty)
    }

    func testFileExtension_curseforge() {
        XCTAssertFalse(ModPackExportFormat.curseforge.fileExtension.isEmpty)
    }

    func testFileExtension_differentFormats() {
        XCTAssertNotEqual(
            ModPackExportFormat.modrinth.fileExtension,
            ModPackExportFormat.curseforge.fileExtension,
        )
    }

    func testCodable_roundTrip() throws {
        let enc = JSONEncoder()
        let dec = JSONDecoder()

        for format in ModPackExportFormat.allCases {
            let data = try enc.encode(format)
            let decoded = try dec.decode(ModPackExportFormat.self, from: data)
            XCTAssertEqual(decoded, format)
        }
    }

    func testCodable_fromRawString() throws {
        let json = "\"curseforge\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ModPackExportFormat.self, from: data)
        XCTAssertEqual(decoded, .curseforge)
    }
}
