import SwiftUI

// MARK: - 世界信息区域视图
struct WorldInfoSectionView: View {
    // MARK: - Properties
    let worlds: [WorldInfo]
    let isLoading: Bool
    let gameName: String

    @State private var selectedWorld: WorldInfo?

    // MARK: - Body
    var body: some View {
        GenericSectionView(
            title: "saveinfo.worlds",
            items: worlds,
            isLoading: isLoading,
            iconName: "folder.fill"
        ) { world in
            worldChip(for: world)
        }
        .sheet(item: $selectedWorld) { world in
            WorldDetailSheetView(world: world, gameName: gameName)
        }
    }

    // MARK: - Chip Builder
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
