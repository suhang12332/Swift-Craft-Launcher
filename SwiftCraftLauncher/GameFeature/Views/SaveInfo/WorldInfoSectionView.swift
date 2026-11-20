//
//  WorldInfoSectionView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Displays world save folders as chips that open the world directory in Finder.
import AppKit
import SwiftUI

struct WorldInfoSectionView: View {
    let worlds: [WorldInfo]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: GameOverviewItem.Kind.world.titleKey,
            items: worlds,
            isLoading: isLoading,
            iconName: GameOverviewItem.Kind.world.systemImage,
        ) { world in
            FilterChip(
                title: world.name,
                action: {
                    NSWorkspace.shared.open(world.path)
                },
                iconName: GameOverviewItem.Kind.world.systemImage,
                maxTextWidth: 150,
            )
        }
    }
}
