//
//  ResourceCountSectionView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Displays the installed resource counts for a game as a section.
import AppKit
import Foundation
import SwiftUI

struct ResourceCountSectionView: View {
    let counts: [GameOverviewItem]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "game.info.overview",
            items: counts,
            isLoading: isLoading,
            maxItems: counts.count,
            maxHeight: nil,
            iconName: GameOverviewItem.fallbackSystemImage,
        ) { item in
            chip(for: item)
        }
    }

    @ViewBuilder
    private func chip(for item: GameOverviewItem) -> some View {
        let title = countTitle(for: item)
        let iconName = item.hasError ? GameOverviewItem.errorSystemImage : item.systemImage
        let customBackgroundColor = item.hasError ? Color.red.opacity(0.1) : nil
        let customBorderColor = item.hasError ? Color.red.opacity(0.3) : nil
        let iconColor: Color? = item.hasError ? .red : nil

        if let action = action(for: item) {
            FilterChip(
                title: title,
                action: action,
                iconName: iconName,
                customBackgroundColor: customBackgroundColor,
                customBorderColor: customBorderColor,
                iconColor: iconColor,
            )
        } else {
            FilterChipLabel(
                title: title,
                iconName: iconName,
                customBackgroundColor: customBackgroundColor,
                customBorderColor: customBorderColor,
                iconColor: iconColor,
            )
        }
    }

    private func action(for item: GameOverviewItem) -> (() -> Void)? {
        guard !item.directories.isEmpty else { return nil }
        return { openDirectories(item.directories) }
    }

    private func openDirectories(_ directories: [URL]) {
        let existing = directories.filter { FileManager.default.fileExists(atPath: $0.path) }

        if existing.isEmpty {
            guard let parent = directories.first?.deletingLastPathComponent(),
                  FileManager.default.fileExists(atPath: parent.path) else {
                AppLog.game.error("Failed to open overview directory: no directory exists")
                return
            }
            if !NSWorkspace.shared.open(parent) {
                AppLog.game.error("Failed to open overview directory: \(parent.path)")
            }
            return
        }

        if existing.count == 1 {
            if !NSWorkspace.shared.open(existing[0]) {
                AppLog.game.error("Failed to open overview directory: \(existing[0].path)")
            }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(existing)
        }
    }

    private func countTitle(for item: GameOverviewItem) -> String {
        String(
            format: "game.overview.item_count".localized(),
            item.title,
            item.itemCount,
        )
    }
}
