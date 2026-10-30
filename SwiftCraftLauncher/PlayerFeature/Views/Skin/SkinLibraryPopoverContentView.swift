//
//  SkinLibraryPopoverContentView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a paginated grid of skin library items for selection.
///
/// Items are loaded lazily as the grid scrolls: appearing the last item asks
/// the owner to fetch the next database page.
struct SkinLibraryPopoverContentView: View {
    private static let tileSize: CGFloat = 48
    private static let gridSpacing: CGFloat = 16
    private static let columnsCount = 4
    private static let contentPadding: CGFloat = 16
    private static let maxVisibleRows = 3
    private static let columns = Array(
        repeating: GridItem(.fixed(tileSize), spacing: gridSpacing),
        count: columnsCount,
    )
    private static let contentWidth = CGFloat(columnsCount) * tileSize
        + CGFloat(columnsCount - 1) * gridSpacing
        + contentPadding * 2

    let items: [SkinLibraryItem]
    @Binding var isPresented: Bool
    let onLoadMore: () -> Void
    let onSelectItem: (SkinLibraryItem) -> Void
    let onDeleteItem: (SkinLibraryItem) -> Void

    private var contentHeight: CGFloat {
        let rowCount = max(
            Int(ceil(Double(items.count) / Double(Self.columnsCount))),
            1,
        )
        let visibleRows = min(rowCount, Self.maxVisibleRows)
        return CGFloat(visibleRows) * Self.tileSize
            + CGFloat(visibleRows - 1) * Self.gridSpacing
            + Self.contentPadding * 2
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Self.columns, spacing: Self.gridSpacing) {
                ForEach(items) { item in
                    tile(for: item)
                        .onAppear {
                            guard item.id == items.last?.id else { return }
                            onLoadMore()
                        }
                }
            }
            .padding(Self.contentPadding)
        }
        .frame(width: Self.contentWidth, height: contentHeight)
    }

    private func tile(for item: SkinLibraryItem) -> some View {
        MinecraftSkinUtils(type: .local, src: item.fileURL.path, size: Self.tileSize)
            .frame(width: Self.tileSize, height: Self.tileSize)
            .onTapGesture {
                onSelectItem(item)
                isPresented = false
            }
            .contextMenu {
                Button("common.delete".localized(), role: .destructive) {
                    onDeleteItem(item)
                }
            }
            .applyPointerHandIfAvailable()
    }
}
