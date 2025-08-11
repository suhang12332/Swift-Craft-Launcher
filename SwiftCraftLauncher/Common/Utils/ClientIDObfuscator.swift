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
    
    // 静态方法：加密原始ClientID
    static func encryptClientID(_ clientID: String) -> String {
        let obfuscator = ClientIDObfuscator(encryptedString: "")
        let parts = obfuscator.splitClientID(clientID)
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
        var parts: [String] = []
        
        for i in 0..<6 {
            let startIndex = clientID.index(clientID.startIndex, offsetBy: i * partLength)
            let endIndex = clientID.index(startIndex, offsetBy: partLength)
            let part = String(clientID[startIndex..<endIndex])
            parts.append(part)
        }
        
        return parts
    }
}
