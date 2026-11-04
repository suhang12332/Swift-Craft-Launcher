//
//  KeychainManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Security

/// Manages secure storage of sensitive data in the system Keychain.
enum KeychainManager {
    private static let service = Bundle.main.identifier

    /// Stores data in the Keychain.
    ///
    /// Existing items are updated in place, so a failed write does not delete
    /// the previously stored data.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - account: The account identifier.
    ///   - key: The key name.
    /// - Returns: `true` if the operation succeeded.
    static func save(data: Data, account: String, key: String) -> Bool {
        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account).\(key)",
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        var status = SecItemUpdate(matchQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = matchQuery
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)

            // Another write may have inserted the item between the update and
            // the add; retry as an update rather than losing the new data.
            if status == errSecDuplicateItem {
                status = SecItemUpdate(matchQuery as CFDictionary, updateAttributes as CFDictionary)
            }
        }

        if status == errSecSuccess {
            AppLog.common.debug("Keychain save succeeded - account: \(account), key: \(key)")
            return true
        } else {
            AppLog.common.error("Keychain save failed - account: \(account), key: \(key), status: \(status)")
            return false
        }
    }

    /// Retrieves data from the Keychain.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - key: The key name.
    /// - Returns: The stored data, or `nil` if not found or the read fails.
    static func load(account: String, key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account).\(key)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("Keychain read succeeded - account: \(account), key: \(key)")
            }
            return data
        } else if status == errSecItemNotFound {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("Keychain item not found - account: \(account), key: \(key)")
            }
            return nil
        } else {
            AppLog.common.error("Keychain read failed - account: \(account), key: \(key), status: \(status)")
            return nil
        }
    }

    /// Deletes a single item from the Keychain.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - key: The key name.
    /// - Returns: `true` if the deletion succeeded or the item did not exist.
    static func delete(account: String, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account).\(key)",
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            AppLog.common.debug("Keychain delete succeeded - account: \(account), key: \(key)")
            return true
        }
        if status == errSecItemNotFound {
            return true
        }

        AppLog.common.error("Keychain delete failed - account: \(account), key: \(key), status: \(status)")
        return false
    }
}
