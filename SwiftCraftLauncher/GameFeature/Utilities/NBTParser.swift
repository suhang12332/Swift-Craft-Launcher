//
//  NBTParser.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses and encodes Minecraft's NBT (Named Binary Tag) format, such as `servers.dat`.
class NBTParser {
    var data: Data
    var offset: Int = 0
    var outputData: Data = .init()

    init(data: Data) {
        self.data = data
    }

    private init() {
        data = Data()
    }

    /// Parses the NBT data into a dictionary.
    /// - Throws: A `GlobalError` if the data is empty or the root tag is not a compound.
    /// - Returns: The root compound as a dictionary.
    func parse() throws -> [String: Any] {
        if data.count >= 2, data[0] == 0x1F, data[1] == 0x8B {
            data = try decompressGzip(data: data)
            offset = 0
        }

        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_empty_data",
                level: .notification,
            )
        }

        let tagType = NBTType(rawValue: data[offset]) ?? .end
        guard tagType == .compound else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_invalid_root",
                level: .notification,
            )
        }

        offset += 1
        _ = try readString()
        return try readCompound() as [String: Any]
    }

    /// Encodes a dictionary into NBT data.
    /// - Parameters:
    ///   - data: The dictionary to encode.
    ///   - compress: Whether to gzip-compress the output. Defaults to `true`.
    /// - Throws: A `GlobalError` if encoding fails.
    /// - Returns: The encoded NBT data.
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
