import SwiftUI

struct GameRemoteResourceView: View {
    let game: GameVersionInfo
    @Binding var query: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var selectedItem: SidebarItem
    @Binding var gameType: Bool
    let header: AnyView?
    @Binding var scannedDetailIds: Set<String> // 从父视图传入的 detailId Set，用于快速查找
    @Binding var dataSource: DataSource

    init(
        game: GameVersionInfo,
        query: Binding<String>,
        selectedVersions: Binding<[String]>,
        selectedCategories: Binding<[String]>,
        selectedFeatures: Binding<[String]>,
        selectedResolutions: Binding<[String]>,
        selectedPerformanceImpact: Binding<[String]>,
        selectedProjectId: Binding<String?>,
        selectedLoaders: Binding<[String]>,
        selectedItem: Binding<SidebarItem>,
        gameType: Binding<Bool>,
        header: AnyView? = nil,
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        dataSource: Binding<DataSource> = .constant(.modrinth)
    ) {
        self.game = game
        _query = query
        _selectedVersions = selectedVersions
        _selectedCategories = selectedCategories
        _selectedFeatures = selectedFeatures
        _selectedResolutions = selectedResolutions
        _selectedPerformanceImpact = selectedPerformanceImpact
        _selectedProjectId = selectedProjectId
        _selectedLoaders = selectedLoaders
        _selectedItem = selectedItem
        _gameType = gameType
        self.header = header
        _scannedDetailIds = scannedDetailIds
        _dataSource = dataSource
    }

    var body: some View {
        ModrinthDetailView(
            query: query,
            selectedVersions: $selectedVersions,
            selectedCategories: $selectedCategories,
            selectedFeatures: $selectedFeatures,
            selectedResolutions: $selectedResolutions,
            selectedPerformanceImpact: $selectedPerformanceImpact,
            selectedProjectId: $selectedProjectId,
            selectedLoader: $selectedLoaders,
            gameInfo: game,
            selectedItem: $selectedItem,
            gameType: $gameType,
            header: header,
            scannedDetailIds: $scannedDetailIds,
            dataSource: $dataSource
        )
    }
}
