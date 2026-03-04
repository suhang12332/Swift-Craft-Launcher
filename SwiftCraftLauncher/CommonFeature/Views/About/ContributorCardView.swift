//
//  ContributorCardView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// GitHub 贡献者卡片视图
struct ContributorCardView: View {
    let contributor: GitHubContributor
    let isTopContributor: Bool
    let rank: Int
    let contributionsText: String

    var body: some View {
        Group {
            if let url = URL(string: contributor.htmlUrl) {
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
            // 头像
            ContributorAvatarView(avatarUrl: contributor.avatarUrl)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contributor.login)
                        .font(
                            .system(
                                size: 13,
                                weight: isTopContributor
                                ? .semibold : .regular
                            )
                        )
                        .foregroundColor(.primary)

                    if isTopContributor {
                        ContributorRankBadgeView(rank: rank)
                    }
                }

                HStack(spacing: 4) {
                    // 代码标签（统一标记为代码贡献者）
                    ContributionTagView(contribution: .code)

                    // 贡献次数
                    Text(contributionsText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 箭头
            Image("github-mark")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .imageScale(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
