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
            AppLog.common.error("Invalid JWT format: not standard 3-part format")
            return nil
        }

        let payload = components[1]
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            AppLog.common.error("JWT payload base64 decode failed")
            return nil
        }

        do {
            let payloadJSON = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]

            if let exp = payloadJSON?["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                    AppLog.common.debug("Parsed expiration time from JWT: \(expirationDate)")
                }
                return expirationDate
            } else {
                AppLog.common.error("exp field not found in JWT payload")
                return nil
            }
        } catch {
            AppLog.common.error("JWT payload JSON parsing failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extracts all claims from a JWT token payload.
    /// - Parameter jwt: A JWT token string.
    /// - Returns: A dictionary of claims, or `nil` if parsing fails.
    static func extractAllInfo(from jwt: String) -> [String: Any]? {
        let components = jwt.components(separatedBy: ".")

        guard components.count == 3 else {
            AppLog.common.error("Invalid JWT format: not standard 3-part format")
            return nil
        }

        let payload = components[1]
        let paddedPayload = addPadding(to: payload)

        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            AppLog.common.error("JWT payload base64 decode failed")
            return nil
        }

        do {
            return try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        } catch {
            AppLog.common.error("JWT payload JSON parsing failed: \(error.localizedDescription)")
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
                AppLog.common.debug("Using JWT-parsed Minecraft token expiration: \(expirationTime)")
            }
            return expirationTime
        } else {
            let defaultExpiration = Date().addingTimeInterval(defaultMinecraftTokenExpiration)
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("Using default Minecraft token expiration: \(defaultExpiration)")
            }
            return defaultExpiration
        }
    }
}
