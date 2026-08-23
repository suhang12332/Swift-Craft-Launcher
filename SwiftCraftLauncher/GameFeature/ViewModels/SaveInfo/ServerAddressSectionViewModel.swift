//
//  ServerAddressSectionViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftServerPingKit
import Observation

/// View model that manages server connection status checks and visibility computation for a list of server addresses.
@MainActor
@Observable
final class ServerAddressSectionViewModel {
    private static let cacheDuration: TimeInterval = 30

    var serverStatuses: [String: ServerConnectionStatus] = [:]
    var serverInfos: [String: MinecraftServerInfo] = [:]

    private var checkTask: Task<Void, Never>?
    private var activeCheckID = UUID()
    private var cachedResults: [String: CachedServerResult] = [:]

    private struct CachedServerResult {
        let address: String
        let port: Int
        let status: ServerConnectionStatus
        let serverInfo: MinecraftServerInfo?
        let date: Date
    }

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
        cancelChecks()
        let checkID = UUID()
        activeCheckID = checkID

        let serverIDs = Set(servers.map(\ .id))
        cachedResults = cachedResults.filter { serverIDs.contains($0.key) }
        serverStatuses = serverStatuses.filter { serverIDs.contains($0.key) }
        serverInfos = serverInfos.filter { serverIDs.contains($0.key) }

        let now = Date()
        var pendingServers: [ServerAddress] = []
        for server in servers {
            if let cachedResult = cachedResults[server.id],
               cachedResult.address == server.address,
               cachedResult.port == server.port,
               now.timeIntervalSince(cachedResult.date) < Self.cacheDuration {
                serverStatuses[server.id] = cachedResult.status
                if let serverInfo = cachedResult.serverInfo {
                    serverInfos[server.id] = serverInfo
                } else {
                    serverInfos.removeValue(forKey: server.id)
                }
            } else {
                serverStatuses[server.id] = .checking
                serverInfos.removeValue(forKey: server.id)
                pendingServers.append(server)
            }
        }

        guard !pendingServers.isEmpty else {
            checkTask = nil
            return
        }

        let pendingServerByID = Dictionary(uniqueKeysWithValues: pendingServers.map { ($0.id, $0) })
        checkTask = Task { [weak self] in
            await withTaskGroup(of: (String, ServerConnectionStatus, MinecraftServerInfo?).self) { group in
                for server in pendingServers {
                    group.addTask {
                        guard !Task.isCancelled else {
                            return (server.id, .failed, nil)
                        }
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
                    guard !Task.isCancelled else { return }
                    guard let self, self.activeCheckID == checkID else { return }
                    self.serverStatuses[serverId] = status
                    if let serverInfo {
                        self.serverInfos[serverId] = serverInfo
                    } else {
                        self.serverInfos.removeValue(forKey: serverId)
                    }
                    guard let server = pendingServerByID[serverId] else { return }
                    self.cachedResults[serverId] = CachedServerResult(
                        address: server.address,
                        port: server.port,
                        status: status,
                        serverInfo: serverInfo,
                        date: Date(),
                    )
                }
            }

            guard let self, activeCheckID == checkID else { return }
            checkTask = nil
        }
    }

    /// Cancels the active server checks without clearing cached results.
    func cancelChecks() {
        checkTask?.cancel()
        checkTask = nil
        activeCheckID = UUID()
    }
}
