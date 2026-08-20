//
//  HTMLTestMod.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

#if DEBUG
/// A local-only project used to exercise the HTML description renderer.
enum HTMLTestMod {
    static let projectId = "swift-craft-launcher-html-test-mod"

    static let project = ModrinthProject(
        projectId: projectId,
        projectType: "mod",
        slug: "html-test-mod",
        author: "Swift Craft Launcher",
        title: "HTML Test Mod",
        description: "HTML renderer test project",
        categories: ["fabric", "utility"],
        displayCategories: ["fabric", "utility"],
        versions: ["1.21"],
        downloads: 0,
        follows: 0,
        iconUrl: nil,
        license: "MIT",
        clientSide: "required",
        serverSide: "unsupported",
        fileName: nil,
    )

    static let detail = ModrinthProjectDetail(
        slug: project.slug,
        title: project.title,
        description: project.description,
        categories: project.categories,
        clientSide: project.clientSide,
        serverSide: project.serverSide,
        body: """
        <h1>HTML Test Mod</h1>
        <p>This is <strong>bold</strong>, <b>also bold</b>, <em>italic</em>, <i>also italic</i>, <s>struck</s>, and <del>deleted</del>.</p>
        <p>Read the <a href="https://example.com/project">project page</a> or press <button data-url="https://example.com/download">Download</button>.</p>
        <p>Inline image: <img src="https://example.com/icon.png" alt="Test icon" /></p>
        <div>Block one<br />Block two</div>
        <hr />
        <blockquote>A quoted line with <code>inlineCode()</code>.</blockquote>
        <pre><code>public func testMod() {
            print("hello")
        }</code></pre>
        <ul><li>Fabric</li><li>Quilt</li></ul>
        <ol><li>Install the mod</li><li>Launch Minecraft</li></ol>
        <table><thead><tr><th>Loader</th><th>Version</th></tr></thead><tbody><tr><td>Fabric</td><td>1.21</td></tr></tbody></table>
        <video src="https://example.com/demo.mp4" title="Demo video"></video>
        <audio><source src="https://example.com/demo.mp3" /></audio>
        <svg aria-label="Test icon"><path d="M0 0" /></svg>
        <details><summary>Advanced details</summary><p>Extra information.</p></details>
        """,
        additionalCategories: ["fabric", "utility"],
        issuesUrl: nil,
        sourceUrl: "https://example.com/html-test-mod",
        wikiUrl: nil,
        discordUrl: nil,
        projectType: "mod",
        downloads: 0,
        iconUrl: nil,
        id: projectId,
        team: "Swift Craft Launcher",
        published: Date(timeIntervalSince1970: 0),
        updated: Date(timeIntervalSince1970: 0),
        followers: 0,
        license: nil,
        versions: ["1.21"],
        gameVersions: ["1.21"],
        loaders: ["fabric"],
        type: "mod",
        fileName: nil,
    )
}
#endif
