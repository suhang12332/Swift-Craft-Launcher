//
//  GameFeatureExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class GameFeatureExtendedTests: XCTestCase {
    func testMacOS_fromJavaArch_aarch64() {
        XCTAssertEqual(MacOS.fromJavaArch("aarch64"), .osxArm64)
    }

    func testMacOS_fromJavaArch_x86_64() {
        XCTAssertEqual(MacOS.fromJavaArch("x86_64"), .osxX86_64)
    }

    func testMacOS_fromJavaArch_amd64() {
        XCTAssertEqual(MacOS.fromJavaArch("amd64"), .osxX86_64)
    }

    func testMacOS_fromJavaArch_unknown() {
        XCTAssertEqual(MacOS.fromJavaArch("arm"), .osx)
    }

    func testMacOS_rawValues() {
        XCTAssertEqual(MacOS.osx.rawValue, "osx")
        XCTAssertEqual(MacOS.osxArm64.rawValue, "osx-arm64")
        XCTAssertEqual(MacOS.osxX86_64.rawValue, "osx-x86_64")
    }

    func testIsLowVersion_below119() {
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.18.2"))
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.8.9"))
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.12.2"))
    }

    func testIsLowVersion_atOrAbove119() {
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.19"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.19.4"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.20.1"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.21"))
    }

    func testIsLowVersion_invalidFormat() {
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("invalid"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1"))
    }

    func testRuleAction_rawValues() {
        XCTAssertEqual(RuleAction.allow.rawValue, "allow")
        XCTAssertEqual(RuleAction.disallow.rawValue, "disallow")
    }

    func testMavenCoordinateToRelativePath_basic() {
        let result = CommonService.mavenCoordinateToRelativePath("com.google.guava:guava:31.1-jre")
        guard let result else {
            XCTFail("Expected non-nil result"); return
        }
        XCTAssertTrue(result.contains("com/google/guava"))
        XCTAssertTrue(result.contains("guava-31.1-jre.jar"))
    }

    func testMavenCoordinateToRelativePath_withClassifier() {
        let result = CommonService.mavenCoordinateToRelativePath("org.lwjgl:lwjgl:3.3.1:natives-macos")
        XCTAssertEqual(result, "org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1-natives-macos.jar")
    }

    func testMavenCoordinateToRelativePath_tooFewParts() {
        let result = CommonService.mavenCoordinateToRelativePath("com.google:guava")
        XCTAssertNil(result)
    }

    func testMavenCoordinateToRelativePath_fiveParts() {
        let result = CommonService.mavenCoordinateToRelativePath("group:artifact:jar:classifier:1.0")
        XCTAssertEqual(result, "group/artifact/1.0/artifact-1.0-classifier.jar")
    }

    func testParseMavenCoordinateWithAtSymbol_basic() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("org.ow2.asm:asm:9.3@jar")
        XCTAssertTrue(result.contains("asm-9.3.jar"))
    }

    func testParseMavenCoordinateWithAtSymbol_noAt() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("com.google:guava:31.1-jre")
        XCTAssertTrue(result.contains("guava-31.1-jre.jar"))
    }

    func testParseMavenCoordinateWithAtSymbol_tooFewParts() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("com.google:guava")
        XCTAssertEqual(result, "com.google:guava")
    }

    func testIsLibraryAllowed_noRules_returnsTrue() throws {
        let json = Data("""
        {"name": "test", "downloads": {"artifact": {"path": "test.jar", "sha1": "", "size": 0, "url": ""}}, "rules": null}
        """.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testIsLibraryAllowed_emptyRules_returnsTrue() throws {
        let json = Data("""
        {"name": "test", "downloads": {"artifact": {"path": "test.jar", "sha1": "", "size": 0, "url": ""}}, "rules": []}
        """.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testShouldDownloadLibrary_notDownloadable_returnsFalse() throws {
        let json = Data("""
        {"name": "test", "downloads": {"artifact": {"path": "test.jar", "sha1": "", "size": 0, "url": ""}}, "downloadable": false}
        """.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        XCTAssertFalse(LibraryFilter.shouldDownloadLibrary(library))
    }

    func testShouldIncludeInClasspath_notDownloadable_returnsFalse() throws {
        let json = Data("""
        {"name": "test", "downloads": {"artifact": {"path": "test.jar", "sha1": "", "size": 0, "url": ""}}, "downloadable": false, "include_in_classpath": true}
        """.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testShouldIncludeInClasspath_notInClasspath_returnsFalse() throws {
        let json = Data("""
        {"name": "test", "downloads": {"artifact": {"path": "test.jar", "sha1": "", "size": 0, "url": ""}}, "downloadable": true, "include_in_classpath": false}
        """.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }
}
