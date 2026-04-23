import SwiftUI

struct SkinLibraryPopoverContentView: View {
    private static let tileSize: CGFloat = 48
    private static let gridSpacing: CGFloat = 12
    private static let maxColumnsCount = 4

    let items: [SkinLibraryItem]
    @Binding var isPresented: Bool
    let onSelectItem: (SkinLibraryItem) -> Void
    let onDeleteItem: (SkinLibraryItem) -> Void

    private var columnsCount: Int {
        min(Self.maxColumnsCount, max(items.count, 1))
    }

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(Self.tileSize), spacing: Self.gridSpacing),
                count: columnsCount
            ),
            spacing: Self.gridSpacing
        ) {
            ForEach(items) { item in
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
        .padding()
    }
}
