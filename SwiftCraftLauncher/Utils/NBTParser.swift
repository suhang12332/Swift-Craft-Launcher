//
//  NBTParser.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// NBT 标签类型
private enum NBTType: UInt8 {
    case end = 0
    case byte = 1
    case short = 2
    case int = 3
    case long = 4
    case float = 5
    case double = 6
    case byteArray = 7
    case string = 8
    case list = 9
    case compound = 10
    case intArray = 11
    case longArray = 12
}

/// NBT 解析器
/// 用于解析和生成 Minecraft 的 NBT 格式文件（如 servers.dat）
class NBTParser {
    private var data: Data
    private var offset: Int = 0
    private var outputData: Data = Data()
    
    init(data: Data) {
        self.data = data
    }
    
    /// 创建用于写入的 NBT 解析器
    private init() {
        self.data = Data()
    }
    
    /// 解析 NBT 数据（支持 GZIP 压缩）
    /// - Returns: 解析后的字典
    /// - Throws: 解析错误
    func parse() throws -> [String: Any] {
        // 检查是否是 GZIP 压缩
        if data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B {
            // GZIP 压缩，先解压
            data = try decompressGzip(data: data)
            offset = 0
        }
        
        // 读取根标签类型（应该是 TAG_Compound）
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据为空",
                i18nKey: "error.filesystem.nbt_empty_data",
                level: .notification
            )
        }
        
        let tagType = NBTType(rawValue: data[offset]) ?? .end
        guard tagType == .compound else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 根标签不是 Compound 类型",
                i18nKey: "error.filesystem.nbt_invalid_root",
                level: .notification
            )
        }
        
        offset += 1
        
        // 读取标签名称（根标签名称可能为空）
        let name = try readString()
        
        // 读取 Compound 内容
        return try readCompound() as? [String: Any] ?? [:]
    }
    
    /// 读取字符串
    private func readString() throws -> String {
        guard offset + 2 <= data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据不足，无法读取字符串长度",
                i18nKey: "error.filesystem.nbt_insufficient_data",
                level: .notification
            )
        }
        
        let length = Int(readShort())
        guard offset + length <= data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 字符串长度超出数据范围",
                i18nKey: "error.filesystem.nbt_string_out_of_range",
                level: .notification
            )
        }
        
        let stringData = data.subdata(in: offset..<(offset + length))
        offset += length
        
        return String(data: stringData, encoding: .utf8) ?? ""
    }
    
    /// 读取短整型（2 字节，大端序）
    private func readShort() -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let value = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
        offset += 2
        return value
    }
    
    /// 读取整型（4 字节，大端序）
    private func readInt() -> Int32 {
        guard offset + 4 <= data.count else { return 0 }
        var value: Int32 = 0
        for i in 0..<4 {
            value = (value << 8) | Int32(data[offset + i])
        }
        offset += 4
        return value
    }
    
    /// 读取字节
    private func readByte() -> UInt8 {
        guard offset < data.count else { return 0 }
        let value = data[offset]
        offset += 1
        return value
    }
    
    /// 读取 Compound 标签
    private func readCompound() throws -> [String: Any] {
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
    
    /// 读取标签值
    private func readTagValue(type: NBTType) throws -> Any {
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
                    level: .notification
                )
            }
            let array = Array(data.subdata(in: offset..<(offset + length)))
            offset += length
            return array
        case .intArray:
            let length = Int(readInt())
            var array: [Int32] = []
            for _ in 0..<length {
                array.append(readInt())
            }
            return array
        case .longArray:
            let length = Int(readInt())
            var array: [Int64] = []
            for _ in 0..<length {
                array.append(readLong())
            }
            return array
        case .end:
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 解析遇到 End 标签",
                i18nKey: "error.filesystem.nbt_unexpected_end_tag",
                level: .notification
            )
        }
    }
    
    /// 读取长整型（8 字节，大端序）
    private func readLong() -> Int64 {
        guard offset + 8 <= data.count else { return 0 }
        var value: Int64 = 0
        for i in 0..<8 {
            value = (value << 8) | Int64(data[offset + i])
        }
        offset += 8
        return value
    }
    
    /// 读取浮点数（4 字节，IEEE 754）
    private func readFloat() -> Float {
        guard offset + 4 <= data.count else { return 0 }
        let intValue = readInt()
        return Float(bitPattern: UInt32(bitPattern: intValue))
    }
    
    /// 读取双精度浮点数（8 字节，IEEE 754）
    private func readDouble() -> Double {
        guard offset + 8 <= data.count else { return 0 }
        let longValue = readLong()
        return Double(bitPattern: UInt64(bitPattern: longValue))
    }
    
    /// 读取列表
    private func readList() throws -> [Any] {
        guard offset < data.count else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据不足，无法读取列表类型",
                i18nKey: "error.filesystem.nbt_insufficient_data_for_list",
                level: .notification
            )
        }
        
        let listType = NBTType(rawValue: data[offset]) ?? .end
        offset += 1
        
        let length = Int(readInt())
        var result: [Any] = []
        
        for _ in 0..<length {
            let value = try readTagValue(type: listType)
            result.append(value)
        }
        
        return result
    }
    
    /// 解压 GZIP 数据（使用系统命令）
    private func decompressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT GZIP 数据为空",
                i18nKey: "error.filesystem.nbt_gzip_empty_data",
                level: .notification
            )
        }
        
        // 创建临时文件用于存储压缩数据
        let tempDir = FileManager.default.temporaryDirectory
        let tempInputFile = tempDir.appendingPathComponent(UUID().uuidString + ".gz")
        let tempOutputFile = tempDir.appendingPathComponent(UUID().uuidString)
        
        defer {
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        // 写入压缩数据到临时文件
        try data.write(to: tempInputFile)
        
        // 使用系统 gzip 命令解压
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", tempInputFile.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "无法启动 gzip 解压进程: \(error.localizedDescription)",
                i18nKey: "error.filesystem.nbt_gzip_process_start_failed",
                level: .notification
            )
        }
        
        // 读取解压后的数据
        let fileHandle = pipe.fileHandleForReading
        let decompressedData = fileHandle.readDataToEndOfFile()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw GlobalError.fileSystem(
                chineseMessage: "GZIP 解压失败，退出状态: \(process.terminationStatus)",
                i18nKey: "error.filesystem.nbt_gzip_decompress_failed",
                level: .notification
            )
        }
        
        guard !decompressedData.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "GZIP 解压后数据为空",
                i18nKey: "error.filesystem.nbt_gzip_decompressed_empty",
                level: .notification
            )
        }
        
        return decompressedData
    }
    
    // MARK: - NBT 写入方法
    
    /// 将字典数据编码为 NBT 格式（支持 GZIP 压缩）
    /// - Parameters:
    ///   - data: 要编码的字典数据
    ///   - compress: 是否使用 GZIP 压缩，默认 true
    /// - Returns: 编码后的 NBT 数据
    /// - Throws: 编码错误
    static func encode(_ data: [String: Any], compress: Bool = true) throws -> Data {
        let parser = NBTParser()
        parser.outputData = Data()
        
        // 写入根标签类型（TAG_Compound）
        parser.writeByte(NBTType.compound.rawValue)
        
        // 写入根标签名称（空字符串）
        parser.writeString("")
        
        // 写入 Compound 内容
        try parser.writeCompound(data)
        
        // 如果启用压缩，使用 gzip 压缩
        if compress {
            return try parser.compressGzip(data: parser.outputData)
        }
        
        return parser.outputData
    }
    
    /// 写入字节
    private func writeByte(_ value: UInt8) {
        outputData.append(value)
    }
    
    /// 写入短整型（2 字节，大端序）
    private func writeShort(_ value: UInt16) {
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }
    
    /// 写入整型（4 字节，大端序）
    private func writeInt(_ value: Int32) {
        outputData.append(UInt8((value >> 24) & 0xFF))
        outputData.append(UInt8((value >> 16) & 0xFF))
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }
    
    /// 写入长整型（8 字节，大端序）
    private func writeLong(_ value: Int64) {
        outputData.append(UInt8((value >> 56) & 0xFF))
        outputData.append(UInt8((value >> 48) & 0xFF))
        outputData.append(UInt8((value >> 40) & 0xFF))
        outputData.append(UInt8((value >> 32) & 0xFF))
        outputData.append(UInt8((value >> 24) & 0xFF))
        outputData.append(UInt8((value >> 16) & 0xFF))
        outputData.append(UInt8((value >> 8) & 0xFF))
        outputData.append(UInt8(value & 0xFF))
    }
    
    /// 写入字符串
    private func writeString(_ value: String) {
        let stringData = value.data(using: .utf8) ?? Data()
        let length = UInt16(stringData.count)
        writeShort(length)
        outputData.append(stringData)
    }
    
    /// 写入浮点数（4 字节，IEEE 754）
    private func writeFloat(_ value: Float) {
        let bitPattern = value.bitPattern
        // 将 UInt32 的位模式转换为 Int32（保持位模式不变）
        let intValue = Int32(bitPattern: bitPattern)
        writeInt(intValue)
    }
    
    /// 写入双精度浮点数（8 字节，IEEE 754）
    private func writeDouble(_ value: Double) {
        let bitPattern = value.bitPattern
        // 将 UInt64 的位模式转换为 Int64（保持位模式不变）
        let longValue = Int64(bitPattern: bitPattern)
        writeLong(longValue)
    }
    
    /// 写入 Compound 标签
    private func writeCompound(_ compound: [String: Any]) throws {
        for (name, value) in compound {
            let tagType = try inferNBTType(from: value)
            writeByte(tagType.rawValue)
            writeString(name)
            try writeTagValue(type: tagType, value: value)
        }
        // 写入 End 标签
        writeByte(NBTType.end.rawValue)
    }
    
    /// 写入标签值
    private func writeTagValue(type: NBTType, value: Any) throws {
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
    
    /// 写入列表
    private func writeList(_ value: Any) throws {
        guard let array = value as? [Any], !array.isEmpty else {
            // 空列表，写入类型为 End，长度为 0
            writeByte(NBTType.end.rawValue)
            writeInt(0)
            return
        }
        
        // 推断列表元素类型
        let elementType = try inferNBTType(from: array[0])
        writeByte(elementType.rawValue)
        writeInt(Int32(array.count))
        
        for item in array {
            try writeTagValue(type: elementType, value: item)
        }
    }
    
    /// 从值推断 NBT 类型
    private func inferNBTType(from value: Any) throws -> NBTType {
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
            // 默认转换为字符串
            return .string
        }
    }
    
    /// 压缩 GZIP 数据（使用系统命令）
    private func compressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据为空，无法压缩",
                i18nKey: "error.filesystem.nbt_empty_data_for_compress",
                level: .notification
            )
        }
        
        // 创建临时文件用于存储未压缩数据
        let tempDir = FileManager.default.temporaryDirectory
        let tempInputFile = tempDir.appendingPathComponent(UUID().uuidString)
        let tempOutputFile = tempDir.appendingPathComponent(UUID().uuidString + ".gz")
        
        defer {
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        // 写入未压缩数据到临时文件
        try data.write(to: tempInputFile)
        
        // 使用系统 gzip 命令压缩
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", tempInputFile.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "无法启动 gzip 压缩进程: \(error.localizedDescription)",
                i18nKey: "error.filesystem.nbt_gzip_compress_process_start_failed",
                level: .notification
            )
        }
        
        // 读取压缩后的数据
        let fileHandle = pipe.fileHandleForReading
        let compressedData = fileHandle.readDataToEndOfFile()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw GlobalError.fileSystem(
                chineseMessage: "GZIP 压缩失败，退出状态: \(process.terminationStatus)",
                i18nKey: "error.filesystem.nbt_gzip_compress_failed",
                level: .notification
            )
        }
        
        guard !compressedData.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "GZIP 压缩后数据为空",
                i18nKey: "error.filesystem.nbt_gzip_compressed_empty",
                level: .notification
            )
        }
        
        return compressedData
    }
}


