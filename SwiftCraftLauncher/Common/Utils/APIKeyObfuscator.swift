import Foundation

/// 统一的解密工具
/// 支持 Client ID 和 API Key 的解密
enum Obfuscator {
    private static let xorKey: UInt8 = 0x7A
    private static let indexOrder = [3, 0, 5, 1, 4, 2]

    // MARK: - 解密核心方法

    private static func decrypt(_ input: String) -> String {
        guard let data = Data(base64Encoded: input) else { return "" }
        let bytes = data.map { ($0 ^ xorKey) >> 3 | ($0 ^ xorKey) << 5 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    // MARK: - Client ID 方法

    /// 解密 Client ID
    static func decryptClientID(_ encryptedString: String) -> String {
        // 将加密字符串按固定长度分割（每个部分8个字符）
        let partLength = 8
        var parts: [String] = []

        for i in 0..<6 {
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: i * partLength)
            let endIndex = encryptedString.index(startIndex, offsetBy: partLength)
            let part = String(encryptedString[startIndex..<endIndex])
            parts.append(part)
        }

        // 按照indexOrder还原原始顺序
        var restoredParts = Array(repeating: "", count: parts.count)
        for (j, part) in parts.enumerated() {
            if let i = indexOrder.firstIndex(of: j) {
                restoredParts[i] = decrypt(part)
            }
        }

        return restoredParts.joined()
    }

    // MARK: - API Key 方法

    /// 解密 API Key
    static func decryptAPIKey(_ encryptedString: String) -> String {
        // 计算需要分割的部分数量（每个部分加密后是 8 个字符）
        let partLength = 8
        let totalLength = encryptedString.count
        let numParts = (totalLength + partLength - 1) / partLength // 向上取整

        // 将加密字符串按固定长度分割
        var parts: [String] = []
        for i in 0..<numParts {
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: i * partLength)
            let endIndex = min(encryptedString.index(startIndex, offsetBy: partLength), encryptedString.endIndex)
            let part = String(encryptedString[startIndex..<endIndex])
            parts.append(part)
        }

        // 如果部分数量少于 6，需要填充到 6 个
        while parts.count < 6 {
            parts.append("")
        }

        // 按照 indexOrder 还原原始顺序（只处理前 6 个部分）
        var restoredParts = Array(repeating: "", count: min(parts.count, 6))
        for (j, part) in parts.prefix(6).enumerated() {
            if j < indexOrder.count, let i = indexOrder.firstIndex(of: j) {
                if i < restoredParts.count {
                    restoredParts[i] = decrypt(part)
                }
            }
        }

        // 如果有超过 6 个部分，直接按顺序解密
        var result = restoredParts.joined()
        if parts.count > 6 {
            for part in parts.suffix(from: 6) {
                result += decrypt(part)
            }
        }

        return result
    }
}
