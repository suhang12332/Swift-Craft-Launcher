//
//  HTMLToMarkdownConverterTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class HTMLToMarkdownConverterTests: XCTestCase {
    func testTestModFixtureCoversSupportedHTML() throws {
        let fixtureURL = TestSupport.fixtureURL(
            subdirectory: "Fixtures/modrinth",
            name: "html_test_mod",
            extension: "html",
        )
        let html = try String(contentsOf: fixtureURL, encoding: .utf8)

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("# HTML Test Mod"))
        XCTAssertTrue(markdown.contains("**bold**"))
        XCTAssertTrue(markdown.contains("*italic*"))
        XCTAssertTrue(markdown.contains("~~struck~~"))
        XCTAssertTrue(markdown.contains("[project page](https://example.com/project)"))
        XCTAssertTrue(markdown.contains("[Download](https://example.com/download)"))
        XCTAssertTrue(markdown.contains("![Test icon](https://example.com/icon.png)"))
        XCTAssertTrue(markdown.contains("Block one\nBlock two"))
        XCTAssertTrue(markdown.contains("---"))
        XCTAssertTrue(markdown.contains("> A quoted line"))
        XCTAssertTrue(markdown.contains("`inlineCode()`"))
        XCTAssertTrue(markdown.contains("```\npublic func testMod()"))
        XCTAssertTrue(markdown.contains("- Fabric"))
        XCTAssertTrue(markdown.contains("1. Install the mod"))
        XCTAssertTrue(markdown.contains("| Loader | Version |"))
        XCTAssertTrue(markdown.contains("| Fabric | 1.21 |"))
        XCTAssertTrue(markdown.contains("[Demo video](https://example.com/demo.mp4)"))
        XCTAssertTrue(markdown.contains("[🔊 Audio](https://example.com/demo.mp3)"))
        XCTAssertTrue(markdown.contains("[Test icon]"))
        XCTAssertTrue(markdown.contains("Advanced details"))
        XCTAssertFalse(markdown.contains("alert('must not execute')"))
        XCTAssertFalse(markdown.contains("color: red"))
    }

    func testButtonOnclickIsConvertedToSafeLink() {
        let html = #"<button onclick="window.open('https://example.com/install')">Install</button>"#

        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(html),
            "[Install](https://example.com/install)",
        )
    }

    func testUnsafeLinksAreNotEmittedAsMarkdownLinks() {
        let html = #"<a href="javascript:alert('x')">Unsafe</a><img src="file:///tmp/secret" alt="Secret">"#

        XCTAssertEqual(HTMLToMarkdownConverter.convert(html), "UnsafeSecret")
    }

    func testEntitiesAndUnknownTagsKeepReadableText() {
        let html = "<custom>Tom &amp; Jerry</custom><span> still readable</span>"

        XCTAssertEqual(HTMLToMarkdownConverter.convert(html), "Tom & Jerry still readable")
    }

    func testNestedListsKeepTheirStructure() {
        let html = "<ul><li>Parent<ul><li>Child</li></ul></li></ul>"

        XCTAssertEqual(HTMLToMarkdownConverter.convert(html), "- Parent\n  - Child")
    }
}
