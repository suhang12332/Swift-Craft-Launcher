import XCTest
@testable import SwiftCraftLauncher

final class NBTTypeTests: XCTestCase {

    func testNBTType_rawValues() {
        XCTAssertEqual(NBTType.end.rawValue, 0)
        XCTAssertEqual(NBTType.byte.rawValue, 1)
        XCTAssertEqual(NBTType.short.rawValue, 2)
        XCTAssertEqual(NBTType.int.rawValue, 3)
        XCTAssertEqual(NBTType.long.rawValue, 4)
        XCTAssertEqual(NBTType.float.rawValue, 5)
        XCTAssertEqual(NBTType.double.rawValue, 6)
        XCTAssertEqual(NBTType.byteArray.rawValue, 7)
        XCTAssertEqual(NBTType.string.rawValue, 8)
        XCTAssertEqual(NBTType.list.rawValue, 9)
        XCTAssertEqual(NBTType.compound.rawValue, 10)
        XCTAssertEqual(NBTType.intArray.rawValue, 11)
        XCTAssertEqual(NBTType.longArray.rawValue, 12)
    }

    func testNBTType_initValidValues() {
        for rawValue: UInt8 in 0...12 {
            XCTAssertNotNil(NBTType(rawValue: rawValue), "NBTType should exist for rawValue \(rawValue)")
        }
    }

    func testNBTType_initInvalidValues() {
        XCTAssertNil(NBTType(rawValue: 13))
        XCTAssertNil(NBTType(rawValue: 255))
    }
}
