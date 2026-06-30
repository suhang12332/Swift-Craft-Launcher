//
//  MinecraftManifestTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftManifestTests: XCTestCase {
    func testMinecraftVersionManifest_decodeMinimal() throws {
        let json = """
        {
            "arguments": {"game": ["--width", "854"], "jvm": ["-Xmx1G"]},
            "assetIndex": {"id": "17", "sha1": "abc", "size": 100, "totalSize": 200, "url": "https://example.com/index.json"},
            "assets": "17",
            "downloads": {"client": {"sha1": "def", "size": 300, "url": "https://example.com/client.jar"}},
            "id": "1.20.1",
            "javaVersion": {"component": "java-runtime-gamma", "majorVersion": 17},
            "libraries": [],
            "logging": {"client": {"argument": "-Dlog4j", "file": {"id": "log.xml", "sha1": "ghi", "size": 400, "url": "https://example.com/log.xml"}, "type": "log4j2-xml"}},
            "mainClass": "net.minecraft.client.main.Main",
            "minimumLauncherVersion": 21,
            "releaseTime": "2023-06-12T12:41:41+00:00",
            "time": "2023-06-12T12:41:41+00:00",
            "type": "release"
        }
        """
        let data = Data(json.utf8)
        let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: data)

        XCTAssertEqual(manifest.id, "1.20.1")
        XCTAssertEqual(manifest.mainClass, "net.minecraft.client.main.Main")
        XCTAssertEqual(manifest.assets, "17")
        XCTAssertEqual(manifest.type, "release")
        XCTAssertEqual(manifest.minimumLauncherVersion, 21)
        XCTAssertEqual(manifest.javaVersion.component, "java-runtime-gamma")
        XCTAssertEqual(manifest.javaVersion.majorVersion, 17)
    }

    func testMinecraftVersionManifest_optionalComplianceLevel() throws {
        let json = """
        {
            "arguments": {"game": [], "jvm": []},
            "assetIndex": {"id": "17", "sha1": "a", "size": 1, "totalSize": 2, "url": "https://e.com/i.json"},
            "assets": "17",
            "downloads": {"client": {"sha1": "b", "size": 3, "url": "https://e.com/c.jar"}},
            "id": "1.20.1",
            "javaVersion": {"component": "java-runtime", "majorVersion": 17},
            "libraries": [],
            "logging": {"client": {"argument": "", "file": {"id": "l", "sha1": "c", "size": 4, "url": "https://e.com/l.xml"}, "type": "t"}},
            "mainClass": "Main",
            "minimumLauncherVersion": 21,
            "releaseTime": "2023-01-01",
            "time": "2023-01-01",
            "type": "release"
        }
        """
        let data = Data(json.utf8)
        let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: data)
        XCTAssertNil(manifest.complianceLevel)
    }

    func testArgumentValue_string() throws {
        let json = "\"--width\""
        let data = Data(json.utf8)
        let value = try JSONDecoder().decode(ArgumentValue.self, from: data)

        if case let .string(s) = value {
            XCTAssertEqual(s, "--width")
        } else {
            XCTFail("Expected string")
        }
    }

    func testArgumentValue_objectWithRules() throws {
        let json = """
        {
            "rules": [{"action": "allow", "os": {"name": "osx"}}],
            "value": "-XstartOnFirstThread"
        }
        """
        let data = Data(json.utf8)
        let value = try JSONDecoder().decode(ArgumentValue.self, from: data)

        if case let .objectWithRules(obj) = value {
            XCTAssertEqual(obj.rules.count, 1)
            XCTAssertEqual(obj.rules.first?.action, "allow")
        } else {
            XCTFail("Expected objectWithRules")
        }
    }

    func testArgumentValueArrayOrString_string() throws {
        let json = "\"hello\""
        let data = Data(json.utf8)
        let value = try JSONDecoder().decode(ArgumentValueArrayOrString.self, from: data)

        if case let .string(s) = value {
            XCTAssertEqual(s, "hello")
        } else {
            XCTFail("Expected string")
        }
    }

    func testArgumentValueArrayOrString_array() throws {
        let json = "[\"a\", \"b\", \"c\"]"
        let data = Data(json.utf8)
        let value = try JSONDecoder().decode(ArgumentValueArrayOrString.self, from: data)

        if case let .array(arr) = value {
            XCTAssertEqual(arr, ["a", "b", "c"])
        } else {
            XCTFail("Expected array")
        }
    }

    func testFeatures_missingKeys_defaultsFalse() throws {
        let json = "{}"
        let data = Data(json.utf8)
        let features = try JSONDecoder().decode(Features.self, from: data)

        XCTAssertFalse(features.is_demo_user)
        XCTAssertFalse(features.has_custom_resolution)
        XCTAssertFalse(features.has_quick_plays_support)
        XCTAssertFalse(features.is_quick_play_singleplayer)
        XCTAssertFalse(features.is_quick_play_multiplayer)
        XCTAssertFalse(features.is_quick_play_realms)
    }

    func testFeatures_withValues() throws {
        let json = """
        {
            "is_demo_user": true,
            "has_custom_resolution": false
        }
        """
        let data = Data(json.utf8)
        let features = try JSONDecoder().decode(Features.self, from: data)

        XCTAssertTrue(features.is_demo_user)
        XCTAssertFalse(features.has_custom_resolution)
        XCTAssertFalse(features.has_quick_plays_support)
    }

    func testLibrary_decodeDefaults() throws {
        let json = """
        {
            "downloads": {"artifact": {"sha1": "abc", "size": 100, "url": "https://example.com/lib.jar"}},
            "name": "org.example:lib:1.0"
        }
        """
        let data = Data(json.utf8)
        let library = try JSONDecoder().decode(Library.self, from: data)

        XCTAssertEqual(library.name, "org.example:lib:1.0")
        XCTAssertTrue(library.includeInClasspath)
        XCTAssertTrue(library.downloadable)
        XCTAssertNil(library.rules)
        XCTAssertNil(library.natives)
    }

    func testLibrary_decodeWithExplicitValues() throws {
        let json = """
        {
            "downloads": {"artifact": {"sha1": "abc", "size": 100, "url": "https://example.com/lib.jar"}},
            "name": "org.example:native:1.0",
            "include_in_classpath": false,
            "downloadable": false,
            "rules": [{"action": "allow", "os": {"name": "osx"}}],
            "natives": {"osx": "natives-osx"}
        }
        """
        let data = Data(json.utf8)
        let library = try JSONDecoder().decode(Library.self, from: data)

        XCTAssertFalse(library.includeInClasspath)
        XCTAssertFalse(library.downloadable)
        XCTAssertNotNil(library.rules)
        XCTAssertEqual(library.natives?["osx"], "natives-osx")
    }

    func testLibraryArtifact_decodeEmptyURL() throws {
        let json = """
        {"sha1": "abc", "size": 100, "url": ""}
        """
        let data = Data(json.utf8)
        let artifact = try JSONDecoder().decode(LibraryArtifact.self, from: data)

        XCTAssertNil(artifact.url)
        XCTAssertNil(artifact.path)
        XCTAssertEqual(artifact.sha1, "abc")
    }

    func testLibraryArtifact_decodeWithPath() throws {
        let json = """
        {"path": "org/example/lib.jar", "sha1": "abc", "size": 100, "url": "https://example.com/lib.jar"}
        """
        let data = Data(json.utf8)
        let artifact = try JSONDecoder().decode(LibraryArtifact.self, from: data)

        XCTAssertEqual(artifact.path, "org/example/lib.jar")
        XCTAssertEqual(artifact.url?.absoluteString, "https://example.com/lib.jar")
    }

    func testLibraryArtifact_encode() throws {
        let artifact = LibraryArtifact(
            path: "org/example/lib.jar",
            sha1: "abc123",
            size: 200,
            url: URL(string: "https://example.com/lib.jar"),
        )
        let encoded = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(LibraryArtifact.self, from: encoded)

        XCTAssertEqual(decoded.path, artifact.path)
        XCTAssertEqual(decoded.sha1, artifact.sha1)
        XCTAssertEqual(decoded.size, artifact.size)
        XCTAssertEqual(decoded.url, artifact.url)
    }

    func testRule_decode() throws {
        let json = """
        {
            "action": "allow",
            "os": {"name": "osx", "version": "10.15", "arch": "x86_64"}
        }
        """
        let data = Data(json.utf8)
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        XCTAssertEqual(rule.action, "allow")
        XCTAssertEqual(rule.os?.name, "osx")
        XCTAssertEqual(rule.os?.version, "10.15")
        XCTAssertEqual(rule.os?.arch, "x86_64")
    }

    func testRule_decodeWithFeatures() throws {
        let json = """
        {
            "action": "allow",
            "features": {"is_demo_user": true}
        }
        """
        let data = Data(json.utf8)
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        XCTAssertEqual(rule.action, "allow")
        XCTAssertTrue(rule.features?.is_demo_user ?? false)
        XCTAssertNil(rule.os)
    }
}
