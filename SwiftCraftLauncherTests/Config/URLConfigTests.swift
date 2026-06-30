//
//  URLConfigTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class URLConfigTests: XCTestCase {
    func testApplyGitProxy_githubURL() {
        let url = URL.require("https://github.com/user/repo/releases/download/v1.0/file.jar")
        let result = URLConfig.applyGitProxyIfNeeded(url)

        XCTAssertTrue(result.absoluteString.contains("gh-proxy.com"))
    }

    func testApplyGitProxy_rawGithubURL() {
        let url = URL.require("https://raw.githubusercontent.com/user/repo/main/file.json")
        let result = URLConfig.applyGitProxyIfNeeded(url)

        XCTAssertTrue(result.absoluteString.contains("gh-proxy.com"))
    }

    func testApplyGitProxy_nonGitHubURL_unchanged() {
        let url = URL.require("https://example.com/file.jar")
        let result = URLConfig.applyGitProxyIfNeeded(url)

        XCTAssertEqual(result, url)
    }

    func testApplyGitProxy_stringVersion() {
        let result = URLConfig.applyGitProxyIfNeeded("https://github.com/user/repo/releases/download/v1.0/file.jar")
        XCTAssertTrue(result.contains("gh-proxy.com"))
    }

    func testApplyGitProxy_stringVersion_nonGitHub() {
        let result = URLConfig.applyGitProxyIfNeeded("https://example.com/file.jar")
        XCTAssertEqual(result, "https://example.com/file.jar")
    }

    func testApplyGitProxy_alreadyProxied() {
        let url = URL.require("https://gh-proxy.com/https://github.com/user/repo/file.jar")
        let result = URLConfig.applyGitProxyIfNeeded(url)

        XCTAssertEqual(result, url)
    }

    func testAPIAuthentication_urls() {
        let auth = URLConfig.API.Authentication.authorize
        XCTAssertTrue(auth.absoluteString.contains("login.microsoftonline.com"))

        let token = URLConfig.API.Authentication.token
        XCTAssertTrue(token.absoluteString.contains("login.microsoftonline.com"))

        let profile = URLConfig.API.Authentication.minecraftProfile
        XCTAssertTrue(profile.absoluteString.contains("api.minecraftservices.com"))

        XCTAssertEqual(URLConfig.API.Authentication.redirectUri, "com.su.code.swiftcraftlauncher://oauth")
    }

    func testAPIJavaRuntime_urls() {
        let baseURL = URLConfig.API.JavaRuntime.baseURL
        XCTAssertTrue(baseURL.absoluteString.contains("launchermeta.mojang.com"))

        let allRuntimes = URLConfig.API.JavaRuntime.allRuntimes
        XCTAssertTrue(allRuntimes.absoluteString.contains("all.json"))
    }

    func testAPIModrinth_urls() {
        let search = URLConfig.API.Modrinth.search
        XCTAssertTrue(search.absoluteString.contains("api.modrinth.com"))

        let project = URLConfig.API.Modrinth.project(id: "abc123")
        XCTAssertTrue(project.absoluteString.contains("project/abc123"))

        let version = URLConfig.API.Modrinth.version(id: "abc123")
        XCTAssertTrue(version.absoluteString.contains("project/abc123/version"))
    }

    func testAPICurseForge_urls() {
        let search = URLConfig.API.CurseForge.search
        XCTAssertTrue(search.absoluteString.contains("api.curseforge.com"))

        let fileDetail = URLConfig.API.CurseForge.fileDetail(projectId: 100, fileId: 200)
        XCTAssertTrue(fileDetail.absoluteString.contains("mods/100/files/200"))

        let fallbackDownload = URLConfig.API.CurseForge.fallbackDownloadUrl(fileId: 12345, fileName: "mod.jar")
        XCTAssertTrue(fallbackDownload.absoluteString.contains("edge.forgecdn.net"))
        XCTAssertTrue(fallbackDownload.absoluteString.contains("mod.jar"))
    }

    func testAPICurseForge_webProjectURL() {
        XCTAssertEqual(
            URLConfig.API.CurseForge.webProjectURL(projectType: "mod"),
            "https://www.curseforge.com/minecraft/mc-mods/",
        )
        XCTAssertEqual(
            URLConfig.API.CurseForge.webProjectURL(projectType: "resourcepack"),
            "https://www.curseforge.com/minecraft/texture-packs/",
        )
        XCTAssertEqual(
            URLConfig.API.CurseForge.webProjectURL(projectType: "shader"),
            "https://www.curseforge.com/minecraft/shaders/",
        )
        XCTAssertEqual(
            URLConfig.API.CurseForge.webProjectURL(projectType: "modpack"),
            "https://www.curseforge.com/minecraft/modpacks/",
        )
    }

    func testAPICurseForge_projectFiles() {
        let url = URLConfig.API.CurseForge.projectFiles(projectId: 123, gameVersion: "1.20.1", modLoaderType: 1)
        XCTAssertTrue(url.absoluteString.contains("mods/123/files"))
        XCTAssertTrue(url.absoluteString.contains("gameVersion=1.20.1"))
        XCTAssertTrue(url.absoluteString.contains("modLoaderType=1"))
    }

    func testAPICurseForge_projectFiles_noFilters() {
        let url = URLConfig.API.CurseForge.projectFiles(projectId: 123)
        XCTAssertTrue(url.absoluteString.contains("mods/123/files"))
        XCTAssertFalse(url.absoluteString.contains("gameVersion"))
    }

    func testServerApiRoot_trailingSlash() {
        XCTAssertEqual(
            URLConfig.API.AuthlibInjector.serverApiRoot(for: "https://littleskin.cn/"),
            "https://littleskin.cn",
        )
    }

    func testServerApiRoot_multipleTrailingSlashes() {
        XCTAssertEqual(
            URLConfig.API.AuthlibInjector.serverApiRoot(for: "https://example.com///"),
            "https://example.com",
        )
    }

    func testServerApiRoot_noTrailingSlash() {
        XCTAssertEqual(
            URLConfig.API.AuthlibInjector.serverApiRoot(for: "https://littleskin.cn"),
            "https://littleskin.cn",
        )
    }

    func testServerApiRoot_whitespace() {
        XCTAssertEqual(
            URLConfig.API.AuthlibInjector.serverApiRoot(for: "  https://example.com/  "),
            "https://example.com",
        )
    }

    func testChunkBase_seedMap() {
        let url = URLConfig.API.ChunkBase.seedMap(seed: 12345)
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("seed=12345") ?? false)
    }

    func testCommunity_urls() {
        let website = URLConfig.API.Community.website()
        XCTAssertTrue(website.absoluteString.contains("suhang12332.github.io"))

        let discord = URLConfig.API.Community.discord()
        XCTAssertTrue(discord.absoluteString.contains("discord.gg"))

        let qq = URLConfig.API.Community.qq()
        XCTAssertTrue(qq.absoluteString.contains("qm.qq.com"))
    }
}
