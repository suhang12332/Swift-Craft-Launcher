//
//  ServerAddressService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CryptoKit
import Foundation

/// Reads and manages Minecraft server addresses from `servers.dat` files.
@MainActor
class ServerAddressService {
    static let shared = ServerAddressService()

    private init() { }

    nonisolated func parseServerAddress(from detail: ModrinthProjectDetail) -> String {
        let rawFileName = detail.fileName ?? ""
        return CommonUtil.parseMinecraftJavaServerInfo(from: rawFileName).address
    }

    func addServerIfNeeded(
        for gameName: String,
        address: String,
        name: String,
    ) async throws {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.server.address_empty",
                level: .notification,
            )
        }

        var currentServers = try await loadServerAddresses(for: gameName)

        let exists = currentServers.contains {
            $0.address.caseInsensitiveCompare(trimmedAddress) == .orderedSame
        }
        guard !exists else {
            throw GlobalError.validation(
                i18nKey: "error.server.already_added",
                level: .notification,
            )
        }

        let serverName = name.isEmpty ? trimmedAddress : name
        let newServer = ServerAddress(
            name: serverName,
            address: trimmedAddress,
            port: 0,
            hidden: false,
            icon: nil,
            acceptTextures: false,
        )

        currentServers.append(newServer)
        try await saveServerAddresses(currentServers, for: gameName)
    }

    func loadServerAddresses(for gameName: String) async throws -> [ServerAddress] {
        let profileDir = AppPaths.profileDirectory(gameName: gameName)
        let serversDatURL = profileDir.appendingPathComponent("servers.dat")

        guard FileManager.default.fileExists(atPath: serversDatURL.path) else {
            AppLog.game.debug("servers.dat file does not exist: \(serversDatURL.path)")
            return []
        }
        AppLog.game.debug("Starting to read servers.dat: \(serversDatURL.path)")
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: serversDatURL)
            }.value
            AppLog.game.debug("servers.dat file size: \(data.count) bytes")
            let servers = try parseServersDat(data: data)
            AppLog.game.debug("Successfully parsed \(servers.count) servers")
            return servers
        } catch {
            AppLog.game.error("Failed to parse servers.dat file: \(error.localizedDescription)")
            return []
        }
    }

    private func parseServersDat(data: Data) throws -> [ServerAddress] {
        let parser = NBTParser(data: data)
        let nbtData = try parser.parse()

        AppLog.game.debug("NBT parsing complete, root tag keys: \(nbtData.keys.joined(separator: ", "))")

        guard let serversList = nbtData["servers"] as? [[String: Any]] else {
            AppLog.game.debug("servers list not found, or type mismatch")
            return []
        }

        AppLog.game.debug("Found \(serversList.count) server entries")

        var servers: [ServerAddress] = []

        for serverData in serversList {
            guard let name = serverData["name"] as? String,
                  let ip = serverData["ip"] as? String else {
                continue
            }

            let (address, port) = parseIPAndPort(ip)

            let hidden: Bool
            if let hiddenValue = serverData["hidden"] as? Int8 {
                hidden = hiddenValue != 0
            } else if let hiddenValue = serverData["hidden"] as? Int {
                hidden = hiddenValue != 0
            } else {
                hidden = false
            }

            let icon = serverData["icon"] as? String

            let acceptTextures: Bool
            if let preventsValue = serverData["preventsChatReports"] as? Int8 {
                acceptTextures = preventsValue != 0
            } else if let preventsValue = serverData["preventsChatReports"] as? Int {
                acceptTextures = preventsValue != 0
            } else {
                acceptTextures = false
            }

            let stableId = generateStableServerId(name: name, address: address, port: port)

            let server = ServerAddress(
                id: stableId,
                name: name,
                address: address,
                port: port,
                hidden: hidden,
                icon: icon,
                acceptTextures: acceptTextures,
            )

            servers.append(server)
        }

        return servers
    }

    private func parseIPAndPort(_ ipString: String) -> (String, Int) {
        let components = ipString.split(separator: ":")

        if components.count == 2,
           let port = Int(components[1]),
           port > 0 {
            return (String(components[0]), port)
        }

        return (ipString, 0)
    }

    private func generateStableServerId(name: String, address: String, port: Int) -> String {
        let content = "\(name)|\(address)|\(port)"
        guard let data = content.data(using: .utf8) else {
            return UUID().uuidString
        }

        let hash = SHA256.hash(data: data)
        var bytes = Array(hash.prefix(16))

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuid = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        return uuid.uuidString
    }

    func filterGamesWithoutExistingServer(
        detail: ModrinthProjectDetail,
        games: [GameVersionInfo],
    ) async -> [GameVersionInfo] {
        let address = parseServerAddress(from: detail)

        guard !address.isEmpty else {
            return games
        }

        let normalizedAddress = address.lowercased()
        var result: [GameVersionInfo] = []

        for game in games {
            let currentServers =
                (try? await loadServerAddresses(
                    for: game.gameName,
                )) ?? []

            let hasSameServer = currentServers.contains {
                $0.address.lowercased() == normalizedAddress
            }

            if !hasSameServer {
                result.append(game)
            }
        }
        return result
    }

    func saveServerAddresses(_ servers: [ServerAddress], for gameName: String) async throws {
        let serversDatURL = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent("servers.dat")

        AppLog.game.debug("Starting to save server address list to: \(serversDatURL.path)")

        var serversList: [[String: Any]] = []

        for server in servers {
            var serverData: [String: Any] = [:]
            serverData["name"] = server.name
            serverData["hidden"] = server.hidden ? Int8(1) : Int8(0)
            serverData["preventsChatReports"] = server.acceptTextures ? Int8(1) : Int8(0)
            if server.port > 0 {
                serverData["ip"] = "\(server.address):\(server.port)"
            } else {
                serverData["ip"] = server.address
            }

            if let icon = server.icon, !icon.isEmpty {
                serverData["icon"] = icon
            }

            serversList.append(serverData)
        }

        let nbtData: [String: Any] = [
            "servers": serversList,
        ]

        let encodedData = try NBTParser.encode(nbtData, compress: false)

        let directory = serversDatURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil,
        )

        try encodedData.write(to: serversDatURL)

        AppLog.game.debug("Successfully saved \(servers.count) server addresses to servers.dat")
    }
}
