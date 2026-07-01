//
//  AuthCredentialStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages authentication credentials securely using the system Keychain.
class AuthCredentialStore {
    /// Saves a credential to the Keychain.
    ///
    /// - Parameter credential: The credential to save.
    /// - Returns: `true` if the credential was saved successfully.
    func saveCredential(_ credential: AuthCredential) -> Bool {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(credential)
            return KeychainManager.save(data: data, account: credential.userId, key: AppConstants.KeychainKeys.authCredential)
        } catch {
            AppLog.player.error("Failed to encode auth credentials: \(error.localizedDescription)")
            return false
        }
    }

    /// Loads a credential from the Keychain.
    ///
    /// - Parameter userId: The identifier for the credential.
    /// - Returns: The credential, or `nil` if none exists or loading fails.
    func loadCredential(userId: String) -> AuthCredential? {
        guard let data = KeychainManager.load(account: userId, key: AppConstants.KeychainKeys.authCredential) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AuthCredential.self, from: data)
        } catch {
            AppLog.player.error("Failed to decode auth credentials: \(error.localizedDescription)")
            return nil
        }
    }

    /// Deletes a credential from the Keychain.
    ///
    /// - Parameter userId: The identifier of the credential to delete.
    /// - Returns: `true` if the credential was deleted successfully.
    func deleteCredential(userId: String) -> Bool {
        KeychainManager.delete(account: userId, key: AppConstants.KeychainKeys.authCredential)
    }

    /// Deletes all credentials associated with the given user.
    ///
    /// - Parameter userId: The user whose credentials should be removed.
    /// - Returns: `true` if the credentials were deleted successfully.
    func deleteAllCredentials(userId: String) -> Bool {
        KeychainManager.deleteAll(account: userId)
    }

    /// Updates an existing credential in the Keychain.
    ///
    /// - Parameter credential: The updated credential.
    /// - Returns: `true` if the credential was updated successfully.
    func updateCredential(_ credential: AuthCredential) -> Bool {
        saveCredential(credential)
    }
}
