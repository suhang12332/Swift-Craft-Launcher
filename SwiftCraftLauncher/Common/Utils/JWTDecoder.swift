import Foundation

/// JWT解码器工具类
/// 解析 JWT 并提取过期时间
enum JWTDecoder {
    /// 解析JWT token并提取过期时间
    /// - Parameter jwt: JWT token字符串
    /// - Returns: 过期时间，如果解析失败则返回nil
    static func extractExpirationTime(from jwt: String) -> Date? {
        // JWT格式：header.payload.signature
        let components = jwt.components(separatedBy: ".")

        // 确保有3个部分
        guard components.count == 3 else {
            Logger.shared.warning("JWT格式无效：不是标准的3部分格式")
            return nil
        }

        // 解析payload部分（第二部分）
        let payload = components[1]

        // 添加padding以确保base64解码正确
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            Logger.shared.warning("JWT payload base64解码失败")
            return nil
        }

        do {
            let payloadJSON = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]

            // 提取exp字段（过期时间戳）
            if let exp = payloadJSON?["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                Logger.shared.debug("从JWT中解析到过期时间：\(expirationDate)")
                return expirationDate
            } else {
                Logger.shared.warning("JWT payload中未找到exp字段")
                return nil
            }
        } catch {
            Logger.shared.warning("JWT payload JSON解析失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 解析JWT token并提取所有可用信息
    /// - Parameter jwt: JWT token字符串
    /// - Returns: 包含JWT信息的字典，如果解析失败则返回nil
    static func extractAllInfo(from jwt: String) -> [String: Any]? {
        let components = jwt.components(separatedBy: ".")

        guard components.count == 3 else {
            Logger.shared.warning("JWT格式无效：不是标准的3部分格式")
            return nil
        }

        let payload = components[1]
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            Logger.shared.warning("JWT payload base64解码失败")
            return nil
        }

        do {
            let payloadJSON = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
            return payloadJSON
        } catch {
            Logger.shared.warning("JWT payload JSON解析失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 为base64字符串添加必要的padding
    /// - Parameter base64String: 原始base64字符串
    /// - Returns: 添加了padding的base64字符串
    private static func addPadding(to base64String: String) -> String {
        var padded = base64String

        // 计算需要添加的padding数量
        let remainder = padded.count % 4
        if remainder > 0 {
            let paddingNeeded = 4 - remainder
            // 使用字符串插值而非字符串拼接
            padded = "\(padded)\(String(repeating: "=", count: paddingNeeded))"
        }

        return padded
    }

    /// 检查JWT token是否即将过期
    /// - Parameters:
    ///   - jwt: JWT token字符串
    ///   - bufferTime: 缓冲时间（秒），默认5分钟
    /// - Returns: 是否即将过期
    static func isTokenExpiringSoon(_ jwt: String, bufferTime: TimeInterval = 300) -> Bool {
        guard let expirationTime = extractExpirationTime(from: jwt) else {
            // 如果无法解析过期时间，认为已过期
            return true
        }

        let currentTime = Date()
        let expirationTimeWithBuffer = expirationTime.addingTimeInterval(-bufferTime)

        return currentTime >= expirationTimeWithBuffer
    }
}

// MARK: - Minecraft Token Constants
extension JWTDecoder {
    /// Minecraft token的默认过期时间（24小时）
    /// 当无法从JWT中解析过期时间时使用
    static let defaultMinecraftTokenExpiration: TimeInterval = 24 * 60 * 60 // 24小时

    /// 获取Minecraft token的过期时间
    /// 优先从JWT中解析，如果失败则使用默认值
    /// - Parameter minecraftToken: Minecraft访问令牌
    /// - Returns: 过期时间
    static func getMinecraftTokenExpiration(from minecraftToken: String) -> Date {
        if let expirationTime = extractExpirationTime(from: minecraftToken) {
            Logger.shared.debug("使用JWT解析的Minecraft token过期时间：\(expirationTime)")
            return expirationTime
        } else {
            let defaultExpiration = Date().addingTimeInterval(defaultMinecraftTokenExpiration)
            Logger.shared.debug("使用默认的Minecraft token过期时间：\(defaultExpiration)")
            return defaultExpiration
        }
    }
}
