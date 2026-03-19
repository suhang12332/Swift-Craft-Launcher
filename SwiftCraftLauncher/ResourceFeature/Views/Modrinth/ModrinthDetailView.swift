import SwiftUI

// MARK: - Main View
struct ModrinthDetailView: View {
    // MARK: - Properties
    let query: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoader: [String]
    let gameInfo: GameVersionInfo?
    @Binding var selectedItem: SidebarItem
    @Binding var gameType: Bool
    let header: AnyView?
    @Binding var scannedDetailIds: Set<String> // 已扫描资源的 detailId Set，用于快速查找
    @Binding var dataSource: DataSource

    @StateObject private var viewModel = ModrinthSearchViewModel()
    @Binding var searchText: String
    @StateObject private var coordinator = ModrinthDetailCoordinatorViewModel()

    init(
        query: String,
        selectedVersions: Binding<[String]>,
        selectedCategories: Binding<[String]>,
        selectedFeatures: Binding<[String]>,
        selectedResolutions: Binding<[String]>,
        selectedPerformanceImpact: Binding<[String]>,
        selectedProjectId: Binding<String?>,
        selectedLoader: Binding<[String]>,
        gameInfo: GameVersionInfo?,
        selectedItem: Binding<SidebarItem>,
        gameType: Binding<Bool>,
        header: AnyView? = nil,
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        dataSource: Binding<DataSource> = .constant(.modrinth),
        searchText: Binding<String> = .constant("")
    ) {
        self.query = query
        _selectedVersions = selectedVersions
        _selectedCategories = selectedCategories
        _selectedFeatures = selectedFeatures
        _selectedResolutions = selectedResolutions
        _selectedPerformanceImpact = selectedPerformanceImpact
        _selectedProjectId = selectedProjectId
        _selectedLoader = selectedLoader
        self.gameInfo = gameInfo
        _selectedItem = selectedItem
        _gameType = gameType
        self.header = header
        _scannedDetailIds = scannedDetailIds
        _dataSource = dataSource
        _searchText = searchText
    }

    private var searchKey: String {
        [
            query,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(gameType),
            dataSource.rawValue,
        ].joined(separator: "|")
    }

    // MARK: - Body
    var body: some View {
        List {
            if let header {
                header
                    .listRowSeparator(.hidden)
            }
            listContent
            if viewModel.isLoadingMore {
                loadingMoreIndicator
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .task {
            if gameType {
                await coordinator.initialLoadIfNeeded(
                    gameType: gameType,
                    searchViewModel: viewModel,
                    context: currentSearchContext
                )
            }
        }
        // 当筛选条件变化时，重新搜索
        .onChange(of: selectedVersions) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedCategories) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedFeatures) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedResolutions) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedPerformanceImpact) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedLoader) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: dataSource) { _, _ in
            // 清理之前的旧数据
            viewModel.clearResults()
            coordinator.resetPagination()
//            searchText = ""
            coordinator.clearError()
            coordinator.hasLoaded = false
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: query) { _, _ in
            // 清理之前的旧数据
            viewModel.clearResults()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
            searchText = ""
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "search.resources".localized()
        )

        .onChange(of: searchText) { oldValue, newValue in
            // 优化：仅在搜索文本实际变化时触发防抖搜索
            if oldValue != newValue {
                coordinator.resetPagination()
                coordinator.debounceSearch(
                    searchViewModel: viewModel,
                    context: currentSearchContext
                )
            }
        }
        .alert(
            "error.notification.search.title".localized(),
            isPresented: Binding(
                get: { coordinator.error != nil },
                set: { if !$0 { coordinator.clearError() } }
            )
        ) {
            Button("common.close".localized()) {
                coordinator.clearError()
            }
        } message: {
            if let error = coordinator.error {
                Text(error.chineseMessage)
            }
        }
        .onDisappear {
            cleanupOnDisappear()
        }
    }

    private func cleanupOnDisappear() {
        coordinator.cancelDebounce()
        coordinator.resetPagination()
        coordinator.clearError()
        coordinator.hasLoaded = false
        viewModel.clearResults()
        searchText = ""
    }

    // MARK: - Result List
    @ViewBuilder private var listContent: some View {
        Group {
            if let error = coordinator.error {
                newErrorView(error)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
            } else if coordinator.hasLoaded && viewModel.results.isEmpty {
                emptyResultView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.results, id: \.projectId) { mod in
                    ModrinthDetailCardView(
                        project: mod,
                        selectedVersions: selectedVersions,
                        selectedLoaders: selectedLoader,
                        gameInfo: gameInfo,
                        query: query,
                        type: true,
                        selectedItem: $selectedItem,
                        scannedDetailIds: $scannedDetailIds
                    )
                    .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                    )
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProjectId = mod.projectId
                        if let type = ResourceType(rawValue: query) {
                            selectedItem = .resource(type)
                        }
                    }
                    .onAppear {
                        coordinator.loadNextPageIfNeeded(
                            currentItem: mod,
                            searchViewModel: viewModel,
                            context: currentSearchContext
                        )
                    }
                }
            }
        }
    }

    private var currentSearchContext: ModrinthSearchContext {
        ModrinthSearchContext(
            query: query,
            selectedVersions: selectedVersions,
            selectedCategories: selectedCategories,
            selectedFeatures: selectedFeatures,
            selectedResolutions: selectedResolutions,
            selectedPerformanceImpact: selectedPerformanceImpact,
            selectedLoader: selectedLoader,
            gameType: gameType,
            dataSource: dataSource,
            searchText: searchText
        )
    }

    private var loadingMoreIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
