//
//  CommonUtilExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CommonUtilExtendedTests: XCTestCase {

    func testForceHTTPS_httpToHttps() {
        let url = URL.require("http://example.com/path")
        let result = url.forceHTTPS()
        XCTAssertEqual(result?.scheme, "https")
    }

    func testForceHTTPS_alreadyHttps() {
        let url = URL.require("https://example.com/path")
        let result = url.forceHTTPS()
        XCTAssertEqual(result, url)
    }

    func testForceHTTPS_otherScheme() {
        let url = URL.require("ftp://example.com/path")
        let result = url.forceHTTPS()
        XCTAssertEqual(result, url)
    }

    func testHttpToHttps_convertsUrl() {
        let result = "http://example.com/path".httpToHttps()
        XCTAssertTrue(result.hasPrefix("https://"))
    }

    func testHttpToHttps_alreadyHttps() {
        let input = "https://example.com/path"
        let result = input.httpToHttps()
        XCTAssertEqual(result, input)
    }

    func testHttpToHttps_invalidUrl() {
        let result = "not a url".httpToHttps()
        XCTAssertFalse(result.isEmpty)
    }

    func testIsMinecraftSnapshotVersion_weekly() {
        XCTAssertTrue(CommonUtil.isMinecraftSnapshotVersion("24w11a"))
    }

    func testIsMinecraftSnapshotVersion_preRelease() {
        XCTAssertTrue(CommonUtil.isMinecraftSnapshotVersion("1.20.1-rc1"))
    }

    func testIsMinecraftSnapshotVersion_beta() {
        XCTAssertTrue(CommonUtil.isMinecraftSnapshotVersion("1.20.1-beta"))
    }

    func testIsMinecraftSnapshotVersion_release() {
        XCTAssertFalse(CommonUtil.isMinecraftSnapshotVersion("1.20.1"))
    }

    func testIsMinecraftSnapshotVersion_singleNumber() {
        XCTAssertFalse(CommonUtil.isMinecraftSnapshotVersion("20"))
    }

    func testCompareMinecraftVersions_sameVersion() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20.1", "1.20.1"), 0)
    }

    func testCompareMinecraftVersions_majorDifference() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("2.0.0", "1.9.9"), 1)
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.9.9", "2.0.0"), -1)
    }

    func testCompareMinecraftVersions_minorDifference() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.21.0", "1.20.9"), 1)
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20.9", "1.21.0"), -1)
    }

    func testCompareMinecraftVersions_patchDifference() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20.2", "1.20.1"), 1)
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20.1", "1.20.2"), -1)
    }

    func testCompareMinecraftVersions_differentLengths() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20.1.0", "1.20.1"), 0)
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20", "1.20.0"), 0)
    }

    func testMinecraftReleaseNewsSlug_simpleVersion() {
        let slug = CommonUtil.minecraftReleaseNewsSlug(version: "1.21")
        XCTAssertEqual(slug, "minecraft-java-edition-1-21")
    }

    func testMinecraftReleaseNewsSlug_threeParts() {
        let slug = CommonUtil.minecraftReleaseNewsSlug(version: "1.20.4")
        XCTAssertEqual(slug, "minecraft-java-edition-1-20-4")
    }

    func testMinecraftSnapshotNewsSlug_weekly() {
        let slug = CommonUtil.minecraftSnapshotNewsSlug(version: "24w11a")
        XCTAssertEqual(slug, "minecraft-snapshot-24w11a")
    }

    func testMinecraftSnapshotNewsSlug_releaseCandidate() {
        let slug = CommonUtil.minecraftSnapshotNewsSlug(version: "1.21-rc-1")
        XCTAssertTrue(slug.contains("release-candidate"))
    }

    func testMinecraftSnapshotNewsSlug_preRelease() {
        let slug = CommonUtil.minecraftSnapshotNewsSlug(version: "1.21-pre-3")
        XCTAssertTrue(slug.contains("pre-release"))
    }

    func testMinecraftLanguageCode_allKnown() {
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "zh-Hans"), "zh_cn")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "zh-Hant"), "zh_tw")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "en"), "en_us")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "ja"), "ja_jp")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "ko"), "ko_kr")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "de"), "de_de")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "fr"), "fr_fr")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "es"), "es_es")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "pt"), "pt_br")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "ru"), "ru_ru")
    }

    func testMinecraftLanguageCode_unknown() {
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "xx"), "en_us")
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: ""), "en_us")
    }

    func testParseMinecraftJavaServerInfo_addressOnly() {
        let result = CommonUtil.parseMinecraftJavaServerInfo(from: "mc.example.com")
        XCTAssertEqual(result.address, "mc.example.com")
        XCTAssertNil(result.playersText)
    }

    func testParseMinecraftJavaServerInfo_withOnline() {
        let result = CommonUtil.parseMinecraftJavaServerInfo(from: "mc.example.com | 5")
        XCTAssertEqual(result.playersText, "5")
    }

    func testParseMinecraftJavaServerInfo_withOnlineAndMax() {
        let result = CommonUtil.parseMinecraftJavaServerInfo(from: "mc.example.com | 5 | 20")
        XCTAssertEqual(result.playersText, "5 / 20")
    }

    func testParseMinecraftJavaServerInfo_empty() {
        let result = CommonUtil.parseMinecraftJavaServerInfo(from: "")
        XCTAssertEqual(result.address, "")
    }

    func testParseMinecraftJavaServerInfo_whitespaceOnly() {
        let result = CommonUtil.parseMinecraftJavaServerInfo(from: "   ")
        XCTAssertEqual(result.address, "")
    }
}
