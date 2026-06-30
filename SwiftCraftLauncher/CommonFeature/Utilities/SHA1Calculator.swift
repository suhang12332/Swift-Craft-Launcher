//
//  SHA1Calculator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CommonCrypto
import CryptoKit
import Foundation

/// Provides SHA1 hash computation for data and files.
public enum SHA1Calculator {
    /// Computes the SHA1 hash of in-memory data.
    /// - Parameter data: The data to hash.
    /// - Returns: A lowercase hexadecimal SHA1 string.
    public static func sha1(of data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Computes the SHA1 hash of a file at the given URL using streaming.
    /// - Parameter url: The file URL.
    /// - Returns: A lowercase hexadecimal SHA1 string.
    /// - Throws: A `GlobalError` if the file cannot be read.
    public static func sha1(ofFileAt url: URL) throws -> String {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            var context = CC_SHA1_CTX()
            CC_SHA1_Init(&context)

            let bufferSize = 1024 * 1024

            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                if !data.isEmpty {
                    data.withUnsafeBytes { bytes in
                        _ = CC_SHA1_Update(&context, bytes.baseAddress, CC_LONG(data.count))
                    }
                    return true
                }
                return false
            }) { }

            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            _ = CC_SHA1_Final(&digest, &context)

            return digest.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "计算文件 SHA1 失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.sha1_calculation_failed",
                level: .notification,
            )
        }
    }

    /// Computes the SHA1 hash of a file, returning `nil` on failure.
    /// - Parameter url: The file URL.
    /// - Returns: A lowercase hexadecimal SHA1 string, or `nil` if the computation fails.
    public static func sha1Silent(ofFileAt url: URL) -> String? {
        do {
            return try sha1(ofFileAt: url)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算文件哈希值失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return nil
        }
    }

    /// Computes the SHA1 hash of in-memory data using CryptoKit.
    /// - Parameter data: The data to hash.
    /// - Returns: A lowercase hexadecimal SHA1 string.
    public static func sha1WithCryptoKit(of data: Data) -> String {
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension Data {
    /// The SHA1 hash of this data instance.
    var sha1: String {
        SHA1Calculator.sha1(of: self)
    }
}
