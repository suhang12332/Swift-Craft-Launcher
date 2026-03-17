import Foundation

final class ServerAddressSectionViewModel: ObservableObject {
    @Published var serverStatuses: [String: ServerConnectionStatus] = [:]

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
            await withTaskGroup(of: (String, ServerConnectionStatus).self) { group in
                for server in servers {
                    group.addTask {
                        var latestStatus: ServerConnectionStatus = .unknown
                        await CommonUtil.updateServerConnectionStatus(
                            for: server.address,
                            port: server.port,
                            timeout: 5.0
                        ) { newStatus in
                            latestStatus = newStatus
                        }
                        return (server.id, latestStatus)
                    }
                }

                for await (serverId, status) in group {
                    await MainActor.run {
                        self.serverStatuses[serverId] = status
                    }
                }
            }
        }
    }
}
