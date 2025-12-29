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
                overflowButton(overflowItems: overflowItems)
            }
        }
        .padding(.bottom, LitematicaSectionConstants.headerBottomPadding)
    }

    private var headerTitle: some View {
        Text("saveinfo.litematica".localized())
            .font(.headline)
    }

    private func overflowButton(overflowItems: [LitematicaInfo]) -> some View {
        Button {
            showOverflowPopover = true
        } label: {
            Text("+\(overflowItems.count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOverflowPopover, arrowEdge: .leading) {
            overflowPopoverContent(overflowItems: overflowItems)
        }
    }

    private func overflowPopoverContent(
        overflowItems: [LitematicaInfo]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    ForEach(overflowItems) { file in
                        LitematicaFileChip(
                            title: file.name,
                            isLoading: false,
                            file: file
                        ) {
                            selectedFile = file
                            showOverflowPopover = false
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: LitematicaSectionConstants.popoverMaxHeight)
        }
        .frame(width: LitematicaSectionConstants.popoverWidth)
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<LitematicaSectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    LitematicaFileChip(
                        title: "common.loading".localized(),
                        isLoading: true
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: LitematicaSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, LitematicaSectionConstants.verticalPadding)
    }

    private var contentWithOverflow: some View {
        FlowLayout {
            ForEach(visibleItems) { file in
                LitematicaFileChip(
                    title: file.name,
                    isLoading: false,
                    file: file
                ) {
                    selectedFile = file
                }
            }
        }
        .frame(maxHeight: LitematicaSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, LitematicaSectionConstants.verticalPadding)
        .padding(.bottom, LitematicaSectionConstants.verticalPadding)
    }

    // MARK: - Helper Methods
    private func updateItemLists(from files: [LitematicaInfo]) {
        // 最多显示 6 个
        visibleItems = Array(files.prefix(LitematicaSectionConstants.maxItems))
        overflowItems = Array(files.dropFirst(LitematicaSectionConstants.maxItems))
    }
}

// MARK: - Litematica File Chip
struct LitematicaFileChip: View {
    let title: String
    let isLoading: Bool
    let file: LitematicaInfo?
    let action: (() -> Void)?

    init(title: String, isLoading: Bool, file: LitematicaInfo? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.isLoading = isLoading
        self.file = file
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
            )
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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
