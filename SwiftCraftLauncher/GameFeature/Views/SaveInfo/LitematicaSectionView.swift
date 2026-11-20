//
//  LitematicaSectionView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Displays Litematica schematic files as selectable chips with detail sheet support.
import SwiftUI

struct LitematicaSectionView: View {
    let litematicaFiles: [LitematicaInfo]
    let isLoading: Bool

    @State private var selectedFile: LitematicaInfo?

    var body: some View {
        GenericSectionView(
            title: GameOverviewItem.Kind.litematica.titleKey,
            items: litematicaFiles,
            isLoading: isLoading,
            iconName: GameOverviewItem.Kind.litematica.systemImage,
        ) { file in
            litematicaChip(for: file)
        }
        .sheet(item: $selectedFile) { file in
            LitematicaDetailSheetView(filePath: file.path)
        }
    }

    private func litematicaChip(for file: LitematicaInfo) -> some View {
        FilterChip(
            title: file.name,
            action: {
                selectedFile = file
            },
            iconName: GameOverviewItem.Kind.litematica.systemImage,
            verticalPadding: 6,
            maxTextWidth: 150,
        )
    }
}
