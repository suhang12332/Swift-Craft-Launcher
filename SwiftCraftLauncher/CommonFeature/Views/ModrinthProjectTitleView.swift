//
//  ModrinthProjectTitleView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import SwiftUI

// MARK: - Modrinth Project Title View
/// 通用的项目标题卡片组件，用于展示 Modrinth 项目详情
/// 适用于 Modrinth 资源、服务器信息等场景
struct ModrinthProjectTitleView: View {
    // MARK: - Properties
    let title: String
    let description: String
    let icon: ProjectIcon
    let infoItems: [InfoItem]
    let tags: [String]

    // MARK: - Types
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

    // MARK: - Initialization
    init(
        title: String,
        description: String,
        icon: ProjectIcon,
        infoItems: [InfoItem],
        tags: [String] = []
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.infoItems = infoItems
        self.tags = tags
    }

    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 项目图标
            iconView

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 项目名称
                    Text(title)
                        .font(.headline)
                    Spacer()
                    // 信息行（地址、玩家数量等）
                    infoRowView
                }

                // 项目描述
                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // 标签
                if !tags.isEmpty {
                    tagsView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - View Components
    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .favicon(let base64):
            if let base64 = base64,
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

        case .asyncImage(let url):
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 64, height: 64)
                .cornerRadius(8)
            } else {
                defaultIcon(systemName: "server.rack")
            }

        case .systemImage(let name):
            defaultIcon(systemName: name)
        }
    }

    private func defaultIcon(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: systemName)
                    .foregroundColor(.secondary)
            )
    }

    private var infoRowView: some View {
        HStack {
            ForEach(Array(infoItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().frame(height: 12)
                }
                Label(item.text, systemImage: item.systemImage)
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

// MARK: - Convenience Initializers
extension ModrinthProjectTitleView {
    /// 从 MinecraftServerInfo 创建项目标题卡片（用于本地服务器）
    init(
        serverName: String,
        serverAddress: String,
        serverPort: Int?,
        serverInfo: MinecraftServerInfo
    ) {
        self.title = serverName
        self.description = serverInfo.description.plainText
        self.icon = .favicon(base64: serverInfo.favicon)

        var items: [InfoItem] = [
            InfoItem(
                text: serverPort.flatMap { $0 > 0 ? "\(serverAddress):\($0)" : nil } ?? serverAddress,
                systemImage: "server.rack"
            )
        ]

        if let players = serverInfo.players {
            items.append(InfoItem(
                text: "\(players.online) / \(players.max)",
                systemImage: "person.2",
            ))
        }

        self.infoItems = items

        if let version = serverInfo.version {
            self.tags = [version.name]
        } else {
            self.tags = []
        }
    }

    /// 从 ModrinthProjectDetail 创建项目标题卡片（用于 Modrinth 项目）
    init(projectDetail: ModrinthProjectDetail) {
        self.title = projectDetail.title
        self.description = projectDetail.description
        self.icon = .asyncImage(url: projectDetail.iconUrl.flatMap { URL(string: $0) })

        if let serverInfo = projectDetail.fileName, !serverInfo.isEmpty {
            let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: serverInfo)
            var items: [InfoItem] = [
                InfoItem(text: parsed.address, systemImage: "server.rack")
            ]
            if let playersText = parsed.playersText, !playersText.isEmpty {
                items.append(InfoItem(text: playersText, systemImage: "person.2"))
            }
            self.infoItems = items
        } else {
            self.infoItems = [
                InfoItem(text: "\(projectDetail.downloads)", systemImage: "arrow.down.circle"),
                InfoItem(text: "\(projectDetail.followers)", systemImage: "heart")
            ]
        }

        self.tags = projectDetail.categories
    }
}
