import SwiftUI

// MARK: - Constants
private enum WorldInfoSectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let maxItems: Int = 6  // 最多显示6个
}

// MARK: - 世界信息区域视图
struct WorldInfoSectionView: View {
    // MARK: - Properties
    let worlds: [WorldInfo]
    let isLoading: Bool
    let gameName: String
    
    @State private var showOverflowPopover = false
    @State private var selectedWorld: WorldInfo?
    
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
        .sheet(item: $selectedWorld) { world in
            WorldDetailSheetView(world: world, gameName: gameName)
        }
    }
    
    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                overflowButton(overflowItems: overflowItems)
            }
        }
        .padding(.bottom, WorldInfoSectionConstants.headerBottomPadding)
    }
    
    private var headerTitle: some View {
        Text("saveinfo.worlds".localized())
            .font(.headline)
    }
    
    private func overflowButton(overflowItems: [WorldInfo]) -> some View {
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
        overflowItems: [WorldInfo]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    ForEach(overflowItems) { world in
                        WorldInfoChip(
                            title: world.name,
                            isLoading: false
                        ) {
                            selectedWorld = world
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: WorldInfoSectionConstants.popoverMaxHeight)
        }
        .frame(width: WorldInfoSectionConstants.popoverWidth)
    }
    
    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<WorldInfoSectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    WorldInfoChip(
                        title: "common.loading".localized(),
                        isLoading: true
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: WorldInfoSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, WorldInfoSectionConstants.verticalPadding)
    }
    
    private var contentWithOverflow: some View {
        let (visibleItems, _) = computeVisibleAndOverflowItems()
        return FlowLayout {
            ForEach(visibleItems) { world in
                WorldInfoChip(
                    title: world.name,
                    isLoading: false
                ) {
                    selectedWorld = world
                }
            }
        }
        .frame(maxHeight: WorldInfoSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, WorldInfoSectionConstants.verticalPadding)
        .padding(.bottom, WorldInfoSectionConstants.verticalPadding)
    }
    
    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> (
        [WorldInfo], [WorldInfo]
    ) {
        // 最多显示6个
        let visibleItems = Array(worlds.prefix(WorldInfoSectionConstants.maxItems))
        let overflowItems = Array(worlds.dropFirst(WorldInfoSectionConstants.maxItems))
        
        return (visibleItems, overflowItems)
    }
}

// MARK: - World Info Chip
struct WorldInfoChip: View {
    let title: String
    let isLoading: Bool
    let action: (() -> Void)?
    
    init(title: String, isLoading: Bool, action: (() -> Void)? = nil) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
