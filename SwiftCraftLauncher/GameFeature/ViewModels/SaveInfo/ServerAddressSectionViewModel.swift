//
//  ServerAddressSectionViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// View model that manages server connection status checks and visibility computation for a list of server addresses.
@Observable
final class ServerAddressSectionViewModel: @unchecked Sendable {
    var serverStatuses: [String: ServerConnectionStatus] = [:]
    var serverInfos: [String: MinecraftServerInfo] = [:]

    /// Splits servers into visible and overflow items based on the configured maximum.
    func computeVisibleAndOverflowItems(
        from servers: [ServerAddress],
    ) -> ([ServerAddress], [ServerAddress]) {
        let maxItems = ServerAddressSectionConstants.maxItems
        let visibleItems = Array(servers.prefix(maxItems))
        let overflowItems = Array(servers.dropFirst(maxItems))
        return (visibleItems, overflowItems)
    }

    /// Checks connection status for all provided servers concurrently.
    func checkAllServers(for servers: [ServerAddress]) {
        guard !servers.isEmpty else { return }
        Task {
            await withTaskGroup(of: (String, ServerConnectionStatus, MinecraftServerInfo?).self) { group in
                for server in servers {
                    group.addTask {
                        let status = await NetworkUtils.checkServerConnectionStatus(
                            address: server.address,
                            port: server.port,
                            timeout: 5.0,
                        )
                        if case let .success(info) = status {
                            return (server.id, status, info)
                        }
                        return (server.id, status, nil)
                    }
                }

                for await (serverId, status, serverInfo) in group {
                    await MainActor.run {
                        self.serverStatuses[serverId] = status
                        if case .success = status {
                            if let info = serverInfo {
                                self.serverInfos[serverId] = info
                            }
                        } else {
                            self.serverInfos.removeValue(forKey: serverId)
                        }
                    }
                }
            }
        }
    }
}
