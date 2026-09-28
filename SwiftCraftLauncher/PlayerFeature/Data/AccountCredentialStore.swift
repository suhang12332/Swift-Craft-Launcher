//
//  AccountCredentialStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Security

/// 统一账号凭据的系统钥匙串存储。
///
/// - 索引采用 `{authMethod}.{userId}` 复合键,隔离不同认证方式的凭据,
///   防止恶意认证服务器签发撞车 UUID 时覆写其他方式的凭据。
/// - 安全属性为 `WhenUnlockedThisDeviceOnly`:锁屏不可读、不随 iCloud
///   钥匙串同步、不随明文设备备份扩散。
final class AccountCredentialStore {
    private var key: String { AppConstants.KeychainKeys.accountCredential }

    /// 保存凭据,同账号重复保存为覆盖写。
    func save(_ credential: AccountCredential) -> Bool {
        do {
            let data = try JSONEncoder().encode(credential)
            return KeychainManager.save(
                data: data,
                account: credential.keychainAccount,
                key: key,
                accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            )
        } catch {
            AppLog.player.error("Failed to encode account credential: \(error.localizedDescription)")
            return false
        }
    }

    /// 按认证方式读取凭据。
    func load(userId: String, authMethod: AccountAuthMethod) -> AccountCredential? {
        let account = AccountCredential.keychainAccount(userId: userId, authMethod: authMethod)
        guard let data = KeychainManager.load(account: account, key: key) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(AccountCredential.self, from: data)
        } catch {
            AppLog.player.error("Failed to decode account credential: \(error.localizedDescription)")
            return nil
        }
    }

    /// 认证方式未知的兜底读取:逐个方式尝试(仅迁移与过渡路径使用)。
    func loadAny(userId: String) -> AccountCredential? {
        for authMethod in AccountAuthMethod.allCases {
            if let credential = load(userId: userId, authMethod: authMethod) {
                return credential
            }
        }
        return nil
    }

    /// 删除凭据,条目不存在时同样视为成功。
    func delete(userId: String, authMethod: AccountAuthMethod) -> Bool {
        let account = AccountCredential.keychainAccount(userId: userId, authMethod: authMethod)
        return KeychainManager.delete(account: account, key: key)
    }

    /// 删除某账号所有认证方式的凭据(删除玩家时的兜底清理)。
    func deleteAll(userId: String) {
        for authMethod in AccountAuthMethod.allCases {
            _ = delete(userId: userId, authMethod: authMethod)
        }
    }
}
