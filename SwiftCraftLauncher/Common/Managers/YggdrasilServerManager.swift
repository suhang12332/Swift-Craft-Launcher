import Foundation
import SwiftUI

/// Yggdrasil 三方登录服务器管理器
/// 负责存储、加载和管理三方登录服务器配置
class YggdrasilServerManager: ObservableObject {
    static let shared = YggdrasilServerManager()
    
    @Published private(set) var servers: [YggdrasilServerConfig] = []
    
    private let userDefaultsKey = "yggdrasilServers"
    
    private init() {
        loadServers()
    }
    
    // MARK: - Public Methods
    
    /// 加载所有服务器配置
    func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            servers = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            servers = try decoder.decode([YggdrasilServerConfig].self, from: data)
            Logger.shared.debug("已加载 \(servers.count) 个 Yggdrasil 服务器配置")
        } catch {
            Logger.shared.error("加载 Yggdrasil 服务器配置失败: \(error.localizedDescription)")
            servers = []
        }
    }
    
    /// 保存所有服务器配置
    private func saveServers() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(servers)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            Logger.shared.debug("已保存 \(servers.count) 个 Yggdrasil 服务器配置")
        } catch {
            Logger.shared.error("保存 Yggdrasil 服务器配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 添加服务器配置
    /// - Parameter server: 服务器配置
    /// - Returns: 是否添加成功
    func addServer(_ server: YggdrasilServerConfig) -> Bool {
        // 检查是否已存在相同 baseURL 的服务器
        if servers.contains(where: { $0.baseURL == server.baseURL }) {
            Logger.shared.warning("服务器已存在: \(server.baseURL)")
            return false
        }
        
        servers.append(server)
        saveServers()
        objectWillChange.send()
        return true
    }
    
    /// 更新服务器配置
    /// - Parameters:
    ///   - oldServer: 旧的服务器配置
    ///   - newServer: 新的服务器配置
    /// - Returns: 是否更新成功
    func updateServer(oldServer: YggdrasilServerConfig, newServer: YggdrasilServerConfig) -> Bool {
        guard let index = servers.firstIndex(where: { $0.baseURL == oldServer.baseURL }) else {
            Logger.shared.warning("未找到要更新的服务器: \(oldServer.baseURL)")
            return false
        }
        
        // 如果 baseURL 改变，检查新 URL 是否已存在
        if oldServer.baseURL != newServer.baseURL {
            if servers.contains(where: { $0.baseURL == newServer.baseURL }) {
                Logger.shared.warning("新服务器 URL 已存在: \(newServer.baseURL)")
                return false
            }
        }
        
        servers[index] = newServer
        saveServers()
        objectWillChange.send()
        return true
    }
    
    /// 删除服务器配置
    /// - Parameter server: 要删除的服务器配置
    /// - Returns: 是否删除成功
    func deleteServer(_ server: YggdrasilServerConfig) -> Bool {
        guard let index = servers.firstIndex(where: { $0.baseURL == server.baseURL }) else {
            Logger.shared.warning("未找到要删除的服务器: \(server.baseURL)")
            return false
        }
        
        servers.remove(at: index)
        saveServers()
        objectWillChange.send()
        return true
    }
    
    /// 根据 baseURL 获取服务器配置
    /// - Parameter baseURL: 服务器基础 URL
    /// - Returns: 服务器配置，如果不存在则返回 nil
    func getServer(baseURL: String) -> YggdrasilServerConfig? {
        return servers.first { $0.baseURL == baseURL }
    }
}

