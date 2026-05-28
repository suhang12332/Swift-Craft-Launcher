//
//  NBTParser+Gzip.swift
//  SwiftCraftLauncher
//

import Foundation

extension NBTParser {

    func decompressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT GZIP 数据为空",
                i18nKey: "error.filesystem.nbt_gzip_empty_data",
                level: .notification
            )
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempInputFile = tempDir.appendingPathComponent(UUID().uuidString + ".gz")
        let tempOutputFile = tempDir.appendingPathComponent(UUID().uuidString)

        defer {
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }

        try data.write(to: tempInputFile)

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

    func compressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "NBT 数据为空，无法压缩",
                i18nKey: "error.filesystem.nbt_empty_data_for_compress",
                level: .notification
            )
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempInputFile = tempDir.appendingPathComponent(UUID().uuidString)
        let tempOutputFile = tempDir.appendingPathComponent(UUID().uuidString + ".gz")

        defer {
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }

        try data.write(to: tempInputFile)

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
