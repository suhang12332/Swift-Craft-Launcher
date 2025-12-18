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

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }

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
                resetPagination()
                loadPage(page: 1, append: false)
            }
        }
        .onChange(of: refreshToken) { _, _ in
            resetPagination()
            loadPage(page: 1, append: false)
        }
        .onChange(of: searchTextForResource) { _, _ in
            // 仅影响前端过滤，本地资源分页仍按文件顺序
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
    @ViewBuilder
    private var listContent: some View {
        let filteredResources = scannedResources
            .filter { res in
                searchTextForResource.isEmpty
                    || res.title.localizedCaseInsensitiveContains(
                        searchTextForResource
                    )
            }

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
            VStack(spacing: 8) {
                Text("暂无本地资源")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
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
                ) {
                    // 本地资源这里不需要重新扫描，保留空闭包以兼容接口
                }
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

        guard
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: game.gameName
            )
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法获取资源目录路径",
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification
            )
            Logger.shared.error("扫描资源失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            error = globalError
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
        ModScanner.shared.scanResourceDirectoryPage(
            resourceDir,
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

        let thresholdIndex = max(scannedResources.count - 5, 0)
        if index >= thresholdIndex {
            currentPage += 1
            let nextPage = currentPage
            loadPage(page: nextPage, append: true)
        }
    }
}
