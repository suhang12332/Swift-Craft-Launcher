//
//  ModrinthProjectTitleView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import SwiftUI

struct ModrinthProjectTitleView: View {
    let projectDetail: ModrinthProjectDetail

    var body: some View {
        VStack {
            HStack {
                // 项目图标
                if let iconUrl = projectDetail.iconUrl,
                    let url = URL(string: iconUrl) {
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "cube.box")
                                .foregroundColor(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(projectDetail.title)
                            .font(.headline)
                        Spacer()
                        infoRow
                    }
                    Text(projectDetail.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    // 项目标签
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(projectDetail.categories, id: \.self) { category in
                                Text(category)
                                    .font(.caption2)
                                    .padding(
                                        .horizontal,
                                        ModrinthConstants.UIConstants
                                            .tagHorizontalPadding
                                    )
                                    .padding(
                                        .vertical,
                                        ModrinthConstants.UIConstants.tagVerticalPadding
                                    )
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(
                                        ModrinthConstants.UIConstants.tagCornerRadius
                                    )
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .cornerRadius(12)
    }

    private var infoRow: some View {
        Group {
            if let serverInfo = projectDetail.fileName, !serverInfo.isEmpty {
                let parsed = CommonUtil.parseMinecraftJavaServerInfo(from: serverInfo)
                let items: [(String, String)] = [
                    ("\(parsed.address)", "server.rack"),
                ] + (parsed.playersText.flatMap { $0.isEmpty ? nil : [("\($0)", "person.2")] } ?? [])
                InfoRow(items: items)
            } else {
                InfoRow(items: [
                    ("\(projectDetail.downloads)", "arrow.down.circle"),
                    ("\(projectDetail.followers)", "heart"),
                ])
            }
        }
    }
}

private struct InfoRow: View {
    let items: [(String, String)]

    var body: some View {
        HStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().frame(height: 12)
                }
                Label(item.0, systemImage: item.1)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
