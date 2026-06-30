//
//  ContributorRankBadgeView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a rank badge for top contributors.
struct ContributorRankBadgeView: View {
    let rank: Int

    var body: some View {
        let (color, icon) = rankBadgeStyle(rank)

        return ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: 20, height: 20)

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func rankBadgeStyle(_ rank: Int) -> (Color, String?) {
        switch rank {
        case 1:
            return (.yellow, "crown.fill")
        case 2:
            return (.gray, "2.circle.fill")
        case 3:
            return (.orange, "3.circle.fill")
        default:
            return (.accentColor, nil)
        }
    }
}
