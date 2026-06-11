import XCTest
@testable import SwiftCraftLauncher

final class MinecraftServerInfoTests: XCTestCase {

    // MARK: - Description.plainText

    func testDescription_plainText_textOnly() throws {
        let json = """
        {"text": "Hello World"}
        """
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "Hello World")
    }

    func testDescription_plainText_stripsFormatCodes() throws {
        let json = """
        {"text": "§aGreen §cRed"}
        """
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "Green Red")
    }

    func testDescription_plainText_empty() throws {
        let json = "{}"
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "")
    }

    func testDescription_plainText_extraElements() throws {
        let json = """
        {
            "extra": [
                "Hello ",
                {"text": "World"}
            ]
        }
        """
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "Hello World")
    }

    func testDescription_plainText_nestedObjects() throws {
        let json = """
        {
            "extra": [
                {"extra": [{"text": "Deep"}]}
            ]
        }
        """
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "Deep")
    }

    func testDescription_plainText_formatCodeAtEnd() throws {
        let json = """
        {"text": "Test§"}
        """
        let data = Data(json.utf8)
        let desc = try JSONDecoder().decode(MinecraftServerInfo.Description.self, from: data)

        XCTAssertEqual(desc.plainText, "Test")
    }

    // MARK: - DescriptionElement

    func testDescriptionElement_string() throws {
        let json = "\"hello\""
        let data = Data(json.utf8)
        let element = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        if case .string(let text) = element {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected string element")
        }
    }

    func testDescriptionElement_object() throws {
        let json = """
        {"text": "world"}
        """
        let data = Data(json.utf8)
        let element = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        if case .object(let desc) = element {
            XCTAssertEqual(desc.plainText, "world")
        } else {
            XCTFail("Expected object element")
        }
    }

    func testDescriptionElement_plainText_string() throws {
        let json = "\"test\""
        let data = Data(json.utf8)
        let element = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        XCTAssertEqual(element.plainText, "test")
    }

    func testDescriptionElement_plainText_object() throws {
        let json = """
        {"text": "nested", "extra": [" data"]}
        """
        let data = Data(json.utf8)
        let element = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        XCTAssertEqual(element.plainText, "nested data")
    }

    // MARK: - MinecraftServerInfo Codable

    func testMinecraftServerInfo_codable() throws {
        let json = """
        {
            "version": {"name": "1.20.1", "protocol": 763},
            "players": {"max": 100, "online": 10, "sample": [{"name": "Steve", "id": "abc"}]},
            "description": {"text": "Welcome"}
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.version?.name, "1.20.1")
        XCTAssertEqual(info.version?.protocol, 763)
        XCTAssertEqual(info.players?.max, 100)
        XCTAssertEqual(info.players?.online, 10)
        XCTAssertEqual(info.players?.sample?.first?.name, "Steve")
        XCTAssertEqual(info.description.plainText, "Welcome")
    }

    func testMinecraftServerInfo_optionalFields() throws {
        let json = """
        {
            "description": {"text": "Hi"}
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertNil(info.version)
        XCTAssertNil(info.players)
        XCTAssertNil(info.favicon)
        XCTAssertNil(info.modinfo)
    }

    func testMinecraftServerInfo_modInfo() throws {
        let json = """
        {
            "description": {"text": "Hi"},
            "modinfo": {
                "type": "forge",
                "modList": [{"modid": "jei", "version": "15.0.0"}]
            }
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.modinfo?.type, "forge")
        XCTAssertEqual(info.modinfo?.modList?.first?.modid, "jei")
    }
}
