//
//  PlayerFeatureModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class PlayerFeatureModelsTests: XCTestCase {
    func testPlayer_init_profile() {
        let profile = UserProfile(id: "id-1", name: "Steve", avatar: "steve")
        let player = Player(profile: profile)

        XCTAssertEqual(player.id, "id-1")
        XCTAssertEqual(player.name, "Steve")
        XCTAssertEqual(player.avatarName, "steve")
        XCTAssertNil(player.credential)
    }

    func testPlayer_init_withCredential() {
        let profile = UserProfile(id: "id-2", name: "Alex", avatar: "alex")
        let credential = AuthCredential(userId: "id-2", accessToken: "at", refreshToken: "rt")
        let player = Player(profile: profile, credential: credential)

        XCTAssertEqual(player.authAccessToken, "at")
        XCTAssertEqual(player.authRefreshToken, "rt")
        XCTAssertTrue(player.isOnlineAccount)
    }

    func testPlayer_isRemote() {
        let localProfile = UserProfile(id: "1", name: "Local", avatar: "steve")
        let remoteProfile = UserProfile(id: "2", name: "Remote", avatar: "https://example.com/skin.png")

        XCTAssertFalse(Player(profile: localProfile).isRemote)
        XCTAssertTrue(Player(profile: remoteProfile).isRemote)
    }

    func testPlayer_isOnlineAccount_noCredential() {
        let localProfile = UserProfile(id: "1", name: "Local", avatar: "steve")
        let player = Player(profile: localProfile)

        XCTAssertFalse(player.isOnlineAccount)
    }

    func testPlayer_convenienceInit_offline() throws {
        let player = try Player(name: "TestPlayer")

        XCTAssertEqual(player.name, "TestPlayer")
        XCTAssertFalse(player.id.isEmpty)
        XCTAssertEqual(player.id.count, 32)
        XCTAssertFalse(player.isCurrent)
        XCTAssertNil(player.credential)
    }

    func testPlayer_convenienceInit_withUUID() throws {
        let player = try Player(name: "Custom", uuid: "custom-uuid-123", avatar: "alex")

        XCTAssertEqual(player.id, "custom-uuid-123")
        XCTAssertEqual(player.avatarName, "alex")
    }

    func testPlayer_convenienceInit_withCredential() throws {
        let credential = AuthCredential(userId: "uid", accessToken: "token", refreshToken: "refresh")
        let player = try Player(name: "Online", avatar: "https://example.com/skin.png", credential: credential)

        XCTAssertEqual(player.name, "Online")
        XCTAssertTrue(player.isOnlineAccount)
    }

    func testPlayer_setProperties() {
        let profile = UserProfile(id: "id", name: "Player", avatar: "steve")
        var player = Player(profile: profile)

        player.isCurrent = true
        XCTAssertTrue(player.isCurrent)

        let newDate = Date(timeIntervalSince1970: 0)
        player.lastPlayed = newDate
        XCTAssertEqual(player.lastPlayed, newDate)
    }

    func testPlayer_equatable() {
        let profile = UserProfile(id: "id", name: "A", avatar: "av")
        let a = Player(profile: profile)
        let b = Player(profile: profile)

        XCTAssertEqual(a, b)
    }

    func testSkinLibraryItem_displayName() {
        let item = SkinLibraryItem(
            originalFileName: "my skin.png",
            sha1: "abc123",
            model: .classic,
            lastUsedAt: Date(),
        )

        XCTAssertEqual(item.displayName, "my skin.png")
    }

    func testSkinLibraryItem_displayName_whitespaceOnly() {
        let item = SkinLibraryItem(
            originalFileName: "   ",
            sha1: "def456",
            model: .classic,
            lastUsedAt: Date(),
        )

        XCTAssertEqual(item.displayName, "def456.png")
    }

    func testSkinLibraryItem_displayName_empty() {
        let item = SkinLibraryItem(
            originalFileName: "",
            sha1: "ghi789",
            model: .slim,
            lastUsedAt: Date(),
        )

        XCTAssertEqual(item.displayName, "ghi789.png")
    }

    func testSkinLibraryItem_id() {
        let item = SkinLibraryItem(
            originalFileName: "skin.png",
            sha1: "hash-value",
            model: .classic,
            lastUsedAt: Date(),
        )

        XCTAssertEqual(item.id, "hash-value")
    }

    func testSkinLibraryItem_fileURL() {
        let item = SkinLibraryItem(
            originalFileName: "skin.png",
            sha1: "abc123",
            model: .classic,
            lastUsedAt: Date(),
        )

        XCTAssertTrue(item.fileURL.absoluteString.contains("abc123.png"))
    }

    func testSkinLibraryItem_codable_roundTrip() throws {
        let original = SkinLibraryItem(
            originalFileName: "test.png",
            sha1: "sha1hash",
            model: .slim,
            lastUsedAt: Date(timeIntervalSince1970: 1_700_000_000),
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkinLibraryItem.self, from: encoded)

        XCTAssertEqual(decoded.originalFileName, original.originalFileName)
        XCTAssertEqual(decoded.sha1, original.sha1)
        XCTAssertEqual(decoded.model, original.model)
    }

    func testSkinLibraryItem_equatable() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = SkinLibraryItem(originalFileName: "same.png", sha1: "same", model: .classic, lastUsedAt: date)
        let b = SkinLibraryItem(originalFileName: "same.png", sha1: "same", model: .classic, lastUsedAt: date)
        let c = SkinLibraryItem(originalFileName: "different.png", sha1: "same", model: .classic, lastUsedAt: date)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
