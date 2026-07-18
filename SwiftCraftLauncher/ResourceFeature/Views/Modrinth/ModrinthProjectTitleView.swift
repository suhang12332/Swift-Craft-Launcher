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
        case favicon(base64: String?)
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
        HStack(alignment: .top, spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    infoRowView
                }

                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                if !tags.isEmpty {
                    tagsView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var iconView: some View {
        switch icon {
        case let .favicon(base64):
            if let base64,
               let imageData = CommonUtil.imageDataFromBase64(base64),
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .cornerRadius(8)
            } else {
                defaultIcon(systemName: "server.rack")
            }

        case let .asyncImage(url):
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
                }
                .frame(width: 64, height: 64)
                .cornerRadius(8)
            } else {
                defaultIcon(systemName: "server.rack")
            }

        case let .systemImage(name):
            defaultIcon(systemName: name)
        }
    }

    private func defaultIcon(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: systemName)
                    .foregroundColor(.secondary),
            )
    }

    private var infoRowView: some View {
        HStack {
            ForEach(Array(infoItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().frame(height: 12)
                }
                Label(item.text, systemImage: item.systemImage)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, ModrinthConstants.UIConstants.tagHorizontalPadding)
                        .padding(.vertical, ModrinthConstants.UIConstants.tagVerticalPadding)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(ModrinthConstants.UIConstants.tagCornerRadius)
                }
            }
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
        icon = .favicon(base64: serverInfo.favicon)

        var items: [InfoItem] = [
            InfoItem(
                text: serverPort.flatMap { $0 > 0 ? "\(serverAddress):\($0)" : nil } ?? serverAddress,
                systemImage: "server.rack",
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
                InfoItem(text: parsed.address, systemImage: "server.rack"),
            ]
            if let playersText = parsed.playersText, !playersText.isEmpty {
                items.append(InfoItem(text: playersText, systemImage: "person.2"))
            }
            infoItems = items
        } else {
            infoItems = [
                InfoItem(text: "\(projectDetail.downloads)", systemImage: "arrow.down.circle"),
                InfoItem(text: "\(projectDetail.followers)", systemImage: "star"),
            ]
        }

        tags = projectDetail.categories
    }
}
