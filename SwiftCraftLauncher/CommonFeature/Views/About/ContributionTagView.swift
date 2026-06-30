//
//  ContributionTagView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a contribution type tag with color-coded styling.
struct ContributionTagView: View {
    let contribution: Contribution

    var body: some View {
        Text(contribution.localizedString)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundColor(contribution.color)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(lineWidth: 1)
                    .foregroundStyle(contribution.color)
                    .opacity(0.8)
            }
    }
}
