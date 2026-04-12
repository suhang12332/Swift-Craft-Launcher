//
//  SHA1Calculator.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import Foundation
import CommonCrypto
import CryptoKit

/// 统一的 SHA1 计算工具类
public enum SHA1Calculator {

    /// 计算 Data 的 SHA1 哈希值（适用于小文件或内存中的数据）
    /// - Parameter data: 要计算哈希的数据
    /// - Returns: SHA1 哈希字符串
    public static func sha1(of data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// 计算文件的 SHA1 哈希值（流式处理，适用于大文件）
    /// - Parameter url: 文件路径
    /// - Returns: SHA1 哈希字符串
    /// - Throws: GlobalError 当操作失败时
    public static func sha1(ofFileAt url: URL) throws -> String {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            var context = CC_SHA1_CTX()
            CC_SHA1_Init(&context)

            // 使用 1MB 缓冲区进行流式处理
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
            }) {}

            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            _ = CC_SHA1_Final(&digest, &context)

            return digest.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "计算文件 SHA1 失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.sha1_calculation_failed",
                level: .notification
            )
        }
    }

    /// 计算文件的 SHA1 哈希值（静默版本，返回可选值）
    /// - Parameter url: 文件路径
    /// - Returns: SHA1 哈希字符串，如果计算失败则返回 nil
    public static func sha1Silent(ofFileAt url: URL) -> String? {
        do {
            return try sha1(ofFileAt: url)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算文件哈希值失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 使用 CryptoKit 计算 SHA1（适用于需要 CryptoKit 特性的场景）
    /// - Parameter data: 要计算哈希的数据
    /// - Returns: SHA1 哈希字符串
    public static func sha1WithCryptoKit(of data: Data) -> String {
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Data Extension (保持向后兼容)
extension Data {
    /// 计算当前 Data 的 SHA1 哈希值
    var sha1: String {
        return SHA1Calculator.sha1(of: self)
    }
}
