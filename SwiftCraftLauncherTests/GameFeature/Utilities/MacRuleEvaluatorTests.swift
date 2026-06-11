import XCTest
@testable import SwiftCraftLauncher

final class MacRuleEvaluatorTests: XCTestCase {

    // MARK: - MacOS.fromJavaArch

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
        XCTAssertEqual(MacOS.fromJavaArch("other"), .osx)
    }

    func testMacOS_fromJavaArch_caseInsensitive() {
        XCTAssertEqual(MacOS.fromJavaArch("AARCH64"), .osxArm64)
    }

    // MARK: - MacOS raw values

    func testMacOS_rawValues() {
        XCTAssertEqual(MacOS.osx.rawValue, "osx")
        XCTAssertEqual(MacOS.osxArm64.rawValue, "osx-arm64")
        XCTAssertEqual(MacOS.osxX86_64.rawValue, "osx-x86_64")
    }

    // MARK: - isLowVersion

    func testIsLowVersion_below1_19() {
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.18.2"))
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.12.2"))
        XCTAssertTrue(MacRuleEvaluator.isLowVersion("1.0"))
    }

    func testIsLowVersion_1_19AndAbove() {
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.19"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.19.4"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.20.1"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("1.21"))
    }

    func testIsLowVersion_invalidFormat() {
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("invalid"))
        XCTAssertFalse(MacRuleEvaluator.isLowVersion("a.b"))
    }

    // MARK: - convertFromMinecraftRules

    func testConvertFromMinecraftRules_empty() {
        let result = MacRuleEvaluator.convertFromMinecraftRules([])
        XCTAssertTrue(result.isEmpty)
    }

    func testConvertFromMinecraftRules_allowWithOsx() {
        let rules = [Rule(action: "allow", features: nil, os: OperatingSystem(name: "osx", version: nil, arch: nil))]
        let result = MacRuleEvaluator.convertFromMinecraftRules(rules)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.action, .allow)
        XCTAssertEqual(result.first?.os, .osx)
    }

    func testConvertFromMinecraftRules_disallowWithOsxArm64() {
        let rules = [Rule(action: "disallow", features: nil, os: OperatingSystem(name: "osx-arm64", version: nil, arch: nil))]
        let result = MacRuleEvaluator.convertFromMinecraftRules(rules)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.action, .disallow)
        XCTAssertEqual(result.first?.os, .osxArm64)
    }

    func testConvertFromMinecraftRules_nonMacOS_filteredOut() {
        let rules = [Rule(action: "allow", features: nil, os: OperatingSystem(name: "windows", version: nil, arch: nil))]
        let result = MacRuleEvaluator.convertFromMinecraftRules(rules)
        XCTAssertTrue(result.isEmpty)
    }

    func testConvertFromMinecraftRules_noOs() {
        let rules = [Rule(action: "allow", features: nil, os: nil)]
        let result = MacRuleEvaluator.convertFromMinecraftRules(rules)

        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.os)
    }

    func testConvertFromMinecraftRules_invalidAction_filteredOut() {
        let rules = [Rule(action: "invalid", features: nil, os: nil)]
        let result = MacRuleEvaluator.convertFromMinecraftRules(rules)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - RuleAction raw values

    func testRuleAction_rawValues() {
        XCTAssertEqual(RuleAction.allow.rawValue, "allow")
        XCTAssertEqual(RuleAction.disallow.rawValue, "disallow")
    }

    // MARK: - MacRule

    func testMacRule_struct() {
        let rule = MacRule(action: .allow, os: .osx)
        XCTAssertEqual(rule.action, .allow)
        XCTAssertEqual(rule.os, .osx)
    }
}
