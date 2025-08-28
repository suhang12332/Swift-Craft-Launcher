import Foundation

class ClientIDObfuscator {
    private let xorKey: UInt8 = 0x7A
    private let indexOrder = [3, 0, 5, 1, 4, 2]
    
    // 接收传入的加密字符串
    private let encryptedString: String
    
    init(encryptedString: String) {
        self.encryptedString = encryptedString
    }
    
    private func encrypt(_ input: String) -> String {
        let bytes = [UInt8](input.utf8)
        let transformed = bytes.map { ($0 << 3 | $0 >> 5) ^ xorKey }
        return Data(transformed).base64EncodedString()
    }
    
    private func decrypt(_ input: String) -> String {
        guard let data = Data(base64Encoded: input) else { return "" }
        let bytes = data.map { ($0 ^ xorKey) >> 3 | ($0 ^ xorKey) << 5 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    func getClientID() -> String {
        // 将加密字符串按固定长度分割（每个部分8个字符）
        let partLength = 8
        let expectedLength = partLength * 6 // 48个字符
        
        // 检查字符串长度是否足够
        guard encryptedString.count >= expectedLength else {
            print("Error: encryptedString length is \(encryptedString.count), expected at least \(expectedLength)")
            return ""
        }
        
        var parts: [String] = []
        
        for i in 0..<6 {
            let startOffset = i * partLength
            let endOffset = startOffset + partLength
            
            // 安全地获取子字符串
            guard startOffset < encryptedString.count,
                  endOffset <= encryptedString.count else {
                print("Error: Index out of bounds at part \(i)")
                return ""
            }
            
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: startOffset)
            let endIndex = encryptedString.index(encryptedString.startIndex, offsetBy: endOffset)
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
    
    // 静态方法：加密原始ClientID
    static func encryptClientID(_ clientID: String) -> String {
        let obfuscator = ClientIDObfuscator(encryptedString: "")
        let parts = obfuscator.splitClientID(clientID)
        
        // 检查分割是否成功
        guard parts.count == 6 else {
            print("Error: Failed to split clientID into 6 parts, got \(parts.count) parts")
            return ""
        }
        
        var encryptedParts = Array(repeating: "", count: parts.count)
        
        // 按照indexOrder进行加密和乱序
        let indexOrder = [3, 0, 5, 1, 4, 2]
        for (i, part) in parts.enumerated() {
            let encrypted = obfuscator.encrypt(part)
            encryptedParts[indexOrder[i]] = encrypted
        }
        
        return encryptedParts.joined()
    }
    
    // 辅助方法：分割ClientID为6个部分
    private func splitClientID(_ clientID: String) -> [String] {
        let partLength = 6
        let expectedLength = partLength * 6 // 36个字符
        
        // 检查字符串长度是否足够
        guard clientID.count >= expectedLength else {
            print("Error: clientID length is \(clientID.count), expected at least \(expectedLength)")
            return []
        }
        
        var parts: [String] = []
        
        for i in 0..<6 {
            let startOffset = i * partLength
            let endOffset = startOffset + partLength
            
            // 安全地获取子字符串
            guard startOffset < clientID.count,
                  endOffset <= clientID.count else {
                print("Error: Index out of bounds at part \(i) in splitClientID")
                return []
            }
            
            let startIndex = clientID.index(clientID.startIndex, offsetBy: startOffset)
            let endIndex = clientID.index(clientID.startIndex, offsetBy: endOffset)
            let part = String(clientID[startIndex..<endIndex])
            parts.append(part)
        }
        
        return parts
    }
}
