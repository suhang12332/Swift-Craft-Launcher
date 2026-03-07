import SwiftUI

// MARK: - Main View
struct ModrinthDetailView: View {
    private enum UIConstants {
        static let emptyStateDelayNanoseconds: UInt64 = 1_200_000_000
    }

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
    @State private var hasLoaded = false
    @Binding var searchText: String
    @State private var searchTimer: Timer?
    @State private var currentPage: Int = 1
    @State private var lastSearchParams: String = ""
    @State private var error: GlobalError?
    @State private var canShowEmptyResult = false
    @State private var emptyResultDelayTask: Task<Void, Never>?

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

    private var hasMoreResults: Bool {
        viewModel.results.count < viewModel.totalHits
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
                await initialLoadIfNeeded()
            }
        }
        // 当筛选条件变化时，重新搜索
        .onChange(of: selectedVersions) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: selectedCategories) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: selectedFeatures) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: selectedResolutions) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: selectedPerformanceImpact) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: selectedLoader) { _, _ in
            resetPagination()
            triggerSearch()
        }
        .onChange(of: dataSource) { _, _ in
            // 清理之前的旧数据
            viewModel.clearResults()
            resetPagination()
//            searchText = ""
            lastSearchParams = ""
            error = nil
            hasLoaded = false
            triggerSearch()
        }
        .onChange(of: query) { _, _ in
            // 清理之前的旧数据
            viewModel.clearResults()
            triggerSearch()
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
                resetPagination()
                debounceSearch()
            }
        }
        .alert(
            "error.notification.search.title".localized(),
            isPresented: .constant(error != nil)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
        .onDisappear {
            searchTimer?.invalidate()
            searchTimer = nil
            emptyResultDelayTask?.cancel()
            emptyResultDelayTask = nil
        }
    }

    // MARK: - Private Methods
    private func initialLoadIfNeeded() async {
        if !hasLoaded {
            hasLoaded = true
            resetPagination()
            await performSearchWithErrorHandling(page: 1, append: false)
        }
    }

    private func triggerSearch() {
        Task {
            await performSearchWithErrorHandling(page: 1, append: false)
        }
    }

    private func debounceSearch() {
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { _ in
            Task {
                await performSearchWithErrorHandling(page: 1, append: false)
            }
        }
    }

    private func performSearchWithErrorHandling(
        page: Int,
        append: Bool
    ) async {
        do {
            try await performSearchThrowing(page: page, append: append)
            // 搜索完成后预加载图片
            preloadImages()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            await MainActor.run {
                self.emptyResultDelayTask?.cancel()
                self.emptyResultDelayTask = nil
                self.error = globalError
            }
        }
    }

    private func performSearchThrowing(page: Int, append: Bool) async throws {
        let params = buildSearchParamsKey(page: page)

        if params == lastSearchParams {
            // 完全重复，不请求
            return
        }

        guard !query.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "查询类型不能为空",
                i18nKey: "error.validation.query_type_empty",
                level: .notification
            )
        }

        lastSearchParams = params
        if !append {
            startEmptyResultDelay()
            viewModel.beginNewSearch()
        }
        await viewModel.search(
            query: searchText,
            projectType: query,
            versions: selectedVersions,
            categories: selectedCategories,
            features: selectedFeatures,
            resolutions: selectedResolutions,
            performanceImpact: selectedPerformanceImpact,
            loaders: selectedLoader,
            page: page,
            append: append,
            dataSource: dataSource
        )

        await MainActor.run {
            if !viewModel.results.isEmpty {
                canShowEmptyResult = true
                emptyResultDelayTask?.cancel()
                emptyResultDelayTask = nil
            }
        }
    }

    private func startEmptyResultDelay() {
        emptyResultDelayTask?.cancel()
        canShowEmptyResult = false
        emptyResultDelayTask = Task {
            try? await Task.sleep(nanoseconds: UIConstants.emptyStateDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if viewModel.results.isEmpty {
                    canShowEmptyResult = true
                }
            }
        }
    }

    // MARK: - Result List
    @ViewBuilder private var listContent: some View {
        Group {
            if let error = error {
                newErrorView(error)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if viewModel.isLoading && viewModel.results.isEmpty {
                // 显示骨架占位符
                skeletonPlaceholders
            } else if hasLoaded && viewModel.results.isEmpty && !canShowEmptyResult {
                // 空状态延迟期间继续显示骨架，避免过早提示“无结果”
                skeletonPlaceholders
            } else if hasLoaded && viewModel.results.isEmpty {
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
                        // 禁用动画以优化性能
                        selectedProjectId = mod.projectId
                        if let type = ResourceType(rawValue: query) {
                            let nextItem = SidebarItem.resource(type)
                            if selectedItem != nextItem {
                                selectedItem = nextItem
                            }
                        }
                    }
                    .onAppear {
                        loadNextPageIfNeeded(currentItem: mod)
                    }
                }
            }
        }
    }

    private func loadNextPageIfNeeded(currentItem mod: ModrinthProject) {
        guard hasMoreResults, !viewModel.isLoading, !viewModel.isLoadingMore else {
            return
        }
        guard
            let index = viewModel.results.firstIndex(where: { $0.projectId == mod.projectId })
        else { return }

        let thresholdIndex = max(viewModel.results.count - 5, 0)
        if index >= thresholdIndex {
            currentPage += 1
            let nextPage = currentPage
            Task {
                await performSearchWithErrorHandling(page: nextPage, append: true)
            }
        }
    }

    private func resetPagination() {
        currentPage = 1
        lastSearchParams = ""
    }

    /// 后台预加载可见的资源图片（只预加载前20个）
    private func preloadImages() {
        let imageUrls = viewModel.results
            .prefix(20)  // 只预加载前 20 个可见的
            .compactMap { $0.iconUrl }
            .compactMap(URL.init(string:))

        if !imageUrls.isEmpty {
            ResourceImageCacheManager.shared.preloadImages(urls: imageUrls)
        }
    }

    private func buildSearchParamsKey(page: Int) -> String {
        [
            query,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(gameType),
            searchText,
            "page:\(page)",
            dataSource.rawValue,
        ].joined(separator: "|")
    }

    private var loadingMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
                .padding(.vertical, 12)
            Spacer()
        }
    }

    // MARK: - Skeleton Placeholders
    /// 骨架占位符视图（加载时显示）
    private var skeletonPlaceholders: some View {
        ForEach(0..<10, id: \.self) { _ in
            SkeletonResourceCard()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                )
                .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Skeleton Card View
/// 骨架占位符卡片
private struct SkeletonResourceCard: View {
    var body: some View {
        HStack(spacing: ModrinthConstants.UIConstants.contentSpacing) {
            // 图标占位符
            RoundedRectangle(cornerRadius: ModrinthConstants.UIConstants.cornerRadius)
                .fill(Color.gray.opacity(0.2))
                .frame(
                    width: ModrinthConstants.UIConstants.iconSize,
                    height: ModrinthConstants.UIConstants.iconSize
                )

            VStack(alignment: .leading, spacing: ModrinthConstants.UIConstants.spacing) {
                // 标题占位符
                Text("Loading Resource Title")
                    .font(.headline)
                    .lineLimit(1)

                // 描述占位符
                Text("Loading description text for this resource item")
                    .font(.subheadline)
                    .lineLimit(ModrinthConstants.UIConstants.descriptionLineLimit)

                // 标签占位符
                HStack(spacing: ModrinthConstants.UIConstants.spacing) {
                    ForEach(0..<3) { _ in
                        Text("Tag")
                            .font(.caption2)
                            .padding(
                                EdgeInsets(
                                    top: ModrinthConstants.UIConstants.tagVerticalPadding,
                                    leading: ModrinthConstants.UIConstants.tagHorizontalPadding,
                                    bottom: ModrinthConstants.UIConstants.tagVerticalPadding,
                                    trailing: ModrinthConstants.UIConstants.tagHorizontalPadding
                                )
                            )
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(ModrinthConstants.UIConstants.tagCornerRadius)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: .placeholder)
        .shimmer()
    }
}

// MARK: - Shimmer Effect
/// 为骨架屏添加闪烁动画效果
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        self
    }
}
