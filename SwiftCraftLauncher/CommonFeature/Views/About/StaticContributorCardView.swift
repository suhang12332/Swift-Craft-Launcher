//
//  StaticContributorCardView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a statically-defined contributor's information in a card layout.
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
            StaticContributorAvatarView(avatar: contributor.avatar)

            VStack(alignment: .leading, spacing: 4) {
                Text(contributor.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    ForEach(contributor.contributions, id: \.self) { contribution in
                        ContributionTagView(contribution: contribution)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
