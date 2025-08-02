import SwiftUI

// MARK: - Main View
struct ModrinthDetailView: View {
    // MARK: - Properties
    let query: String
    @Binding var currentPage: Int
    @Binding var totalItems: Int
    @Binding var sortIndex: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoader: [String]
    let gameInfo: GameVersionInfo?
    @Binding var selectedItem: SidebarItem

    @StateObject private var viewModel = ModrinthSearchViewModel()
    @State private var hasLoaded = false
    @State private var searchText: String = ""
    @State private var searchTimer: Timer? = nil
    @Binding var gameType: Bool
    @State private var lastSearchKey: String = ""
    @State private var lastSearchParams: String = ""
    @State private var error: GlobalError?

    private var searchKey: String {
        [
            query,
            sortIndex,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(currentPage),
            String(gameType)
        ].joined(separator: "|")
    }

    // MARK: - Body
    var body: some View {
        LazyVStack {
            if let error = error {
                ErrorView(error)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.results.isEmpty {
                EmptyResultView()
            } else {
                resultList
            }
        }
        .task { if gameType {
            await initialLoadIfNeeded()
        } }
        .onChange(of: searchKey) { _, newKey in
            if newKey != lastSearchKey {
                lastSearchKey = newKey
                triggerSearch()
            }
        }
        .onChange(of: viewModel.totalHits) { _, newValue in totalItems = newValue }
        .searchable(text: $searchText)
        .onChange(of: searchText) { _, _ in
            debounceSearch()
        }
        .alert("error.notification.search.title".localized(), isPresented: .constant(error != nil)) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
    }

    // MARK: - Private Methods
    private func initialLoadIfNeeded() async {
        if !hasLoaded {
            hasLoaded = true
            await performSearchWithErrorHandling()
        }
    }

    private func triggerSearch() {
        Task { await performSearchWithErrorHandling() }
    }

    private func resetPageAndSearch() {
        currentPage = 1
        triggerSearch()
    }

    private func debounceSearch() {
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { _ in
            Task { await performSearchWithErrorHandling() }
        }
    }

    private func performSearchWithErrorHandling() async {
        do {
            try await performSearchThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            await MainActor.run {
                self.error = globalError
            }
        }
    }

    private func performSearchThrowing() async throws {
        let params = [
            query,
            sortIndex,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(currentPage),
            String(gameType),
            searchText
        ].joined(separator: "|")
        
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
        await viewModel.search(
            projectType: query,
            page: currentPage,
            query: searchText,
            sortIndex: sortIndex,
            versions: selectedVersions,
            categories: selectedCategories,
            features: selectedFeatures,
            resolutions: selectedResolutions,
            performanceImpact: selectedPerformanceImpact,
            loaders: selectedLoader
        )
    }

    // MARK: - Result List
    private var resultList: some View {
        ForEach(viewModel.results, id: \.projectId) { mod in
            ModrinthDetailCardView(
                project: mod,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoader,
                gameInfo: gameInfo,
                query: query,
                type: true,
                selectedItem: $selectedItem
            )
            .padding(.vertical, ModrinthConstants.UI.verticalPadding)
            .listRowInsets(
                EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            )
            .onTapGesture {
                selectedProjectId = mod.projectId
                if let type = ResourceType(rawValue: query) {
                    selectedItem = .resource(type)
                }
            }
        }
    }
}
