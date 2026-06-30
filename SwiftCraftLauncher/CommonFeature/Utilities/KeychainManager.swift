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
    /// - Parameters:
    ///   - data: The data to store.
    ///   - account: The account identifier.
    ///   - key: The key name.
    /// - Returns: `true` if the operation succeeded.
    static func save(data: Data, account: String, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account).\(key)",
            kSecValueData as String: data,
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.shared.debug("Keychain 保存成功 - account: \(account), key: \(key)")
            return true
        } else {
            Logger.shared.error("Keychain 保存失败 - account: \(account), key: \(key), status: \(status)")
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
                Logger.shared.debug("Keychain 读取成功 - account: \(account), key: \(key)")
            }
            return data
        } else if status == errSecItemNotFound {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                Logger.shared.debug("Keychain 项不存在 - account: \(account), key: \(key)")
            }
            return nil
        } else {
            Logger.shared.error("Keychain 读取失败 - account: \(account), key: \(key), status: \(status)")
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

        if status == errSecSuccess || status == errSecItemNotFound {
            Logger.shared.debug("Keychain 删除成功 - account: \(account), key: \(key)")
            return true
        } else {
            Logger.shared.error("Keychain 删除失败 - account: \(account), key: \(key), status: \(status)")
            return false
        }
    }

    /// Deletes all Keychain items for the specified account.
    /// Queries all items and removes those whose account attribute starts with the given prefix.
    /// - Parameter account: The account identifier.
    /// - Returns: `true` if all deletions succeeded.
    static func deleteAll(account: String) -> Bool {
        let accountPrefix = "\(account)."
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status == errSecItemNotFound {
                Logger.shared.debug("Keychain 无数据可删 - account: \(account)")
                return true
            }
            Logger.shared.error("Keychain 查询所有数据失败 - account: \(account), status: \(status)")
            return false
        }

        var allSucceeded = true
        for item in items {
            guard let storedAccount = item[kSecAttrAccount as String] as? String,
                  storedAccount.hasPrefix(accountPrefix) else { continue }
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: storedAccount,
            ]
            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
                Logger.shared.error("Keychain 删除单项失败 - account: \(storedAccount), status: \(deleteStatus)")
                allSucceeded = false
            }
        }

        if allSucceeded {
            Logger.shared.debug("Keychain 删除所有数据成功 - account: \(account)")
        }
        return allSucceeded
    }
}
