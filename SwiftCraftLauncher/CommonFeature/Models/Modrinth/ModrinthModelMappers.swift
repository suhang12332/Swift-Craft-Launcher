//
//  ModrinthModelMappers.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

public extension ModrinthProjectDetail {
    /// Creates a `ModrinthProjectDetail` from the V3 API response format.
    static func fromV3(_ v3: ModrinthProjectDetailV3) -> ModrinthProjectDetail {
        let serverInfo = v3.minecraftJavaServer
        let address = serverInfo?.address ?? ""
        let online = serverInfo?.ping?.data?.playersOnline
        let max = serverInfo?.ping?.data?.playersMax

        let fileName: String? = {
            guard !address.isEmpty else { return nil }
            if let online, let max {
                return "\(address) | \(online) | \(max)"
            } else if let online {
                return "\(address) | \(online)"
            } else {
                return address
            }
        }()

        return ModrinthProjectDetail(
            slug: v3.slug,
            title: v3.name,
            description: v3.summary,
            categories: v3.categories,
            clientSide: "required",
            serverSide: "required",
            body: v3.description,
            additionalCategories: v3.additionalCategories,
            issuesUrl: v3.linkUrls?.wiki?.url,
            sourceUrl: nil,
            wikiUrl: v3.linkUrls?.wiki?.url,
            discordUrl: v3.linkUrls?.discord?.url,
            projectType: v3.projectTypes.first ?? "minecraft_java_server",
            downloads: v3.downloads,
            iconUrl: v3.iconUrl,
            id: v3.id,
            team: v3.organization ?? "",
            published: v3.published,
            updated: v3.updated,
            followers: v3.followers,
            license: v3.license,
            versions: v3.versions,
            gameVersions: {
                let primary = v3.gameVersions
                let fallback = v3.minecraftJavaServer?.content?.supportedGameVersions ?? []

                var seen = Set<String>()
                var merged: [String] = []
                merged.reserveCapacity(primary.count + fallback.count)

                for v in primary where seen.insert(v).inserted {
                    merged.append(v)
                }
                for v in fallback where seen.insert(v).inserted {
                    merged.append(v)
                }
                return merged
            }(),
            loaders: v3.loaders,
            type: nil,
            fileName: fileName,
        )
    }
}

extension ModrinthProjectDetail {
    /// Creates a `ModrinthProjectDetail` for a server, embedding connection-check results in existing fields.
    static func fromServer(
        _ server: ServerAddress,
        info: MinecraftServerInfo?,
        status: ServerConnectionStatus,
    ) -> ModrinthProjectDetail {
        let displayAddress: String = {
            if server.port > 0 {
                return "\(server.address):\(server.port)"
            }
            return server.address
        }()

        let motd = info?.description.plainText ?? ""

        return ModrinthProjectDetail(
            slug: server.name.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: server.name,
            description: motd.isEmpty ? displayAddress : motd,
            categories: ["server"],
            clientSide: "unknown",
            serverSide: status.statusCode,
            body: server.address,
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: ResourceType.minecraftJavaServer.rawValue,
            downloads: info?.players?.online ?? 0,
            iconUrl: info?.favicon ?? server.icon,
            id: "server_\(server.id)",
            team: "local",
            published: Date(),
            updated: Date(),
            followers: info?.players?.max ?? 0,
            license: nil,
            versions: [],
            gameVersions: [],
            loaders: [],
            type: nil,
            fileName: displayAddress,
        )
    }
}

public extension ModrinthProject {
    /// Creates a `ModrinthProject` from a detailed project response.
    static func from(detail: ModrinthProjectDetail) -> ModrinthProject {
        ModrinthProject(
            projectId: detail.id,
            projectType: detail.projectType,
            slug: detail.slug,
            author: detail.team,
            title: detail.title,
            description: detail.description,
            categories: detail.categories,
            displayCategories: detail.additionalCategories ?? [],
            versions: detail.versions,
            downloads: detail.downloads,
            follows: detail.followers,
            iconUrl: detail.iconUrl,
            license: detail.license?.name ?? "",
            clientSide: detail.clientSide,
            serverSide: detail.serverSide,
            fileName: detail.fileName,
        )
    }

    /// The color representing the server connection status.
    var statusColor: Color? {
        switch serverStatus {
        case .checking:
            return .blue.opacity(0.5)
        case .success:
            return .green
        case .timeout, .failed:
            return .red
        case .unknown, nil:
            return nil
        }
    }

    /// The online player count text, or a placeholder when the server is unreachable.
    var playersText: String {
        switch serverStatus {
        case .timeout, .failed:
            return "-- / --"
        default:
            return "\(downloads) / \(follows)"
        }
    }
}

extension ModrinthProject {
    /// The server connection status parsed from `serverSide`.
    var serverStatus: ServerConnectionStatus? {
        ServerConnectionStatus(statusCode: serverSide)
    }

    /// The `ServerAddress` reconstructed from the project, used for editing.
    var serverAddress: ServerAddress? {
        guard projectId.hasPrefix("server_") else { return nil }
        let serverId = String(projectId.dropFirst("server_".count))
        let (host, port) = CommonUtil.parseServerAddressComponents(fileName ?? "")
        return ServerAddress(
            id: serverId,
            name: title,
            address: host,
            port: port ?? 0,
        )
    }

    /// The connection information reconstructed from the project, used for editing.
    var serverInfo: MinecraftServerInfo? {
        guard let serverStatus, case .success = serverStatus else { return nil }
        let players: MinecraftServerInfo.Players? = (follows > 0 || downloads > 0)
            ? MinecraftServerInfo.Players(max: follows, online: downloads, sample: nil)
            : nil
        return MinecraftServerInfo(
            version: nil,
            players: players,
            description: MinecraftServerInfo.Description(
                text: description.isEmpty ? nil : description,
                extra: nil,
            ),
            favicon: iconUrl,
            modinfo: nil,
        )
    }
}
