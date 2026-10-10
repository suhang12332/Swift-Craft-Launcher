//
//  CustomYggdrasilServerStore.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A user-added custom Yggdrasil authentication server (password login).
struct CustomYggdrasilServer: Codable, Identifiable, Equatable {
    /// Stable identifier for management actions (players link to servers by base URL).
    let id: String
    /// Display name, taken from `meta.serverName` and editable by the user.
    var serverName: String
    /// The authlib-injector API root (normalized, without a trailing slash).
    var apiRoot: String
    /// Whether the server accepts profile names as login (`meta.feature.non_email_login`).
    var nonEmailLogin: Bool
    let dateAdded: Date
}

/// Observable store of custom Yggdrasil servers.
///
/// `servers` is the single observable source of truth: adding or removing a server
/// immediately refreshes every view that references it (such as the server menu in
/// the add-account title bar). The list is persisted in UserDefaults because server
/// addresses and names are not sensitive.
@Observable
final class CustomYggdrasilServerStore {
    /// Soft cap that keeps the list manageable.
    static let maxServers = 10

    /// Current custom servers, ordered by the time they were added.
    private(set) var servers: [CustomYggdrasilServer]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        servers = Self.loadPersistedServers(from: defaults)
    }

    /// Adds a server; throws when the API root already exists or the limit is reached.
    @discardableResult
    func add(name: String, apiRoot: String, nonEmailLogin: Bool) throws -> CustomYggdrasilServer {
        let normalized = Self.normalizeAPIRoot(apiRoot)
        guard !servers.contains(where: { $0.apiRoot == normalized }) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.duplicated",
                level: .notification,
                message: "Custom Yggdrasil server already exists: \(normalized)",
            )
        }
        guard servers.count < Self.maxServers else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.limit_reached",
                level: .notification,
                message: "Custom Yggdrasil server limit reached (\(Self.maxServers))",
            )
        }

        let server = CustomYggdrasilServer(
            id: UUID().uuidString,
            serverName: name,
            apiRoot: normalized,
            nonEmailLogin: nonEmailLogin,
            dateAdded: Date(),
        )
        servers.append(server)
        persist()
        return server
    }

    /// Removes a server. Removal is refused when `referencedBaseURLs` contains the
    /// server, i.e. existing players still use it and must be removed first.
    func remove(id: String, referencedBaseURLs: Set<String>) throws {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        let server = servers[index]
        let baseURL = Self.configBaseURL(for: server)
        guard !referencedBaseURLs.contains(baseURL) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.in_use",
                level: .notification,
                message: "Custom Yggdrasil server \(server.apiRoot) is referenced by existing players",
            )
        }
        servers.remove(at: index)
        persist()
    }

    /// Fetches server metadata: `GET {apiRoot}` returns
    /// `{meta: {serverName, feature: {non_email_login}}}`.
    static func fetchMetadata(apiRoot: String) async throws -> (serverName: String, nonEmailLogin: Bool) {
        let normalized = normalizeAPIRoot(apiRoot)
        guard let url = URL(string: normalized) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.invalid_url",
                level: .notification,
                message: "Invalid Yggdrasil API root: \(normalized)",
            )
        }

        let data: Data
        do {
            data = try await APIClient.get(url: url, headers: [:])
        } catch {
            throw GlobalError.network(
                i18nKey: "yggdrasil.custom.error.metadata_fetch_failed",
                message: "Failed to fetch Yggdrasil server metadata from \(normalized): \(error.localizedDescription)",
            )
        }

        // Metadata shape: {meta: {serverName, feature: {non_email_login}}}. Parsed with
        // JSONSerialization to avoid boilerplate for the optional boolean feature flag.
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = object["meta"] as? [String: Any],
              let serverName = meta["serverName"] as? String, !serverName.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.metadata_invalid",
                level: .notification,
                message: "Invalid Yggdrasil server metadata from \(normalized)",
            )
        }
        let feature = meta["feature"] as? [String: Any]
        let nonEmailLogin = feature?["non_email_login"] as? Bool ?? false
        return (serverName, nonEmailLogin)
    }

    /// Converts the server into a password-login ``YggdrasilServerConfig``.
    static func toConfig(_ server: CustomYggdrasilServer) -> YggdrasilServerConfig {
        YggdrasilServerConfig(
            name: server.serverName,
            baseURL: URL(string: server.apiRoot) ?? URL(fileURLWithPath: "/"),
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "",
            tokenPath: "",
            profilePath: "",
            scope: "",
            parserId: .custom,
            token: "",
            loginMethod: .password,
            apiRoot: URL(string: server.apiRoot),
        )
    }

    /// Normalizes an API root by trimming whitespace and trailing slashes.
    static func normalizeAPIRoot(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    /// The base URL string used by ``YggdrasilServerConfig`` and stored player profiles.
    static func configBaseURL(for server: CustomYggdrasilServer) -> String {
        server.apiRoot
    }

    private static func loadPersistedServers(from defaults: UserDefaults) -> [CustomYggdrasilServer] {
        guard let data = defaults.data(forKey: AppConstants.UserDefaultsKeys.customYggdrasilServers),
              let servers = try? JSONDecoder().decode([CustomYggdrasilServer].self, from: data) else {
            return []
        }
        return servers
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(servers) else {
            AppLog.common.error("Failed to encode custom Yggdrasil servers")
            return
        }
        defaults.set(data, forKey: AppConstants.UserDefaultsKeys.customYggdrasilServers)
    }
}
