import Foundation

final class ServerAddressSectionViewModel: ObservableObject {
    @Published var serverStatuses: [String: ServerConnectionStatus] = [:]
    @Published var serverInfos: [String: MinecraftServerInfo] = [:]

    /// 计算可见与溢出的服务器列表
    func computeVisibleAndOverflowItems(
        from servers: [ServerAddress]
    ) -> ([ServerAddress], [ServerAddress]) {
        let maxItems = ServerAddressSectionConstants.maxItems
        let visibleItems = Array(servers.prefix(maxItems))
        let overflowItems = Array(servers.dropFirst(maxItems))
        return (visibleItems, overflowItems)
    }

    /// 并发检测所有服务器的连接状态
    func checkAllServers(for servers: [ServerAddress]) {
        guard !servers.isEmpty else { return }
        Task {
            await withTaskGroup(of: (String, ServerConnectionStatus, MinecraftServerInfo?).self) { group in
                for server in servers {
                    group.addTask {
                        var latestStatus: ServerConnectionStatus = .unknown
                        var serverInfo: MinecraftServerInfo?
                        await CommonUtil.updateServerConnectionStatus(
                            for: server.address,
                            port: server.port,
                            timeout: 5.0
                        ) { newStatus in
                            latestStatus = newStatus
                            if case .success(let info) = newStatus {
                                serverInfo = info
                            }
                        }
                        return (server.id, latestStatus, serverInfo)
                    }
                }

                for await (serverId, status, serverInfo) in group {
                    await MainActor.run {
                        self.serverStatuses[serverId] = status
                        // 清除旧的服务器信息，除非是成功状态且有有效信息
                        if case .success = status {
                            if let info = serverInfo {
                                self.serverInfos[serverId] = info
                            }
                            // 如果 serverInfo 为 nil，保持现有服务器信息不变
                        } else {
                            self.serverInfos.removeValue(forKey: serverId)
                        }
                    }
                }
            }
        }
    }
}
