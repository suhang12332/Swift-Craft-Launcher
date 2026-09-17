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

/// 自定义 Yggdrasil 服务器的可观察存储。
///
/// `servers` 是 SwiftUI 可观察的唯一事实来源:增删会立即刷新所有引用
/// 该列表的视图(如添加账户标题栏的服务器菜单)。持久化走 UserDefaults
/// (地址与名称并非敏感信息;此类服务器的凭据仍统一走 `AccountCredentialStore`)。
@Observable
final class CustomYggdrasilServerStore {
    /// 与规范"每用户令牌上限"精神一致的软上限,防止列表失控。
    static let maxServers = 10

    /// 当前自定义服务器列表(按添加时间有序)。
    private(set) var servers: [CustomYggdrasilServer]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        servers = Self.loadPersistedServers(from: defaults)
    }

    // MARK: - 增删(同时写盘并更新可观察列表)

    /// 添加服务器;API 根重复或超出上限时抛错。
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

    /// 移除服务器;`referencedBaseURLs` 为仍在使用该服务器的玩家档案地址,
    /// 命中时拒绝删除(需先移除对应玩家)。
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

    // MARK: - 静态无状态工具

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

    /// 规范化 API 根:去首尾空白与尾斜杠。
    static func normalizeAPIRoot(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    /// 统一配置视角下的 baseURL 字符串(与凭据/档案关联键一致)。
    static func configBaseURL(for server: CustomYggdrasilServer) -> String {
        server.apiRoot
    }

    // MARK: - 持久化

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
