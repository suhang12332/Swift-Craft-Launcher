//
//  NBTParser.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// NBT 解析器
/// 用于解析和生成 Minecraft 的 NBT 格式文件（如 servers.dat）
class NBTParser {
    var data: Data
    var offset: Int = 0
    var outputData: Data = Data()

    init(data: Data) {
        self.data = data
    }

    private init() {
        self.data = Data()
    }

    func parse() throws -> [String: Any] {
        if data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B {
            data = try decompressGzip(data: data)
            offset = 0
        }

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
        _ = try readString()
        return try readCompound() as [String: Any]
    }

    static func encode(_ data: [String: Any], compress: Bool = true) throws -> Data {
        let parser = NBTParser()
        parser.outputData = Data()

        parser.writeByte(NBTType.compound.rawValue)
        parser.writeString("")
        try parser.writeCompound(data)

        if compress {
            return try parser.compressGzip(data: parser.outputData)
        }

        return parser.outputData
    }
}
