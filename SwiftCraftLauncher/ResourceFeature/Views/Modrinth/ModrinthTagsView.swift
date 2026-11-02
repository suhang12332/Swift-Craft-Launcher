//
//  ModrinthTagsView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays up to `maxTags` tags, with a +N marker when more are available.
struct ModrinthTagsView: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(
                Array(
                    tags.prefix(
                        ModrinthConstants.UIConstants.maxTags,
                    ),
                ),
                id: \.self,
            ) { tag in
                ModrinthDetailCardTagView(text: tag)
            }

            if tags.count > ModrinthConstants.UIConstants.maxTags {
                Text("+\(tags.count - ModrinthConstants.UIConstants.maxTags)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
