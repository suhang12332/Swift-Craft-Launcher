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
                if let iconUrl = projectDetail.iconUrl, let url = URL(string: iconUrl) {
                    ProxyAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        }
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
                        HStack {
                            Label("\(projectDetail.downloads)", systemImage: "arrow.down.circle")
                            Divider().frame(height: 12)
                            Label("\(projectDetail.followers)", systemImage: "heart")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                                    .padding(.horizontal, ModrinthConstants.UI.tagHorizontalPadding)
                                    .padding(.vertical, ModrinthConstants.UI.tagVerticalPadding)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(ModrinthConstants.UI.tagCornerRadius)

                            }
                        }
                    }
                }
                Spacer()
            }
            
        }
        .cornerRadius(12)
    }
}
