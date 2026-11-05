//
//  ModrinthProjectTitleView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A title card view for displaying Modrinth project or server information.
struct ModrinthProjectTitleView: View {
    let title: String
    let description: String
    let icon: ProjectIcon
    let infoItems: [InfoItem]
    let tags: [String]

    enum ProjectIcon {
        case asyncImage(url: URL?)
        case systemImage(name: String)
    }

    struct InfoItem: Identifiable {
        let id = UUID()
        let text: String
        let systemImage: String

        init(text: String, systemImage: String) {
            self.text = text
            self.systemImage = systemImage
        }
    }

    init(
        title: String,
        description: String,
        icon: ProjectIcon,
        infoItems: [InfoItem],
        tags: [String] = [],
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.infoItems = infoItems
        self.tags = tags
    }

    var body: some View {
        ModrinthDetailCardLayout(
            icon: { iconView },
            title: {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            },
            description: {
                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(tags.isEmpty ? 2 : ModrinthConstants.UIConstants.descriptionLineLimit)
                }
            },
            tags: {
                if !tags.isEmpty {
                    tagsView
                }
            },
            trailing: {
                infoColumnView
            },
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var iconView: some View {
        switch icon {
        case let .asyncImage(url):
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        ModrinthDetailCardPlaceholderIcon(sfSymbol: "questionmark.circle")
                    default:
                        ModrinthDetailCardPlaceholderIcon()
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
                }
                .frame(
                    width: ModrinthConstants.UIConstants.iconSize,
                    height: ModrinthConstants.UIConstants.iconSize,
                )
                .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
                .clipped()
            } else {
                ModrinthDetailCardPlaceholderIcon(sfSymbol: "tv.badge.wifi")
            }

        case let .systemImage(name):
            ModrinthDetailCardPlaceholderIcon(sfSymbol: name)
        }
    }

    private var infoColumnView: some View {
        VStack(alignment: .trailing, spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(infoItems) { item in
                Label(item.text, systemImage: item.systemImage)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var tagsView: some View {
        ModrinthTagsView(tags: tags)
    }
}

extension ModrinthProjectTitleView {
    /// Creates a title card from server information.
    init(
        serverName: String,
        serverAddress: String,
        serverPort: Int?,
        serverInfo: MinecraftServerInfo,
    ) {
        title = serverName
        description = serverInfo.description.plainText
        icon = .asyncImage(url: CommonUtil.iconURL(from: serverInfo.favicon))

        var items: [InfoItem] = [
            InfoItem(
                text: serverPort.flatMap { $0 > 0 ? "\(serverAddress):\($0)" : nil } ?? serverAddress,
                systemImage: "tv.badge.wifi",
            ),
        ]

        if let players = serverInfo.players {
            items.append(InfoItem(
                text: "\(players.online) / \(players.max)",
                systemImage: "person.2",
            ))
        }

        infoItems = items

        if let version = serverInfo.version {
            tags = [version.name]
        } else {
            tags = []
        }
    }

    /// Creates a title card from a Modrinth project detail.
    init(projectDetail: ModrinthProjectDetail) {
        title = projectDetail.title
        description = projectDetail.description
        icon = .asyncImage(url: projectDetail.iconUrl.flatMap { URL(string: $0) })

        if let serverInfo = projectDetail.fileName, !serverInfo.isEmpty {
            let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: serverInfo)
            var items: [InfoItem] = [
                InfoItem(text: parsed.address, systemImage: "tv.badge.wifi"),
            ]
            if let playersText = parsed.playersText, !playersText.isEmpty {
                items.append(InfoItem(text: playersText, systemImage: "person.2"))
            }
            infoItems = items
        } else {
            infoItems = [
                InfoItem(
                    text: ModrinthDetailCardView.formatNumber(projectDetail.downloads),
                    systemImage: "arrow.down.circle",
                ),
                InfoItem(
                    text: ModrinthDetailCardView.formatNumber(projectDetail.followers),
                    systemImage: "star",
                ),
            ]
        }

        tags = projectDetail.categories
    }
}
