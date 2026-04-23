//
//  ModrinthCompatibilityView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import Foundation
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let maxVisibleVersions = 15
    static let popoverWidth: CGFloat = 300
    static let popoverHeight: CGFloat = 400
}

// MARK: - Compatibility Section
struct ModrinthCompatibilitySection: View {
    let project: ModrinthProjectDetail?
    let isLoading: Bool
    let resourceType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                GameVersionsSection(versions: [], isLoading: true)
                LoadersSection(loaders: [], isLoading: true)
            } else if let project = project {
                if !project.gameVersions.isEmpty {
                    GameVersionsSection(versions: project.gameVersions, isLoading: false)
                }
                if !project.loaders.isEmpty {
                    LoadersSection(loaders: project.loaders, isLoading: false)
                }
                if resourceType == ProjectType.minecraftJavaServer,
                   let fileName = project.fileName {
                    ServerInfoSection(fileName: fileName)
                    PlayerInfoSection(fileName: fileName)
                }
                if resourceType != ProjectType.minecraftJavaServer {
                    PlatformSupportSection(
                        clientSide: project.clientSide,
                        serverSide: project.serverSide
                    )
                }
            }
        }
    }
}

// MARK: - Game Versions Section
private struct GameVersionsSection: View {
    let versions: [String]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "game.version",
            items: versions.map { IdentifiableString(id: $0) },
            isLoading: isLoading,
            maxItems: Constants.maxVisibleVersions
        ) { item in
            VersionTag(version: item.id)
        } overflowContentBuilder: { _ in
            AnyView(
                GameVersionsPopover(versions: versions)
            )
        }
    }
}

// MARK: - Game Versions Popover
private struct GameVersionsPopover: View {
    let versions: [String]

    var body: some View {
        VersionGroupedView(
            items: versions.map { FilterItem(id: $0, name: $0) },
            selectedItems: .constant([])
        ) { _ in }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }
}

// MARK: - Version Tag
private struct VersionTag: View {
    let version: String

    var body: some View {
        FilterChip(
            title: version,
            isSelected: false
        ) {}
    }
}

// MARK: - Loaders Section
private struct LoadersSection: View {
    let loaders: [String]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "project.info.platforms",
            items: loaders.map { IdentifiableString(id: $0) },
            isLoading: isLoading
        ) { item in
            VersionTag(version: item.id)
        }
    }
}

// MARK: - Server Info Section
private struct ServerInfoSection: View {
    let fileName: String
    @State private var connectionStatus: ServerConnectionStatus = .unknown

    var body: some View {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: fileName)
        let displayAddress = parsed.address
        let items = displayAddress.isEmpty ? [] : [IdentifiableString(id: displayAddress)]

        GenericSectionView(
            title: "project.info.server",
            items: items,
            isLoading: false
        ) { item in
            FilterChip(
                title: item.id,
                isSelected: false,
                action: {},
                iconName: "server.rack",
                iconColor: connectionStatus.statusColor
            )
            .frame(maxWidth: 160, alignment: .leading)
            .lineLimit(1)
        }
        .task(id: displayAddress) {
            await CommonUtil.updateServerConnectionStatus(
                for: displayAddress
            ) { newStatus in
                connectionStatus = newStatus
            }
        }
    }
}

// MARK: - Player Info Section
private struct PlayerInfoSection: View {
    let fileName: String

    var body: some View {
        let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: fileName)
        let items: [IdentifiableString] = {
            guard let playersText = parsed.playersText, !playersText.isEmpty else {
                return []
            }
            return [IdentifiableString(id: playersText)]
        }()

        return GenericSectionView(
            title: "project.info.players",
            items: items,
            isLoading: false
        ) { item in
            FilterChip(
                title: item.id,
                isSelected: false,
                action: {},
                iconName: "person.2",
                iconColor: .secondary
            )
        }
    }
}

// MARK: - Platform Support Section
private struct PlatformSupportSection: View {
    let clientSide: String
    let serverSide: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\("platform.support".localized()):")
                .font(.headline)
                .padding(.bottom, SectionViewConstants.defaultHeaderBottomPadding)

            ContentWithOverflow(
                items: [
                    IdentifiablePlatformItem(id: "client", icon: "laptopcomputer", text: "platform.client.\(clientSide)".localized()),
                    IdentifiablePlatformItem(id: "server", icon: "server.rack", text: "platform.server.\(serverSide)".localized()),
                ],
                maxHeight: SectionViewConstants.defaultMaxHeight,
                verticalPadding: SectionViewConstants.defaultVerticalPadding
            ) { item in
                PlatformSupportItem(icon: item.icon, text: item.text)
            }
        }
    }
}

// MARK: - Platform Item Models
private struct IdentifiablePlatformItem: Identifiable {
    let id: String
    let icon: String
    let text: String
}

// MARK: - Platform Support Item
private struct PlatformSupportItem: View {
    let icon: String
    let text: String

    var body: some View {
        FilterChip(
            title: text,
            isSelected: false,
            action: {},
            iconName: icon,
            iconColor: .secondary
        )
    }
}
