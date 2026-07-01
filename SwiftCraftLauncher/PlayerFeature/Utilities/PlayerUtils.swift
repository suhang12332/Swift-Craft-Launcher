//
//  PlayerUtils.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CryptoKit
import SwiftUI

/// Provides utility functions for player identity operations.
enum PlayerUtils {
    private static let names = ["alex", "ari", "efe", "kai", "makena", "noor", "steve", "sunny", "zuri"]
    private static let offlinePrefix = "OfflinePlayer:"

    /// Generates an offline-mode UUID for the given username.
    ///
    /// The UUID is derived from an MD5 hash of the string `"OfflinePlayer:<username>"`
    /// and formatted according to RFC 4122 (version 3).
    ///
    /// - Parameter username: The player's username.
    /// - Returns: A 32-character hex UUID string without hyphens.
    /// - Throws: A `GlobalError` if the username is empty or encoding fails.
    static func generateOfflineUUID(for username: String) throws -> String {
        guard !username.isEmpty else {
            throw GlobalError.player(
                i18nKey: "error.player.invalid_username_empty",
                level: .notification,
            )
        }

        guard let data = (offlinePrefix + username).data(using: .utf8) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.username_encode_failed",
                level: .notification,
            )
        }

        var bytes = [UInt8](Insecure.MD5.hash(data: data))
        bytes[6] = (bytes[6] & 0x0F) | 0x30
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        let uuidString = uuid.uuidString.lowercased()
        AppLog.player.debug("Generated offline UUID - username: \(username), UUID: \(uuidString)")
        return uuidString.replacingOccurrences(of: "-", with: "")
    }

    /// Returns a default avatar name for the given UUID.
    ///
    /// - Parameter uuid: The player's UUID string.
    /// - Returns: An avatar asset name, or `nil` if the UUID is invalid.
    static func avatarName(for uuid: String) -> String? {
        guard let index = nameIndex(for: uuid) else {
            AppLog.player.error("Cannot get avatar name - invalid UUID: \(uuid)")
            return nil
        }
        return names[index]
    }

    private static func nameIndex(for uuid: String) -> Int? {
        let cleanUUID = uuid.replacingOccurrences(of: "-", with: "")
        guard cleanUUID.count >= 32 else { return nil }
        let iStr = String(cleanUUID.prefix(16))
        let uStr = String(cleanUUID.dropFirst(16).prefix(16))
        guard let i = UInt64(iStr, radix: 16), let u = UInt64(uStr, radix: 16) else { return nil }
        let f = i ^ u
        let mixedBits = (f ^ (f >> 32)) & 0xFFFF_FFFF
        let ii = Int32(bitPattern: UInt32(truncatingIfNeeded: mixedBits))
        return (Int(ii) % names.count + names.count) % names.count
    }
}
