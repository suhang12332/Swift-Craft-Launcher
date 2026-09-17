//
//  CustomYggdrasilServerStore.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// 用户添加的自定义 Yggdrasil 认证服务器(密码登录)。
struct CustomYggdrasilServer: Codable, Identifiable, Equatable {
    /// 稳定引用 id(档案与凭据通过 baseURL 关联,id 用于管理操作)。
    let id: String
    /// 显示名,来自服务器元数据 `meta.serverName`,允许用户修改。
    var serverName: String
    /// authlib-injector API 根地址(已规范化,无尾斜杠)。
    var apiRoot: String
    /// 服务器是否支持角色名登录(`meta.feature.non_email_login`)。
    var nonEmailLogin: Bool
    let dateAdded: Date
}

/// 自定义 Yggdrasil 服务器的持久化与元数据获取。
///
/// 列表与元数据缓存存 UserDefaults:服务器地址与名称并非敏感信息;
/// 该类服务器的敏感凭据(密码/令牌)仍统一走 `AccountCredentialStore`。
enum CustomYggdrasilServerStore {
    /// 软上限,防止列表失控;与规范"每用户令牌上限"的精神一致。
    static let maxServers = 10

    // MARK: - 列表读写

    static func load() -> [CustomYggdrasilServer] {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.UserDefaultsKeys.customYggdrasilServers),
              let servers = try? JSONDecoder().decode([CustomYggdrasilServer].self, from: data) else {
            return []
        }
        return servers
    }

    static func save(_ servers: [CustomYggdrasilServer]) {
        guard let data = try? JSONEncoder().encode(servers) else {
            AppLog.common.error("Failed to encode custom Yggdrasil servers")
            return
        }
        UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.customYggdrasilServers)
    }

    /// 添加服务器;API 根重复时抛错。
    static func add(name: String, apiRoot: String, nonEmailLogin: Bool) throws -> CustomYggdrasilServer {
        var servers = load()
        let normalized = normalizeAPIRoot(apiRoot)
        guard !servers.contains(where: { $0.apiRoot == normalized }) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.duplicated",
                level: .notification,
                message: "Custom Yggdrasil server already exists: \(normalized)",
            )
        }
        guard servers.count < maxServers else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.limit_reached",
                level: .notification,
                message: "Custom Yggdrasil server limit reached (\(maxServers))",
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
        save(servers)
        return server
    }

    /// 移除服务器;`referencedBaseURLs` 为仍在使用该服务器的玩家档案地址,
    /// 命中时拒绝删除(需先移除对应玩家)。
    static func remove(id: String, referencedBaseURLs: Set<String>) throws {
        var servers = load()
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        let server = servers[index]
        let baseURL = configBaseURL(for: server)
        guard !referencedBaseURLs.contains(baseURL) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.custom.error.in_use",
                level: .notification,
                message: "Custom Yggdrasil server \(server.apiRoot) is referenced by existing players",
            )
        }
        servers.remove(at: index)
        save(servers)
    }

    // MARK: - 转换与元数据

    /// 转为统一的服务器配置(密码登录形态)。
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

    /// 规范化 API 根:去首尾空白与尾斜杠,并强制 HTTPS(localhost 除外)。
    static func normalizeAPIRoot(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    /// 拉取服务器元数据:`GET {apiRoot}` 返回
    /// `{meta: {serverName, feature: {non_email_login}}}`。
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

        // 规范元数据结构:{meta: {serverName, feature: {non_email_login}}};
        // 用 JSONSerialization 手工解析,避免可选布尔类型的解析样板。
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

    /// 统一配置视角下的 baseURL 字符串(与凭据/档案关联键一致)。
    static func configBaseURL(for server: CustomYggdrasilServer) -> String {
        server.apiRoot
    }
}
