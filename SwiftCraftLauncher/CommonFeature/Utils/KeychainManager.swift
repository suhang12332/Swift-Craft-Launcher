import Foundation
import Security

/// Keychain 管理工具类，用于安全存储敏感信息
enum KeychainManager {
    // MARK: - Constants

    private static let service = Bundle.main.identifier

    // MARK: - Public Methods

    /// 保存数据到 Keychain
    /// - Parameters:
    ///   - data: 要保存的数据
    ///   - account: 账户标识符（通常是用户ID）
    ///   - key: 键名
    /// - Returns: 是否保存成功
    static func save(data: Data, account: String, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account).\(key)",
            kSecValueData as String: data,
        ]

        // 先删除已存在的项
        SecItemDelete(query as CFDictionary)

        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.shared.debug("Keychain 保存成功 - account: \(account), key: \(key)")
            return true
        } else {
            Logger.shared.error("Keychain 保存失败 - account: \(account), key: \(key), status: \(status)")
            return false
        }
    }

    /// 从 Keychain 读取数据
    /// - Parameters:
    ///   - account: 账户标识符（通常是用户ID）
    ///   - key: 键名
    /// - Returns: 读取的数据，如果不存在或读取失败则返回 nil
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
            Logger.shared.debug("Keychain 读取成功 - account: \(account), key: \(key)")
            return data
        } else if status == errSecItemNotFound {
            Logger.shared.debug("Keychain 项不存在 - account: \(account), key: \(key)")
            return nil
        } else {
            Logger.shared.error("Keychain 读取失败 - account: \(account), key: \(key), status: \(status)")
            return nil
        }
    }

    /// 从 Keychain 删除数据
    /// - Parameters:
    ///   - account: 账户标识符（通常是用户ID）
    ///   - key: 键名
    /// - Returns: 是否删除成功
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

    /// 删除账户的所有 Keychain 数据
    /// 保存时使用 kSecAttrAccount = "\(account).\(key)"，此处需先查出该 account 前缀的所有项再逐条删除
    /// - Parameter account: 账户标识符（通常是用户ID）
    /// - Returns: 是否全部删除成功
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
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
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
