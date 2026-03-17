import Foundation
import SwiftUI

@MainActor
final class GameLocalResourceViewModel: ObservableObject {
    @Published private(set) var scannedResources: [ModrinthProjectDetail] = []
    @Published private(set) var isLoadingResources = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasLoaded = false
    @Published var error: GlobalError?

    private(set) var currentPage: Int = 1
    private(set) var hasMoreResults: Bool = true

    private var game: GameVersionInfo?
    private var query: String = ""
    private var localFilter: LocalResourceFilter = .all

    private var resourceDirectory: URL?
    private var allFiles: [URL] = []

    private var searchTask: Task<Void, Never>?
    private var searchGeneration: Int = 0
    private var currentSearchText: String = ""

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }

    var displayedResources: [ModrinthProjectDetail] { scannedResources }

    func onAppear(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter) {
        guard !hasLoaded else { return }
        hasLoaded = true
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = ""
        loadPage(page: 1, append: false, searchText: currentSearchText)
    }

    func onDisappear() {
        clearAllData()
    }

    func updateContextOnRefreshToken(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter, searchText: String) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = searchText
        loadPage(page: 1, append: false, searchText: currentSearchText)
    }

    func updateContextOnQueryChanged(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = ""
        loadPage(page: 1, append: false, searchText: currentSearchText)
    }

    func updateContextOnLocalFilterChanged(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter, searchText: String) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = searchText
        loadPage(page: 1, append: false, searchText: currentSearchText)
    }

    func onSearchTextChanged(_ newValue: String) {
        resetPagination()
        currentSearchText = newValue
        debounceSearch(searchText: newValue)
    }

    func loadNextPageIfNeeded(currentProjectId: String) {
        guard hasMoreResults, !isLoadingResources, !isLoadingMore else { return }
        guard let index = scannedResources.firstIndex(where: { $0.id == currentProjectId }) else { return }

        let thresholdIndex = max(scannedResources.count - 5, 0)
        if index >= thresholdIndex {
            currentPage += 1
            loadPage(page: currentPage, append: true, searchText: nil)
        }
    }

    func refreshResources() {
        refreshAllFiles()
        resetPagination()
        loadPage(page: 1, append: false, searchText: nil)
    }

    func handleLocalDisableStateChanged(projectId: String, oldFileName: String, isDisabled: Bool) {
        let newFileName: String = {
            if isDisabled { return oldFileName + ".disable" }
            return oldFileName.hasSuffix(".disable")
                ? String(oldFileName.dropLast(".disable".count))
                : oldFileName
        }()

        if let i = scannedResources.firstIndex(where: { $0.id == projectId }) {
            var d = scannedResources[i]
            d.fileName = newFileName
            scannedResources[i] = d
        }

        if let dir = currentResourceDirectory(),
           let j = allFiles.firstIndex(where: { $0.lastPathComponent == oldFileName }) {
            allFiles[j] = dir.appendingPathComponent(newFileName)
        }

        if localFilter == .disabled, !isDisabled {
            scannedResources.removeAll { $0.id == projectId }
        }
    }

    func handleResourceUpdated(projectId: String, oldFileName: String, newFileName: String, newHash: String?) {
        _ = newHash

        if let i = scannedResources.firstIndex(where: { $0.id == projectId }) {
            var d = scannedResources[i]
            d.fileName = newFileName
            scannedResources[i] = d
        }

        if let dir = currentResourceDirectory(),
           let j = allFiles.firstIndex(where: { $0.lastPathComponent == oldFileName }) {
            allFiles[j] = dir.appendingPathComponent(newFileName)
        }
    }

    // MARK: - Private

    private func applyContext(
        game: GameVersionInfo,
        query: String,
        localFilter: LocalResourceFilter,
        forceResetDirectory: Bool
    ) {
        self.game = game
        self.query = query
        self.localFilter = localFilter
        if forceResetDirectory { resourceDirectory = nil }
        initializeResourceDirectoryIfNeeded()
    }

    private func resetPagination() {
        currentPage = 1
        hasMoreResults = true
        isLoadingResources = false
        isLoadingMore = false
        error = nil
        scannedResources = []
        searchGeneration &+= 1
    }

    private func clearAllData() {
        searchTask?.cancel()
        searchTask = nil

        scannedResources = []
        isLoadingResources = false
        isLoadingMore = false
        error = nil
        currentPage = 1
        hasMoreResults = true
        hasLoaded = false
        resourceDirectory = nil
        allFiles = []
    }

    private func debounceSearch(searchText: String) {
        searchTask?.cancel()
        let generationAtSchedule = searchGeneration
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            guard generationAtSchedule == self.searchGeneration else { return }
            self.loadPage(page: 1, append: false, searchText: searchText)
        }
    }

    private var filesToScan: [URL] {
        switch localFilter {
        case .all:
            return allFiles
        case .disabled:
            return allFiles.filter { $0.lastPathComponent.hasSuffix(".disable") }
        }
    }

    private func initializeResourceDirectoryIfNeeded() {
        guard let game else { return }

        if let existingDir = resourceDirectory {
            let expectedDir = AppPaths.resourceDirectory(for: query, gameName: game.gameName)
            if existingDir == expectedDir { return }
            resourceDirectory = nil
        }

        resourceDirectory = AppPaths.resourceDirectory(for: query, gameName: game.gameName)

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

    private func currentResourceDirectory() -> URL? {
        if let resourceDirectory { return resourceDirectory }
        guard let game else { return nil }
        return AppPaths.resourceDirectory(for: query, gameName: game.gameName)
    }

    private func refreshAllFiles() {
        if query.lowercased() == ResourceType.modpack.rawValue {
            allFiles = []
            return
        }

        initializeResourceDirectoryIfNeeded()

        guard let resourceDir = currentResourceDirectory() else {
            allFiles = []
            return
        }

        allFiles = ModScanner.shared.getAllResourceFiles(resourceDir)
    }

    private func filterResourcesByTitle(_ details: [ModrinthProjectDetail], searchText: String) -> [ModrinthProjectDetail] {
        let queryLower = query.lowercased()
        let filteredByType = details.filter { detail in
            if detail.id.hasPrefix("local_") || detail.id.hasPrefix("file_") { return true }
            return detail.type?.lowercased() == queryLower
        }

        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchLower.isEmpty else { return filteredByType }
        return filteredByType.filter { $0.title.lowercased().contains(searchLower) }
    }

    /// - Parameter searchText: `nil` 表示使用 `currentSearchText`
    private func loadPage(page: Int, append: Bool, searchText: String?) {
        guard !isLoadingResources, !isLoadingMore else { return }

        if query.lowercased() == ResourceType.modpack.rawValue {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        let sourceFiles = filesToScan
        if sourceFiles.isEmpty {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        if append { isLoadingMore = true } else { isLoadingResources = true }
        error = nil

        let effectiveSearchText = searchText ?? currentSearchText
        let isSearching = !effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let generationAtStart = searchGeneration

        ModScanner.shared.scanResourceFilesPage(
            fileURLs: sourceFiles,
            page: page,
            pageSize: pageSize
        ) { [weak self] details, hasMore in
            DispatchQueue.main.async {
                guard let self else { return }
                guard generationAtStart == self.searchGeneration else { return }

                let filteredDetails = self.filterResourcesByTitle(details, searchText: effectiveSearchText)

                if append {
                    let existingIds = Set(self.scannedResources.map { $0.id })
                    let newDetails = filteredDetails.filter { !existingIds.contains($0.id) }
                    self.scannedResources.append(contentsOf: newDetails)
                } else {
                    self.scannedResources = filteredDetails
                }

                if isSearching && hasMore {
                    self.isLoadingResources = false
                    self.isLoadingMore = false
                    let nextPage = page + 1
                    self.currentPage = nextPage
                    self.loadPage(page: nextPage, append: true, searchText: effectiveSearchText)
                } else {
                    self.hasMoreResults = hasMore
                    self.isLoadingResources = false
                    self.isLoadingMore = false
                }
            }
        }
    }
}

