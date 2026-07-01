//
//  JWTDecoder.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Decodes JWT tokens and extracts claim information.
enum JWTDecoder {
    /// Extracts the expiration date from a JWT token.
    /// - Parameter jwt: A JWT token string.
    /// - Returns: The expiration date, or `nil` if parsing fails.
    static func extractExpirationTime(from jwt: String) -> Date? {
        let components = jwt.components(separatedBy: ".")

        guard components.count == 3 else {
            AppLog.common.error("JWT格式无效：不是标准的3部分格式")
            return nil
        }

        let payload = components[1]
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            AppLog.common.error("JWT payload base64解码失败")
            return nil
        }

        do {
            let payloadJSON = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]

            if let exp = payloadJSON?["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                    AppLog.common.debug("从JWT中解析到过期时间：\(expirationDate)")
                }
                return expirationDate
            } else {
                AppLog.common.error("JWT payload中未找到exp字段")
                return nil
            }
        } catch {
            AppLog.common.error("JWT payload JSON解析失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// Extracts all claims from a JWT token payload.
    /// - Parameter jwt: A JWT token string.
    /// - Returns: A dictionary of claims, or `nil` if parsing fails.
    static func extractAllInfo(from jwt: String) -> [String: Any]? {
        let components = jwt.components(separatedBy: ".")

        guard components.count == 3 else {
            AppLog.common.error("JWT格式无效：不是标准的3部分格式")
            return nil
        }

        let payload = components[1]
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            AppLog.common.error("JWT payload base64解码失败")
            return nil
        }

        do {
            return try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        } catch {
            AppLog.common.error("JWT payload JSON解析失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// Adds the necessary padding characters to a Base64 string.
    private static func addPadding(to base64String: String) -> String {
        var padded = base64String
        let remainder = padded.count % 4
        if remainder > 0 {
            let paddingNeeded = 4 - remainder
            padded = "\(padded)\(String(repeating: "=", count: paddingNeeded))"
        }
        return padded
    }

    /// Indicates whether a JWT token will expire within the specified buffer time.
    /// - Parameters:
    ///   - jwt: A JWT token string.
    ///   - bufferTime: The buffer interval in seconds. Defaults to 300 (5 minutes).
    /// - Returns: `true` if the token is expiring soon or cannot be decoded.
    static func isTokenExpiringSoon(_ jwt: String, bufferTime: TimeInterval = 300) -> Bool {
        guard let expirationTime = extractExpirationTime(from: jwt) else {
            return true
        }

        let currentTime = Date()
        let expirationTimeWithBuffer = expirationTime.addingTimeInterval(-bufferTime)

        return currentTime >= expirationTimeWithBuffer
    }
}

extension JWTDecoder {
    /// Default expiration interval for Minecraft tokens (24 hours), used when the JWT cannot be decoded.
    static let defaultMinecraftTokenExpiration: TimeInterval = 24 * 60 * 60

    /// Returns the expiration date for a Minecraft token.
    /// Attempts to decode the JWT; falls back to the default expiration interval.
    /// - Parameter minecraftToken: A Minecraft access token.
    /// - Returns: The expiration date.
    static func getMinecraftTokenExpiration(from minecraftToken: String) -> Date {
        if let expirationTime = extractExpirationTime(from: minecraftToken) {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("使用JWT解析的Minecraft token过期时间：\(expirationTime)")
            }
            return expirationTime
        } else {
            let defaultExpiration = Date().addingTimeInterval(defaultMinecraftTokenExpiration)
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("使用默认的Minecraft token过期时间：\(defaultExpiration)")
            }
            return defaultExpiration
        }
    }
}
