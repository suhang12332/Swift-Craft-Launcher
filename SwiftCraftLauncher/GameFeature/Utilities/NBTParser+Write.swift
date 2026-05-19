//
//  NBTParser+Write.swift
//  SwiftCraftLauncher
//

import Foundation

extension NBTParser {

    func writeByte(_ value: UInt8) {
        outputData.append(value)
    }

    func writeShort(_ value: UInt16) {
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }

    func writeInt(_ value: Int32) {
        outputData.append(UInt8((value >> 24) & 0xFF))
        outputData.append(UInt8((value >> 16) & 0xFF))
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }

    func writeLong(_ value: Int64) {
        outputData.append(UInt8((value >> 56) & 0xFF))
        outputData.append(UInt8((value >> 48) & 0xFF))
        outputData.append(UInt8((value >> 40) & 0xFF))
        outputData.append(UInt8((value >> 32) & 0xFF))
        outputData.append(UInt8((value >> 24) & 0xFF))
        outputData.append(UInt8((value >> 16) & 0xFF))
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }

    func writeString(_ value: String) {
        let stringData = value.data(using: .utf8) ?? Data()
        let length = UInt16(stringData.count)
        writeShort(length)
        outputData.append(stringData)
    }

    func writeFloat(_ value: Float) {
        let bitPattern = value.bitPattern
        let intValue = Int32(bitPattern: bitPattern)
        writeInt(intValue)
    }

    func writeDouble(_ value: Double) {
        let bitPattern = value.bitPattern
        let longValue = Int64(bitPattern: bitPattern)
        writeLong(longValue)
    }

    func writeCompound(_ compound: [String: Any]) throws {
        for (name, value) in compound {
            let tagType = try inferNBTType(from: value)
            writeByte(tagType.rawValue)
            writeString(name)
            try writeTagValue(type: tagType, value: value)
        }
        writeByte(NBTType.end.rawValue)
    }

    func writeTagValue(type: NBTType, value: Any) throws {
        switch type {
        case .byte:
            if let intValue = value as? Int {
                writeByte(UInt8(bitPattern: Int8(intValue)))
            } else if let int8Value = value as? Int8 {
                writeByte(UInt8(bitPattern: int8Value))
            } else if let boolValue = value as? Bool {
                writeByte(boolValue ? 1 : 0)
            } else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Byte 类型",
                    i18nKey: "error.filesystem.nbt_invalid_byte_value",
                    level: .notification
                )
            }
        case .short:
            let shortValue: Int16
            if let intValue = value as? Int {
                shortValue = Int16(intValue)
            } else if let int16Value = value as? Int16 {
                shortValue = int16Value
            } else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Short 类型",
                    i18nKey: "error.filesystem.nbt_invalid_short_value",
                    level: .notification
                )
            }
            writeShort(UInt16(bitPattern: shortValue))
        case .int:
            let intValue: Int32
            if let int = value as? Int {
                intValue = Int32(int)
            } else if let int32Value = value as? Int32 {
                intValue = int32Value
            } else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Int 类型",
                    i18nKey: "error.filesystem.nbt_invalid_int_value",
                    level: .notification
                )
            }
            writeInt(intValue)
        case .long:
            let longValue: Int64
            if let int = value as? Int {
                longValue = Int64(int)
            } else if let int64Value = value as? Int64 {
                longValue = int64Value
            } else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Long 类型",
                    i18nKey: "error.filesystem.nbt_invalid_long_value",
                    level: .notification
                )
            }
            writeLong(longValue)
        case .float:
            guard let floatValue = value as? Float else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Float 类型",
                    i18nKey: "error.filesystem.nbt_invalid_float_value",
                    level: .notification
                )
            }
            writeFloat(floatValue)
        case .double:
            guard let doubleValue = value as? Double else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Double 类型",
                    i18nKey: "error.filesystem.nbt_invalid_double_value",
                    level: .notification
                )
            }
            writeDouble(doubleValue)
        case .string:
            let stringValue: String
            if let str = value as? String {
                stringValue = str
            } else {
                stringValue = String(describing: value)
            }
            writeString(stringValue)
        case .list:
            try writeList(value)
        case .compound:
            guard let compoundValue = value as? [String: Any] else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 Compound 类型",
                    i18nKey: "error.filesystem.nbt_invalid_compound_value",
                    level: .notification
                )
            }
            try writeCompound(compoundValue)
        case .byteArray:
            guard let array = value as? [UInt8] else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 ByteArray 类型",
                    i18nKey: "error.filesystem.nbt_invalid_byte_array_value",
                    level: .notification
                )
            }
            writeInt(Int32(array.count))
            outputData.append(contentsOf: array)
        case .intArray:
            guard let array = value as? [Int32] else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 IntArray 类型",
                    i18nKey: "error.filesystem.nbt_invalid_int_array_value",
                    level: .notification
                )
            }
            writeInt(Int32(array.count))
            for item in array {
                writeInt(item)
            }
        case .longArray:
            guard let array = value as? [Int64] else {
                throw GlobalError.fileSystem(
                    chineseMessage: "无法将值转换为 LongArray 类型",
                    i18nKey: "error.filesystem.nbt_invalid_long_array_value",
                    level: .notification
                )
            }
            writeInt(Int32(array.count))
            for item in array {
                writeLong(item)
            }
        case .end:
            break
        }
    }

    func writeList(_ value: Any) throws {
        guard let array = value as? [Any], !array.isEmpty else {
            writeByte(NBTType.end.rawValue)
            writeInt(0)
            return
        }

        let elementType = try inferNBTType(from: array[0])
        writeByte(elementType.rawValue)
        writeInt(Int32(array.count))

        for item in array {
            try writeTagValue(type: elementType, value: item)
        }
    }

    func inferNBTType(from value: Any) throws -> NBTType {
        switch value {
        case is Bool, is Int8:
            return .byte
        case is Int16:
            return .short
        case is Int32, is Int:
            return .int
        case is Int64:
            return .long
        case is Float:
            return .float
        case is Double:
            return .double
        case is String:
            return .string
        case is [UInt8]:
            return .byteArray
        case is [Int32]:
            return .intArray
        case is [Int64]:
            return .longArray
        case is [Any]:
            return .list
        case is [String: Any]:
            return .compound
        default:
            return .string
        }
    }
}
