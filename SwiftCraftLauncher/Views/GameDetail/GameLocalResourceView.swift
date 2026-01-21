import SwiftUI
import AppKit

struct GameLocalResourceView: View {
    let game: GameVersionInfo
    let query: String
    let header: AnyView?
    @Binding var selectedItem: SidebarItem
    @Binding var selectedProjectId: String?
    let refreshToken: UUID
    @Binding var searchText: String
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
    @Binding var localFilter: LocalResourceFilter

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }

    // 当前显示的资源列表（无限滚动）
    private var displayedResources: [ModrinthProjectDetail] {
        scannedResources
    }

    /// 当前筛选下真正用于扫描的文件列表
    private var filesToScan: [URL] {
        switch localFilter {
        case .all:
            return allFiles
        case .disabled:
            // 只扫描 .disable 后缀文件
            return allFiles.filter { $0.lastPathComponent.hasSuffix(".disable") }
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
            text: $searchText,
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
            // 重置资源目录，确保切换游戏时使用新游戏的目录
            resourceDirectory = nil
            resetPagination()
            refreshAllFiles()
            loadPage(page: 1, append: false)
        }
        .onChange(of: query) { oldValue, newValue in
            // 当资源类型（query）改变时，重新初始化资源目录并刷新文件列表
            if oldValue != newValue {
                resourceDirectory = nil
                resetPagination()
                refreshAllFiles()
                loadPage(page: 1, append: false)
            }
            // 注意：不再清除搜索文本，保持用户搜索状态
            searchText = ""
        }
        .onChange(of: searchText) { oldValue, newValue in
            // 搜索文本变化时，重置分页并触发防抖搜索
            if oldValue != newValue {
                resetPagination()
                debounceSearch()
            }
        }
        .onChange(of: localFilter) { _, _ in
            resourceDirectory = nil
            resetPagination()
            refreshAllFiles()
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
                    onResourceChanged: refreshResources,
                    onLocalDisableStateChanged: handleLocalDisableStateChanged,
                    onResourceUpdated: handleResourceUpdated,
                    scannedDetailIds: .constant([])
                )
                .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                )
                .listRowSeparator(.hidden)
                .onTapGesture {
                    // 本地资源不跳转详情页面（沿用原逻辑）
                    // 使用 id 前缀判断本地资源，更可靠
                    if !mod.projectId.hasPrefix("local_") && !mod.projectId.hasPrefix("file_") {
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
        // 注意：不再清除搜索文本，保持用户搜索状态
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
        let currentSearchText = searchText
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { _ in
            // 检查搜索文本是否已变化（避免过期的搜索）
            if self.searchText == currentSearchText {
                self.loadPage(page: 1, append: false)
            }
        }
    }

    /// 根据 title 和 projectType 过滤资源详情
    private func filterResourcesByTitle(_ details: [ModrinthProjectDetail]) -> [ModrinthProjectDetail] {
        // 首先根据 query 筛选资源类型
        let queryLower = query.lowercased()
        let filteredByType = details.filter { detail in
            // 对于本地资源（id 以 "local_" 或 "file_" 开头），目录本身已经根据 query 筛选了，
            // 所以不需要再根据 projectType 筛选（因为 fallback detail 的 projectType 总是 "mod"）
            if detail.id.hasPrefix("local_") || detail.id.hasPrefix("file_") {
                // 本地资源：目录已经筛选，直接显示
                return true
            } else {
                // 从 API 获取的资源：根据 projectType 筛选
                // 确保只显示与 query 匹配的资源类型
                return detail.projectType.lowercased() == queryLower
            }
        }

        // 然后根据搜索文本过滤
        let searchLower = searchText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if searchLower.isEmpty {
            return filteredByType
        }

        return filteredByType.filter { detail in
            detail.title.lowercased().contains(searchLower)
        }
    }

    // MARK: - 资源目录初始化
    /// 初始化资源目录路径
    private func initializeResourceDirectory() {
        // 如果 resourceDirectory 已存在，检查是否匹配当前游戏
        if let existingDir = resourceDirectory {
            let expectedDir = AppPaths.resourceDirectory(
                for: query,
                gameName: game.gameName
            )
            // 如果目录不匹配，需要重新初始化
            if existingDir != expectedDir {
                resourceDirectory = nil
            } else {
                return
            }
        }

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

        // 根据当前筛选选择实际要扫描的文件集合
        let sourceFiles = filesToScan

        if sourceFiles.isEmpty {
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

        let isSearching = !searchText.isEmpty

        // 始终使用当前筛选下的文件列表进行分页扫描，然后在结果中根据 title 过滤
        ModScanner.shared.scanResourceFilesPage(
            fileURLs: sourceFiles,
            page: page,
            pageSize: pageSize
        ) { [self] details, hasMore in
            DispatchQueue.main.async {
                // 根据 title 过滤结果
                let filteredDetails = self.filterResourcesByTitle(details)

                if append {
                    // 追加模式：只添加匹配的结果，并去重
                    // 获取已存在的 id 集合，用于去重
                    let existingIds = Set(self.scannedResources.map { $0.id })
                    // 只添加不重复的资源
                    let newDetails = filteredDetails.filter { !existingIds.contains($0.id) }
                    self.scannedResources.append(contentsOf: newDetails)
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

    // MARK: - 刷新资源
    /// 刷新资源列表（删除资源后调用）
    private func refreshResources() {
        // 刷新文件列表
        refreshAllFiles()
        // 重置分页并重新加载第一页
        resetPagination()
        loadPage(page: 1, append: false)
    }

    /// 本地资源启用/禁用状态变更后的处理
    /// - Parameters:
    ///   - project: 对应的 ModrinthProject（由 detail 转换而来）
    ///   - isDisabled: 变更后的禁用状态
    private func handleLocalDisableStateChanged(
        project: ModrinthProject,
        isDisabled: Bool
    ) {
        // 在“已禁用”筛选下，当资源被启用时，从当前结果中移除该资源；无需重新扫描
        if localFilter == .disabled, !isDisabled {
            scannedResources.removeAll { $0.id == project.projectId }
        }
        // 其他场景保持现状（不额外刷新）
    }

    /// 更新成功后的局部刷新：仅更新当前条目的 hash 与列表项，不全局扫描
    /// - Parameters:
    ///   - projectId: 项目 id
    ///   - oldFileName: 更新前的文件名（用于在 allFiles 中替换）
    ///   - newFileName: 新文件名
    ///   - newHash: 新文件 hash（ModScanner 缓存已由下载器更新，此处仅预留）
    private func handleResourceUpdated(
        projectId: String,
        oldFileName: String,
        newFileName: String,
        newHash: String?
    ) {
        // 更新 scannedResources 中对应条目的 fileName
        if let i = scannedResources.firstIndex(where: { $0.id == projectId }) {
            var d = scannedResources[i]
            d.fileName = newFileName
            scannedResources[i] = d
        }
        // 更新 allFiles：将旧文件 URL 替换为新文件 URL，避免与后续分页不一致
        let resourceDir = resourceDirectory ?? AppPaths.resourceDirectory(
            for: query,
            gameName: game.gameName
        )
        if let dir = resourceDir, let j = allFiles.firstIndex(where: { $0.lastPathComponent == oldFileName }) {
            allFiles[j] = dir.appendingPathComponent(newFileName)
        }
    }

    /// 切换资源启用/禁用状态
    private func toggleResourceState(_ mod: ModrinthProject) {
        guard let resourceDir = resourceDirectory ?? AppPaths.resourceDirectory(
            for: query,
            gameName: game.gameName
        ) else {
            Logger.shared.error("切换资源启用状态失败：资源目录不存在")
            return
        }

        guard let fileName = mod.fileName else {
            Logger.shared.error("切换资源启用状态失败：缺少文件名")
            return
        }

        let fileManager = FileManager.default
        let currentURL = resourceDir.appendingPathComponent(fileName)
        let targetFileName: String

        let isDisabled = fileName.hasSuffix(".disable")
        if isDisabled {
            guard fileName.hasSuffix(".disable") else {
                Logger.shared.error("启用资源失败：文件后缀不包含 .disable")
                return
            }
            targetFileName = String(fileName.dropLast(".disable".count))
        } else {
            targetFileName = fileName + ".disable"
        }

        let targetURL = resourceDir.appendingPathComponent(targetFileName)

        do {
            try fileManager.moveItem(at: currentURL, to: targetURL)
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
            GlobalErrorHandler.shared.handle(GlobalError.resource(
                chineseMessage: "切换资源状态失败：\(error.localizedDescription)",
                i18nKey: "error.resource.toggle_state_failed",
                level: .notification
            ))
        }
    }
}
