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
    private static let offlineNameAllowedCharacters =
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")
    /// The inclusive length range for offline player names.
    static let offlineNameLengthRange = 3 ... 16

    /// Returns whether the given name has a valid offline player name length.
    ///
    /// - Parameter name: The player name to validate.
    /// - Returns: `true` if the name is 3–16 characters long.
    static func isValidOfflineNameLength(_ name: String) -> Bool {
        offlineNameLengthRange.contains(name.count)
    }

    /// Returns whether the given name contains only allowed offline player name characters.
    ///
    /// - Parameter name: The player name to validate.
    /// - Returns: `true` if the name only contains half-width ASCII letters, digits, and underscores.
    static func isValidOfflineNameCharacters(_ name: String) -> Bool {
        name.unicodeScalars.allSatisfy { offlineNameAllowedCharacters.contains($0) }
    }

    /// Returns whether the given name is a valid offline player name.
    ///
    /// A valid name is 3–16 characters long and contains only half-width ASCII
    /// letters, digits, and underscores. Chinese characters, spaces, and any
    /// other special characters are rejected.
    ///
    /// - Parameter name: The player name to validate.
    /// - Returns: `true` if the name only contains allowed characters.
    static func isValidOfflineName(_ name: String) -> Bool {
        isValidOfflineNameLength(name) && isValidOfflineNameCharacters(name)
    }

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
                message: "Username is empty, cannot generate offline UUID",
            )
        }

        guard let data = (offlinePrefix + username).data(using: .utf8) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.username_encode_failed",
                level: .notification,
                message: "Failed to encode \"\(offlinePrefix + username)\" to UTF-8 data",
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
