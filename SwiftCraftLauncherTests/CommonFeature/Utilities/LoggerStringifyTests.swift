import XCTest
@testable import SwiftCraftLauncher

final class LoggerStringifyTests: XCTestCase {

    func testStringify_string() {
        let result = Logger.stringify("hello")
        XCTAssertEqual(result, "hello")
    }

    func testStringify_int() {
        let result = Logger.stringify(42)
        XCTAssertEqual(result, "42")
    }

    func testStringify_double() {
        let result = Logger.stringify(3.14)
        XCTAssertEqual(result, "3.14")
    }

    func testStringify_bool() {
        XCTAssertEqual(Logger.stringify(true), "true")
        XCTAssertEqual(Logger.stringify(false), "false")
    }

    func testStringify_error() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let result = Logger.stringify(error)
        XCTAssertTrue(result.contains("Test error"))
        XCTAssertTrue(result.hasPrefix("Error:"))
    }

    func testStringify_data_utf8() {
        let data = "hello".data(using: .utf8)!
        let result = Logger.stringify(data)
        XCTAssertEqual(result, "hello")
    }

    func testStringify_data_nonUtf8() {
        let data = Data([0xFF, 0xFE])
        let result = Logger.stringify(data)
        XCTAssertEqual(result, "<Data>")
    }

    func testStringify_array() {
        let result = Logger.stringify([1, 2, 3])
        XCTAssertEqual(result, "[1, 2, 3]")
    }

    func testStringify_array_truncation() {
        let array = Array(0..<150)
        let result = Logger.stringify(array)
        XCTAssertTrue(result.hasPrefix("["))
        XCTAssertTrue(result.contains("... (50 more)"))
    }

    func testStringify_dictionary() {
        let dict: [String: Any] = ["key": "value", "num": 42]
        let result = Logger.stringify(dict)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.contains("key: value"))
    }

    func testStringify_dictionary_truncation() {
        var dict: [String: Any] = [:]
        for i in 0..<60 {
            dict["key\(i)"] = i
        }
        let result = Logger.stringify(dict)
        XCTAssertTrue(result.contains("... (10 more)"))
    }

    func testStringify_encodable() {
        let message = ChatMessage(role: .user, content: "test")
        let result = Logger.stringify(message)
        XCTAssertTrue(result.contains("user"))
        XCTAssertTrue(result.contains("test"))
    }

    func testStringify_unknownType() {
        let result = Logger.stringify(UUID())
        XCTAssertFalse(result.isEmpty)
    }
}
