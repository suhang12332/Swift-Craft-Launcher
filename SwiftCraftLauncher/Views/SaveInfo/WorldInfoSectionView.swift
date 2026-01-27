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
        let (_, overflowItems) = worlds.computeVisibleAndOverflowItems(maxItems: WorldInfoSectionConstants.maxItems)
        return HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                OverflowButton(
                    count: overflowItems.count,
                    isPresented: $showOverflowPopover
                ) {
                    OverflowPopoverContent(
                        items: overflowItems,
                        maxHeight: WorldInfoSectionConstants.popoverMaxHeight,
                        width: WorldInfoSectionConstants.popoverWidth
                    ) { world in
                        worldChip(for: world)
                    }
                }
            }
        }
        .padding(.bottom, WorldInfoSectionConstants.headerBottomPadding)
    }

    private var headerTitle: some View {
        Text("saveinfo.worlds".localized())
            .font(.headline)
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        LoadingPlaceholder(
            count: WorldInfoSectionConstants.placeholderCount,
            iconName: "folder.fill",
            maxHeight: WorldInfoSectionConstants.maxHeight,
            verticalPadding: WorldInfoSectionConstants.verticalPadding
        )
    }

    private var contentWithOverflow: some View {
        let (visibleItems, _) = worlds.computeVisibleAndOverflowItems(maxItems: WorldInfoSectionConstants.maxItems)
        return ContentWithOverflow(
            items: visibleItems,
            maxHeight: WorldInfoSectionConstants.maxHeight,
            verticalPadding: WorldInfoSectionConstants.verticalPadding
        ) { world in
            worldChip(for: world)
        }
    }
    
    private func worldChip(for world: WorldInfo) -> some View {
        FilterChip(
            title: world.name,
            action: {
                selectedWorld = world
            },
            iconName: "folder.fill",
            isLoading: false,
            maxTextWidth: 150
        )
    }
}

