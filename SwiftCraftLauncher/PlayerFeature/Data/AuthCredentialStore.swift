import Foundation

/// 认证凭据存储管理器
/// 使用 Keychain 安全存储认证凭据
class AuthCredentialStore {
    // MARK: - Public Methods

    /// 保存认证凭据
    /// - Parameter credential: 要保存的认证凭据
    /// - Returns: 是否保存成功
    func saveCredential(_ credential: AuthCredential) -> Bool {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(credential)
            return KeychainManager.save(data: data, account: credential.userId, key: "authCredential")
        } catch {
            Logger.shared.error("编码认证凭据失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 加载认证凭据
    /// - Parameter userId: 用户ID
    /// - Returns: 认证凭据，如果不存在或加载失败则返回 nil
    func loadCredential(userId: String) -> AuthCredential? {
        guard let data = KeychainManager.load(account: userId, key: "authCredential") else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AuthCredential.self, from: data)
        } catch {
            Logger.shared.error("解码认证凭据失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 删除认证凭据
    /// - Parameter userId: 用户ID
    /// - Returns: 是否删除成功
    func deleteCredential(userId: String) -> Bool {
        return KeychainManager.delete(account: userId, key: "authCredential")
    }

    /// 删除用户的所有认证凭据
    /// - Parameter userId: 用户ID
    /// - Returns: 是否删除成功
    func deleteAllCredentials(userId: String) -> Bool {
        return KeychainManager.deleteAll(account: userId)
    }

    /// 更新认证凭据
    /// - Parameter credential: 更新后的认证凭据
    /// - Returns: 是否更新成功
    func updateCredential(_ credential: AuthCredential) -> Bool {
        return saveCredential(credential)
    }
}
