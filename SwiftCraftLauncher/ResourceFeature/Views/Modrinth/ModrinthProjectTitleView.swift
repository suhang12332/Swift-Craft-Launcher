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
    let style: Style

    enum Style {
        case standard
        case detail
    }

    enum ProjectIcon {
        case asyncImage(url: URL?)
        case systemImage(name: String)
    }

    struct InfoItem: Identifiable {
        let id = UUID()
        let text: String
    }

    init(
        title: String,
        description: String,
        icon: ProjectIcon,
        infoItems: [InfoItem],
        tags: [String] = [],
        style: Style = .standard,
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.infoItems = infoItems
        self.tags = tags
        self.style = style
    }

    private var iconSize: CGFloat {
        style == .detail ? 64 : ModrinthConstants.UIConstants.iconSize
    }

    private var titleFont: Font {
        style == .detail ? .largeTitle.bold() : .headline
    }

    var body: some View {
        ModrinthDetailCardLayout(
            icon: { iconView },
            title: {
                Text(title)
                    .font(titleFont)
                    .lineLimit(1)
            },
            description: {
                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(ModrinthConstants.UIConstants.descriptionLineLimit)
                }
            },
            tags: {
                tagsView
            },
            trailing: {
                EmptyView()
            },
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
                        ModrinthDetailCardPlaceholderIcon(
                            sfSymbol: "questionmark.circle",
                            size: iconSize,
                        )
                    default:
                        ModrinthDetailCardPlaceholderIcon(size: iconSize)
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
                }
                .frame(width: iconSize, height: iconSize)
                .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
                .clipped()
            } else {
                ModrinthDetailCardPlaceholderIcon(
                    sfSymbol: "tv.badge.wifi",
                    size: iconSize,
                )
            }

        case let .systemImage(name):
            ModrinthDetailCardPlaceholderIcon(sfSymbol: name, size: iconSize)
        }
    }

    private var tagsView: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(infoItems) { item in
                ModrinthDetailCardTagView(text: item.text)
            }
            ModrinthTagsView(
                tags: tags,
                maxTags: max(0, ModrinthConstants.UIConstants.maxTags - infoItems.count),
            )
        }
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
            ),
        ]

        if let players = serverInfo.players {
            items.append(InfoItem(text: "\(players.online) / \(players.max)"))
        }

        infoItems = items
        style = .standard

        if let version = serverInfo.version {
            tags = [version.name]
        } else {
            tags = []
        }
    }

    /// Creates a title card from a Modrinth project detail.
    init(
        projectDetail: ModrinthProjectDetail,
        style: Style = .standard,
    ) {
        title = projectDetail.title
        description = projectDetail.description
        icon = .asyncImage(url: projectDetail.iconUrl.flatMap { URL(string: $0) })
        self.style = style

        if let serverInfo = projectDetail.fileName, !serverInfo.isEmpty {
            let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: serverInfo)
            var items: [InfoItem] = [
                InfoItem(text: parsed.address),
            ]
            if let playersText = parsed.playersText, !playersText.isEmpty {
                items.append(InfoItem(text: playersText))
            }
            infoItems = items
        } else {
            infoItems = [
                InfoItem(text: ModrinthDetailCardView.formatNumber(projectDetail.downloads)),
                InfoItem(text: ModrinthDetailCardView.formatNumber(projectDetail.followers)),
            ]
        }

        tags = projectDetail.categories
    }
}
