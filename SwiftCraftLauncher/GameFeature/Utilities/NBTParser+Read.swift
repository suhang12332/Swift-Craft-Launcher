//
//  NBTParser+Read.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension NBTParser {
    /// Reads a length-prefixed UTF-8 string from the data buffer.
    /// - Throws: A `GlobalError` if there is insufficient data or the string length exceeds the buffer.
    /// - Returns: The decoded string.
    func readString() throws -> String {
        guard offset + 2 <= data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据不足，无法读取字符串长度",
                i18nKey: "error.filesystem.nbt_insufficient_data",
                level: .notification,
            )
        }

        let length = Int(readShort())
        guard offset + length <= data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 字符串长度超出数据范围",
                i18nKey: "error.filesystem.nbt_string_out_of_range",
                level: .notification,
            )
        }

        let stringData = data.subdata(in: offset ..< (offset + length))
        offset += length

        return String(data: stringData, encoding: .utf8) ?? ""
    }

    /// Reads a big-endian 16-bit unsigned integer.
    /// - Returns: The value, or `0` if insufficient data remains.
    func readShort() -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let value = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    /// Reads a big-endian 32-bit signed integer.
    /// - Returns: The value, or `0` if insufficient data remains.
    func readInt() -> Int32 {
        guard offset + 4 <= data.count else { return 0 }
        var value: Int32 = 0
        for i in 0 ..< 4 {
            value = (value << 8) | Int32(data[offset + i])
        }
        offset += 4
        return value
    }

    /// Reads a single byte.
    /// - Returns: The byte, or `0` if no data remains.
    func readByte() -> UInt8 {
        guard offset < data.count else { return 0 }
        let value = data[offset]
        offset += 1
        return value
    }

    /// Reads a compound tag containing nested name-value pairs.
    /// - Throws: A `GlobalError` if a child tag cannot be read.
    /// - Returns: A dictionary of tag names to their values.
    func readCompound() throws -> [String: Any] {
        var result: [String: Any] = [:]

        while offset < data.count {
            let tagType = NBTType(rawValue: data[offset]) ?? .end
            offset += 1

            if tagType == .end {
                break
            }

            let name = try readString()
            let value = try readTagValue(type: tagType)
            result[name] = value
        }

        return result
    }

    /// Reads a tag value of the specified type.
    /// - Parameter type: The NBT tag type to read.
    /// - Throws: A `GlobalError` if the tag type is unsupported or data is malformed.
    /// - Returns: The decoded value.
    func readTagValue(type: NBTType) throws -> Any {
        switch type {
        case .byte:
            return Int8(bitPattern: readByte())
        case .short:
            return Int16(bitPattern: readShort())
        case .int:
            return readInt()
        case .long:
            return readLong()
        case .float:
            return readFloat()
        case .double:
            return readDouble()
        case .string:
            return try readString()
        case .list:
            return try readList()
        case .compound:
            return try readCompound()
        case .byteArray:
            let length = Int(readInt())
            guard offset + length <= data.count else {
                throw GlobalError.fileSystem(
                    chineseMessage: "NBT 字节数组长度超出数据范围",
                    i18nKey: "error.filesystem.nbt_byte_array_out_of_range",
                    level: .notification,
                )
            }
            let array = Array(data.subdata(in: offset ..< (offset + length)))
            offset += length
            return array
        case .intArray:
            let length = Int(readInt())
            var array: [Int32] = []
            for _ in 0 ..< length {
                array.append(readInt())
            }
            return array
        case .longArray:
            let length = Int(readInt())
            var array: [Int64] = []
            for _ in 0 ..< length {
                array.append(readLong())
            }
            return array
        case .end:
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 解析遇到 End 标签",
                i18nKey: "error.filesystem.nbt_unexpected_end_tag",
                level: .notification,
            )
        }
    }

    /// Reads a big-endian 64-bit signed integer.
    /// - Returns: The value, or `0` if insufficient data remains.
    func readLong() -> Int64 {
        guard offset + 8 <= data.count else { return 0 }
        var value: Int64 = 0
        for i in 0 ..< 8 {
            value = (value << 8) | Int64(data[offset + i])
        }
        offset += 8
        return value
    }

    /// Reads a big-endian 32-bit IEEE 754 float.
    /// - Returns: The value, or `0` if insufficient data remains.
    func readFloat() -> Float {
        guard offset + 4 <= data.count else { return 0 }
        let intValue = readInt()
        return Float(bitPattern: UInt32(bitPattern: intValue))
    }

    /// Reads a big-endian 64-bit IEEE 754 double.
    /// - Returns: The value, or `0` if insufficient data remains.
    func readDouble() -> Double {
        guard offset + 8 <= data.count else { return 0 }
        let longValue = readLong()
        return Double(bitPattern: UInt64(bitPattern: longValue))
    }

    /// Reads a list tag containing homogeneous elements.
    /// - Throws: A `GlobalError` if there is insufficient data or an element cannot be read.
    /// - Returns: An array of values.
    func readList() throws -> [Any] {
        guard offset < data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据不足，无法读取列表类型",
                i18nKey: "error.filesystem.nbt_insufficient_data_for_list",
                level: .notification,
            )
        }

        let listType = NBTType(rawValue: data[offset]) ?? .end
        offset += 1

        let length = Int(readInt())
        var result: [Any] = []

        for _ in 0 ..< length {
            let value = try readTagValue(type: listType)
            result.append(value)
        }

        return result
    }
}
