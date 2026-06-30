//
//  ContributorCardView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a GitHub contributor's information in a card layout.
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
            ContributorAvatarView(avatarUrl: contributor.avatarUrl)

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
                    ContributionTagView(contribution: .code)

                    Text(contributionsText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
