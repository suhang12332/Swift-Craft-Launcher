import SwiftUI

struct SkinLibraryPopoverContentView: View {
    private static let tileSize: CGFloat = 72
    private static let gridSpacing: CGFloat = 12
    private static let columnsCount = 4
    private static let horizontalPadding: CGFloat = 24
    private static var popoverWidth: CGFloat {
        (CGFloat(columnsCount) * tileSize)
        + (CGFloat(columnsCount - 1) * gridSpacing)
        + horizontalPadding
    }

    let items: [SkinLibraryItem]
    @Binding var isPresented: Bool
    let onSelectItem: (SkinLibraryItem) -> Void
    let onDeleteItem: (SkinLibraryItem) -> Void
    let onAppear: () -> Void

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(Self.tileSize), spacing: Self.gridSpacing),
                count: Self.columnsCount
            ),
            spacing: Self.gridSpacing
        ) {
            ForEach(items) { item in
                MinecraftSkinUtils(type: .local, src: item.fileURL.path, size: 48)
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
            }
        }
        .padding()
        .frame(width: Self.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: onAppear)
    }
}
