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

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }

    // 根据搜索文本过滤已加载的资源（仅基于标题）
    private var filteredResources: [ModrinthProjectDetail] {
        if searchTextForResource.isEmpty {
            return scannedResources
        }

        let searchLower = searchTextForResource.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return scannedResources.filter { detail in
            // 仅搜索标题
            detail.title.lowercased().contains(searchLower)
        }
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
                // 页面初始化时，直接加载第一页资源
                initializeResourceDirectory()
                resetPagination()
                loadPage(page: 1, append: false)
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
        .onChange(of: refreshToken) { _, _ in
            resetPagination()
            loadPage(page: 1, append: false)
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
        let filteredResources = self.filteredResources

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
        } else if hasLoaded && filteredResources.isEmpty {
            EmptyView()
        } else {
            ForEach(
                filteredResources.map { ModrinthProject.from(detail: $0) },
                id: \.projectId
            ) { mod in
                ModrinthDetailCardView(
                    project: mod,
                    selectedVersions: [game.gameVersion],
                    selectedLoaders: [game.modLoader],
                    gameInfo: game,
                    query: query,
                    type: false,
                    selectedItem: $selectedItem
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
                    loadNextPageIfNeeded(currentItem: mod, totalCount: filteredResources.count)
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
        searchTextForResource = ""
        scannedResources = []
        isLoadingResources = false
        error = nil
        currentPage = 1
        hasMoreResults = true
        isLoadingMore = false
        hasLoaded = false
        resourceDirectory = nil
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

        // 确保资源目录已初始化
        if resourceDirectory == nil {
            initializeResourceDirectory()
        }

        guard let resourceDir = resourceDirectory else {
            return
        }

        // 获取所有文件 URL（不进行过滤，直接加载所有文件）
        let allFiles = ModScanner.shared.getAllResourceFiles(resourceDir)

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

        ModScanner.shared.scanResourceFilesPage(
            fileURLs: allFiles,
            page: page,
            pageSize: pageSize
        ) { details, hasMore in
            DispatchQueue.main.async {
                if append {
                    scannedResources.append(contentsOf: details)
                } else {
                    scannedResources = details
                }
                hasMoreResults = hasMore
                isLoadingResources = false
                isLoadingMore = false

                // 如果当前处于搜索状态且匹配结果过少，则自动继续加载更多页
                if !searchTextForResource.isEmpty && hasMore {
                    // 直接计算当前过滤结果数量
                    let searchLower = searchTextForResource.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let filteredCount = scannedResources.filter { detail in
                        detail.title.lowercased().contains(searchLower)
                    }.count
                    // 如果过滤结果少于半页，继续加载
                    if filteredCount < pageSize / 2 {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
                            guard hasMoreResults, !isLoadingResources, !isLoadingMore else { return }
                            currentPage += 1
                            let nextPage = currentPage
                            loadPage(page: nextPage, append: true)
                        }
                    }
                }
            }
        }
    }

    private func loadNextPageIfNeeded(
        currentItem mod: ModrinthProject,
        totalCount: Int
    ) {
        guard hasMoreResults, !isLoadingResources, !isLoadingMore else {
            return
        }
        guard
            let index = scannedResources.firstIndex(where: {
                $0.id == mod.projectId
            })
        else { return }

        // 如果正在搜索且过滤结果很少，直接触发加载（不依赖滚动位置）
        if !searchTextForResource.isEmpty {
            let filteredList = filteredResources
            let filteredCount = filteredList.count
            // 如果过滤结果少于半页，直接加载更多
            if filteredCount < pageSize / 2 {
                currentPage += 1
                let nextPage = currentPage
                loadPage(page: nextPage, append: true)
                return
            }
        }

        // 保持原有行为：当滚动到已加载列表的末尾附近时加载下一页
        let thresholdIndex = max(scannedResources.count - 5, 0)
        if index >= thresholdIndex {
            currentPage += 1
            let nextPage = currentPage
            loadPage(page: nextPage, append: true)
        }
    }
}
