//
//  ModrinthTagsView.swift
//  ResourceFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays up to `maxTags` tags, with a +N marker when more are available.
struct ModrinthTagsView: View {
    let tags: [String]
    var maxTags: Int = ModrinthConstants.UIConstants.maxTags

    var body: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(
                Array(tags.prefix(maxTags)),
                id: \.self,
            ) { tag in
                ModrinthDetailCardTagView(text: tag)
            }

            if tags.count > maxTags {
                Text("+\(tags.count - maxTags)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
