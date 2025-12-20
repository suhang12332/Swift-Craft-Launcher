//
//  StaticContributorCardView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// 静态贡献者卡片视图
struct StaticContributorCardView: View {
    let contributor: StaticContributor

    var body: some View {
        Group {
            if !contributor.url.isEmpty, let url = URL(string: contributor.url) {
                Link(destination: url) {
                    contributorContent
                }
            } else {
                contributorContent
            }
        }
    }

    private var contributorContent: some View {
        HStack(spacing: 12) {
            // 头像（emoji）
            StaticContributorAvatarView(avatar: contributor.avatar)

            // 信息部分
            VStack(alignment: .leading, spacing: 4) {
                // 用户名
                Text(contributor.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                // 贡献标签行
                HStack(spacing: 6) {
                    ForEach(contributor.contributions, id: \.self) { contribution in
                        ContributionTagView(contribution: contribution)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 显示箭头图标（如果有URL）
            if !contributor.url.isEmpty {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
