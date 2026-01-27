import SwiftUI
import AppKit

// MARK: - Constants
private enum LitematicaSectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let chipPadding: CGFloat = 16
    static let estimatedCharWidth: CGFloat = 10
    static let maxItems: Int = 6  // 最多显示6个
    static let maxWidth: CGFloat = 320
}

// MARK: - Litematica 投影文件区域视图
struct LitematicaSectionView: View {
    // MARK: - Properties
    let litematicaFiles: [LitematicaInfo]
    let isLoading: Bool
    let gameName: String

    @State private var showOverflowPopover = false
    @State private var selectedFile: LitematicaInfo?

    @State private var visibleItems: [LitematicaInfo] = []
    @State private var overflowItems: [LitematicaInfo] = []

    // MARK: - Body
    var body: some View {
        VStack {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
        .sheet(item: $selectedFile) { file in
            LitematicaDetailSheetView(filePath: file.path, gameName: gameName)
        }
        .onChange(of: litematicaFiles) { _, files in
            updateItemLists(from: files)
        }
        .onAppear {
            updateItemLists(from: litematicaFiles)
        }
    }

    // MARK: - Header Views
    private var headerView: some View {
        HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                OverflowButton(
                    count: overflowItems.count,
                    isPresented: $showOverflowPopover
                ) {
                    OverflowPopoverContent(
                        items: overflowItems,
                        maxHeight: LitematicaSectionConstants.popoverMaxHeight,
                        width: LitematicaSectionConstants.popoverWidth
                    ) { file in
                        litematicaChip(for: file, closePopover: true)
                    }
                }
            }
        }
        .padding(.bottom, LitematicaSectionConstants.headerBottomPadding)
    }

    private var headerTitle: some View {
        Text("saveinfo.litematica".localized())
            .font(.headline)
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        LoadingPlaceholder(
            count: LitematicaSectionConstants.placeholderCount,
            iconName: "square.stack.3d.up",
            maxHeight: LitematicaSectionConstants.maxHeight,
            verticalPadding: LitematicaSectionConstants.verticalPadding,
            verticalPaddingForChip: 6
        )
    }

    private var contentWithOverflow: some View {
        ContentWithOverflow(
            items: visibleItems,
            maxHeight: LitematicaSectionConstants.maxHeight,
            verticalPadding: LitematicaSectionConstants.verticalPadding
        ) { file in
            litematicaChip(for: file)
        }
    }

    // MARK: - Helper Methods
    private func updateItemLists(from files: [LitematicaInfo]) {
        let (visible, overflow) = files.computeVisibleAndOverflowItems(maxItems: LitematicaSectionConstants.maxItems)
        visibleItems = visible
        overflowItems = overflow
    }
    
    private func litematicaChip(for file: LitematicaInfo, closePopover: Bool = false) -> some View {
        FilterChip(
            title: file.name,
            action: {
                selectedFile = file
                if closePopover {
                    showOverflowPopover = false
                }
            },
            iconName: "square.stack.3d.up",
            isLoading: false,
            verticalPadding: 6,
            maxTextWidth: 150
        )
    }
}

// MARK: - Litematica File Row
struct LitematicaFileRow: View {
    let file: LitematicaInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)

                if let author = file.author {
                    Text(String(format: "saveinfo.litematica.author".localized(), author))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let description = file.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let regionCount = file.regionCount {
                        Label(String(format: "saveinfo.litematica.region_count".localized(), regionCount), systemImage: "square.grid.2x2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let totalBlocks = file.totalBlocks {
                        Label(String(format: "saveinfo.litematica.block_count".localized(), totalBlocks), systemImage: "cube")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(file.path.deletingLastPathComponent())
            } label: {
                Image(systemName: "folder.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
