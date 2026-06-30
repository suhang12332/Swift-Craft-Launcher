//
//  APIKeyObfuscator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides obfuscation and deobfuscation utilities for API keys and client IDs.
enum Obfuscator {
    private static let xorKey: UInt8 = 0x7A
    private static let indexOrder = [3, 0, 5, 1, 4, 2]

    private static func decrypt(_ input: String) -> String {
        guard let data = Data(base64Encoded: input) else { return "" }
        let bytes = data.map { ($0 ^ xorKey) >> 3 | ($0 ^ xorKey) << 5 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// Decrypts an obfuscated client ID string.
    static func decryptClientID(_ encryptedString: String) -> String {
        let partLength = 8
        var parts: [String] = []

        for i in 0 ..< 6 {
            let startOffset = i * partLength
            guard startOffset < encryptedString.count else {
                parts.append("")
                continue
            }
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: startOffset)
            let endIndex = encryptedString.index(startIndex, offsetBy: partLength, limitedBy: encryptedString.endIndex) ?? encryptedString.endIndex
            let part = String(encryptedString[startIndex ..< endIndex])
            parts.append(part)
        }

        var restoredParts = Array(repeating: "", count: parts.count)
        for (j, part) in parts.enumerated() {
            if let i = indexOrder.firstIndex(of: j) {
                restoredParts[i] = decrypt(part)
            }
        }

        return restoredParts.joined()
    }

    /// Decrypts an obfuscated API key string.
    static func decryptAPIKey(_ encryptedString: String) -> String {
        let partLength = 8
        let totalLength = encryptedString.count
        let numParts = (totalLength + partLength - 1) / partLength

        var parts: [String] = []
        for i in 0 ..< numParts {
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: i * partLength)
            let endIndex = min(encryptedString.index(startIndex, offsetBy: partLength), encryptedString.endIndex)
            let part = String(encryptedString[startIndex ..< endIndex])
            parts.append(part)
        }

        while parts.count < 6 {
            parts.append("")
        }

        var restoredParts = Array(repeating: "", count: min(parts.count, 6))
        for (j, part) in parts.prefix(6).enumerated() {
            if j < indexOrder.count, let i = indexOrder.firstIndex(of: j) {
                if i < restoredParts.count {
                    restoredParts[i] = decrypt(part)
                }
            }
        }

        var result = restoredParts.joined()
        if parts.count > 6 {
            for part in parts.suffix(from: 6) {
                result += decrypt(part)
            }
        }

        return result
    }
}
