//
//  NBTParser+Gzip.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension NBTParser {
    /// Decompresses gzip-compressed data using the system `gunzip` utility.
    /// - Parameter data: The gzip-compressed data.
    /// - Throws: A `GlobalError` if the input is empty, the process fails, or the output is empty.
    /// - Returns: The decompressed data.
    func decompressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_gzip_empty_data",
                level: .notification,
                message: "input data is empty, nothing to decompress",
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
                i18nKey: "error.filesystem.nbt_gzip_process_start_failed",
                level: .notification,
                message: "failed to start gunzip process at /usr/bin/gunzip, error: \(error.localizedDescription)",
            )
        }

        let fileHandle = pipe.fileHandleForReading
        let decompressedData = fileHandle.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_gzip_decompress_failed",
                level: .notification,
                message: "gunzip exited with status \(process.terminationStatus), input file: \(tempInputFile.path)",
            )
        }

        guard !decompressedData.isEmpty else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_gzip_decompressed_empty",
                level: .notification,
                message: "decompressed data is empty",
            )
        }

        return decompressedData
    }

    /// Compresses data using the system `gzip` utility.
    /// - Parameter data: The data to compress.
    /// - Throws: A `GlobalError` if the input is empty, the process fails, or the output is empty.
    /// - Returns: The gzip-compressed data.
    func compressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_empty_data_for_compress",
                level: .notification,
                message: "input data is empty, nothing to compress",
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
                i18nKey: "error.filesystem.nbt_gzip_compress_process_start_failed",
                level: .notification,
                message: "failed to start gzip process at /usr/bin/gzip, error: \(error.localizedDescription)",
            )
        }

        let fileHandle = pipe.fileHandleForReading
        let compressedData = fileHandle.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_gzip_compress_failed",
                level: .notification,
                message: "gzip exited with status \(process.terminationStatus), input file: \(tempInputFile.path)",
            )
        }

        guard !compressedData.isEmpty else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.nbt_gzip_compressed_empty",
                level: .notification,
                message: "compressed data is empty",
            )
        }

        return compressedData
    }
}
