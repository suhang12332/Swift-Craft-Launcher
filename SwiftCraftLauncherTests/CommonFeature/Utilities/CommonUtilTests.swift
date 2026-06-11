import XCTest
@testable import SwiftCraftLauncher

final class CommonUtilTests: XCTestCase {
    func testIsMinecraftSnapshotVersion_release_returnsFalse() {
        XCTAssertFalse(CommonUtil.isMinecraftSnapshotVersion("1.21.4"))
    }

    func testIsMinecraftSnapshotVersion_snapshot_returnsTrue() {
        XCTAssertTrue(CommonUtil.isMinecraftSnapshotVersion("26w11a"))
    }

    func testCompareMinecraftVersions_greater() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.21", "1.20.6"), 1)
    }

    func testCompareMinecraftVersions_equal() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.20", "1.20"), 0)
    }

    func testCompareMinecraftVersions_less() {
        XCTAssertEqual(CommonUtil.compareMinecraftVersions("1.19", "1.20"), -1)
    }

    func testIsVersionAtLeast_baseline() {
        XCTAssertTrue(CommonUtil.isVersionAtLeast("1.20"))
        XCTAssertFalse(CommonUtil.isVersionAtLeast("1.12"))
    }

    func testSortMinecraftVersions_descending() {
        let sorted = CommonUtil.sortMinecraftVersions(["1.18", "1.21", "1.20"])
        XCTAssertEqual(sorted, ["1.21", "1.20", "1.18"])
    }

    func testVersionsAtLeast_withBaselineInList() {
        let versions = ["1.12", "1.13", "1.14", "1.15"]
        let result = CommonUtil.versionsAtLeast(versions, baseline: "1.13")
        XCTAssertEqual(result, ["1.12", "1.13"])
    }

    func testVersionsAtLeast_withoutBaseline_filtersByComparison() {
        let versions = ["1.11", "1.14", "1.16"]
        let result = CommonUtil.versionsAtLeast(versions, baseline: "1.13")
        XCTAssertEqual(result, ["1.14", "1.16"])
    }

    func testMinecraftLanguageCode_zhHans() {
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "zh-Hans"), "zh_cn")
    }

    func testMinecraftLanguageCode_unknownDefaultsToEnglish() {
        XCTAssertEqual(CommonUtil.minecraftLanguageCode(from: "xx"), "en_us")
    }

    func testMinecraftReleaseNewsSlug() {
        XCTAssertEqual(
            CommonUtil.minecraftReleaseNewsSlug(version: "1.26.1"),
            "minecraft-java-edition-1-26-1"
        )
    }

    func testMinecraftSnapshotNewsSlug_weekly() {
        XCTAssertEqual(
            CommonUtil.minecraftSnapshotNewsSlug(version: "26w11a"),
            "minecraft-snapshot-26w11a"
        )
    }

    func testMinecraftSnapshotNewsSlug_rc() {
        XCTAssertEqual(
            CommonUtil.minecraftSnapshotNewsSlug(version: "26.1.2-rc-1"),
            "minecraft-26-1-2-release-candidate-1"
        )
    }

    func testParseServerInfo_addressOnly() {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: "play.example.com")
        XCTAssertEqual(parsed.address, "play.example.com")
        XCTAssertNil(parsed.playersText)
    }

    func testParseServerInfo_addressAndOnline() {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: "play.example.com | 12")
        XCTAssertEqual(parsed.address, "play.example.com")
        XCTAssertEqual(parsed.playersText, "12")
    }

    func testParseServerInfo_addressOnlineMax() {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: "play.example.com | 5 | 20")
        XCTAssertEqual(parsed.address, "play.example.com")
        XCTAssertEqual(parsed.playersText, "5 / 20")
    }

    func testParseServerInfo_empty_returnsEmpty() {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: "   ")
        XCTAssertEqual(parsed.address, "")
        XCTAssertNil(parsed.playersText)
    }

    func testImageDataFromBase64_raw() {
        let payload = Data("hello".utf8).base64EncodedString()
        XCTAssertEqual(CommonUtil.imageDataFromBase64(payload), Data("hello".utf8))
    }

    func testImageDataFromBase64_dataUriPrefix() {
        let raw = Data("skin".utf8).base64EncodedString()
        let dataURI = "data:image/png;base64,\(raw)"
        XCTAssertEqual(CommonUtil.imageDataFromBase64(dataURI), Data("skin".utf8))
    }

    func testImageDataFromBase64_invalid_returnsNil() {
        XCTAssertNil(CommonUtil.imageDataFromBase64("%%%not-base64%%%"))
    }
}
