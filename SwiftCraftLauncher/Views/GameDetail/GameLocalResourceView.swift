import SwiftUI

struct GameLocalResourceView: View {
    let game: GameVersionInfo
    let query: String
    let header: AnyView?
    @Binding var selectedItem: SidebarItem
    @Binding var selectedProjectId: String?
    let refreshToken: UUID

    @State private var searchTextForResource = ""
    @State private var scannedResources: [ModrinthProjectDetail] = []
    @State private var isLoadingResources = false
    @State private var error: GlobalError?
    @State private var currentPage: Int = 1
    @State private var hasMoreResults: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var hasLoaded: Bool = false
    @State private var resourceDirectory: URL? // 保存资源目录路径
    @State private var allFiles: [URL] = [] // 所有文件列表
    @State private var searchTimer: Timer? // 搜索防抖定时器

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }
    
    // 当前显示的资源列表（无限滚动）
    private var displayedResources: [ModrinthProjectDetail] {
        scannedResources
    }

    var body: some View {
        List {
            if let header {
                header
                    .listRowSeparator(.hidden)
            }
            listContent
            if isLoadingMore {
                loadingMoreIndicator
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $searchTextForResource,
            placement: .toolbar,
            prompt: "search.resources".localized()
        )
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                // 页面初始化时，加载第一页资源（无限滚动）
                initializeResourceDirectory()
                resetPagination()
                refreshAllFiles()
                loadPage(page: 1, append: false)
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
        .onChange(of: refreshToken) { _, _ in
            resetPagination()
            refreshAllFiles()
            loadPage(page: 1, append: false)
        }
        .onChange(of: searchTextForResource) { oldValue, newValue in
            // 搜索文本变化时，重置分页并触发防抖搜索
            if oldValue != newValue {
                resetPagination()
                debounceSearch()
            }
        }
        .alert(
            "error.notification.validation.title".localized(),
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
    }

    // MARK: - 列表内容
    @ViewBuilder private var listContent: some View {
        if let error {
            VStack {
                Text(error.chineseMessage)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
        } else if isLoadingResources && scannedResources.isEmpty {
            HStack {
                ProgressView()
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
        } else if hasLoaded && displayedResources.isEmpty {
            EmptyView()
        } else {
            ForEach(
                displayedResources.map { ModrinthProject.from(detail: $0) },
                id: \.projectId
            ) { mod in
                ModrinthDetailCardView(
                    project: mod,
                    selectedVersions: [game.gameVersion],
                    selectedLoaders: [game.modLoader],
                    gameInfo: game,
                    query: query,
                    type: false,
                    selectedItem: $selectedItem,
                    scannedDetailIds: []
                )
                .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                )
                .listRowSeparator(.hidden)
                .onTapGesture {
                    // 本地资源不跳转详情页面（沿用原逻辑）
                    if mod.author != "local" {
                        selectedProjectId = mod.projectId
                        if let type = ResourceType(rawValue: query) {
                            selectedItem = .resource(type)
                        }
                    }
                }
                .onAppear {
                    loadNextPageIfNeeded(currentItem: mod)
                }
            }
        }
    }

    private var loadingMoreIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: - 分页加载
    private func resetPagination() {
        currentPage = 1
        hasMoreResults = true
        isLoadingResources = false
        isLoadingMore = false
        error = nil
        scannedResources = []
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 清理搜索定时器
        searchTimer?.invalidate()
        searchTimer = nil
        searchTextForResource = ""
        scannedResources = []
        isLoadingResources = false
        error = nil
        currentPage = 1
        hasMoreResults = true
        isLoadingMore = false
        hasLoaded = false
        resourceDirectory = nil
        allFiles = []
    }
    
    // MARK: - 搜索相关
    /// 防抖搜索
    private func debounceSearch() {
        searchTimer?.invalidate()
        let searchText = searchTextForResource
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { _ in
            // 检查搜索文本是否已变化（避免过期的搜索）
            if self.searchTextForResource == searchText {
                self.loadPage(page: 1, append: false)
            }
        }
    }
    
    /// 根据 title 过滤资源详情
    private func filterResourcesByTitle(_ details: [ModrinthProjectDetail]) -> [ModrinthProjectDetail] {
        let searchLower = searchTextForResource.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchLower.isEmpty {
            return details
        }
        
        return details.filter { detail in
            detail.title.lowercased().contains(searchLower)
        }
    }

    // MARK: - 资源目录初始化
    /// 初始化资源目录路径
    private func initializeResourceDirectory() {
        guard resourceDirectory == nil else { return }

        resourceDirectory = AppPaths.resourceDirectory(
            for: query,
            gameName: game.gameName
        )

        if resourceDirectory == nil {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法获取资源目录路径",
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification
            )
            Logger.shared.error("初始化资源目录失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            error = globalError
        }
    }

    // MARK: - 文件列表
    private func refreshAllFiles() {
        // Modpacks don't have a local directory to scan
        if query.lowercased() == "modpack" {
            allFiles = []
            return
        }

        if resourceDirectory == nil {
            initializeResourceDirectory()
        }

        guard let resourceDir = resourceDirectory else {
            allFiles = []
            return
        }

        allFiles = ModScanner.shared.getAllResourceFiles(resourceDir)
    }

    private func loadPage(page: Int, append: Bool) {
        guard !isLoadingResources, !isLoadingMore else { return }

        // Modpacks don't have a local directory to scan, skip scanning
        if query.lowercased() == "modpack" {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        if allFiles.isEmpty {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        if append {
            isLoadingMore = true
        } else {
            isLoadingResources = true
        }
        error = nil

        let isSearching = !searchTextForResource.isEmpty
        
        // 始终使用 allFiles 进行分页扫描，然后在结果中根据 title 过滤
        ModScanner.shared.scanResourceFilesPage(
            fileURLs: allFiles,
            page: page,
            pageSize: pageSize
        ) { [self] details, hasMore in
            DispatchQueue.main.async {
                // 根据 title 过滤结果
                let filteredDetails = self.filterResourcesByTitle(details)
                
                if append {
                    // 追加模式：只添加匹配的结果
                    scannedResources.append(contentsOf: filteredDetails)
                } else {
                    // 替换模式：直接使用过滤后的结果
                    scannedResources = filteredDetails
                }
                
                // 搜索模式下：如果还有更多页，直接自动加载下一页，直到查完所有文件
                if isSearching && hasMore {
                    // 先重置加载状态，然后继续加载下一页
                    isLoadingResources = false
                    isLoadingMore = false
                    let nextPage = page + 1
                    self.currentPage = nextPage
                    // 直接继续加载下一页，不判断过滤结果
                    self.loadPage(page: nextPage, append: true)
                } else {
                    // 非搜索模式或已查完所有文件
                    hasMoreResults = hasMore
                    isLoadingResources = false
                    isLoadingMore = false
                }
            }
        }
    }

    private func loadNextPageIfNeeded(currentItem mod: ModrinthProject) {
        guard hasMoreResults, !isLoadingResources, !isLoadingMore else {
            return
        }
        guard
            let index = scannedResources.firstIndex(where: {
                $0.id == mod.projectId
            })
        else { return }

        // 滚动到已加载列表的末尾附近时加载下一页
        let thresholdIndex = max(scannedResources.count - 5, 0)
        if index >= thresholdIndex {
            currentPage += 1
            let nextPage = currentPage
            loadPage(page: nextPage, append: true)
        }
    }
}

