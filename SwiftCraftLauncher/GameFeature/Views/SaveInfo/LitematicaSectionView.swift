//
//  LitematicaSectionView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

// Displays Litematica schematic files as selectable chips with detail sheet support.
import SwiftUI

struct LitematicaSectionView: View {
    let litematicaFiles: [LitematicaInfo]
    let isLoading: Bool
    let gameName: String

    @State private var selectedFile: LitematicaInfo?

    var body: some View {
        GenericSectionView(
            title: "saveinfo.litematica",
            items: litematicaFiles,
            isLoading: isLoading,
            iconName: "square.stack.3d.up",
        ) { file in
            litematicaChip(for: file)
        }
        .sheet(item: $selectedFile) { file in
            LitematicaDetailSheetView(filePath: file.path, gameName: gameName)
        }
    }

    private func litematicaChip(for file: LitematicaInfo) -> some View {
        FilterChip(
            title: file.name,
            action: {
                selectedFile = file
            },
            iconName: "square.stack.3d.up",
            isLoading: false,
            verticalPadding: 6,
            maxTextWidth: 150,
        )
    }
}
