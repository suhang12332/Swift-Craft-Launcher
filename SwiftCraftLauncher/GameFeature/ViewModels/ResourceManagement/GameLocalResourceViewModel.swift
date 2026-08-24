//
//  GameLocalResourceViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import SwiftUI

/// View model that manages paginated loading, search, and filtering of local game resources.
@MainActor
@Observable
final class GameLocalResourceViewModel {
    private(set) var scannedResources: [ModrinthProjectDetail] = []
    private(set) var isLoadingResources = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false

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
    private var suppressNextFileRefresh = false

    private static let pageSize: Int = 20
    private var pageSize: Int { Self.pageSize }

    var displayedResources: [ModrinthProjectDetail] { scannedResources }

    init() { }

    func onDisappear() {
        clearAllData()
    }

    func updateContextOnRefreshToken(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter, searchText: String) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = searchText
        Task { await loadPage(page: 1, append: false, searchText: currentSearchText) }
    }

    func updateContextOnQueryChanged(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = ""
        Task { await loadPage(page: 1, append: false, searchText: currentSearchText) }
    }

    func updateContextOnLocalFilterChanged(game: GameVersionInfo, query: String, localFilter: LocalResourceFilter, searchText: String) {
        applyContext(game: game, query: query, localFilter: localFilter, forceResetDirectory: true)
        refreshAllFiles()
        resetPagination()
        currentSearchText = searchText
        Task { await loadPage(page: 1, append: false, searchText: currentSearchText) }
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
            Task { await loadPage(page: currentPage, append: true, searchText: nil) }
        }
    }

    func refreshResources() {
        if suppressNextFileRefresh {
            suppressNextFileRefresh = false
            return
        }
        refreshAllFiles()
        resetPagination()
        Task { await loadPage(page: 1, append: false, searchText: nil) }
    }

    func handleLocalDisableStateChanged(projectId: String, oldFileName: String, isDisabled: Bool) {
        suppressNextFileRefresh = true
        let newFileName: String = {
            if isDisabled {
                return oldFileName + ".disable"
            }
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
        suppressNextFileRefresh = true
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

    private func applyContext(
        game: GameVersionInfo,
        query: String,
        localFilter: LocalResourceFilter,
        forceResetDirectory: Bool,
    ) {
        self.game = game
        self.query = query
        self.localFilter = localFilter
        if forceResetDirectory {
            resourceDirectory = nil
        }
        initializeResourceDirectoryIfNeeded()
    }

    private func resetPagination() {
        currentPage = 1
        hasMoreResults = true
        isLoadingResources = false
        isLoadingMore = false
        scannedResources = []
        searchGeneration &+= 1
    }

    private func clearAllData() {
        searchTask?.cancel()
        searchTask = nil

        scannedResources = []
        isLoadingResources = false
        isLoadingMore = false
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
            guard generationAtSchedule == searchGeneration else { return }
            await loadPage(page: 1, append: false, searchText: searchText)
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

        if query.lowercased() == ResourceType.minecraftJavaServer.rawValue {
            return
        }

        if let existingDir = resourceDirectory {
            let expectedDir = AppPaths.resourceDirectory(for: query, gameName: game.gameName)
            if existingDir == expectedDir {
                return
            }
            resourceDirectory = nil
        }

        resourceDirectory = AppPaths.resourceDirectory(for: query, gameName: game.gameName)

        if resourceDirectory == nil {
            let globalError = GlobalError.configuration(
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification,
            )
            AppLog.game.error("Failed to initialize resource directory: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    private func currentResourceDirectory() -> URL? {
        if let resourceDirectory {
            return resourceDirectory
        }
        guard let game else { return nil }
        return AppPaths.resourceDirectory(for: query, gameName: game.gameName)
    }

    private func refreshAllFiles() {
        if query.lowercased() == ResourceType.modpack.rawValue {
            allFiles = []
            return
        }

        if query.lowercased() == ResourceType.minecraftJavaServer.rawValue {
            allFiles = []
            return
        }

        initializeResourceDirectoryIfNeeded()

        guard let resourceDir = currentResourceDirectory() else {
            allFiles = []
            return
        }

        do {
            allFiles = try DIContainer.shared.core.modScanner.getAllResourceFilesThrowing(resourceDir)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to get resource file list: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            allFiles = []
        }
    }

    private func filterResourcesByTitle(_ details: [ModrinthProjectDetail], searchText: String) -> [ModrinthProjectDetail] {
        let queryLower = query.lowercased()
        let filteredByType = details.filter { detail in
            if detail.id.hasPrefix("local_") || detail.id.hasPrefix("file_") {
                return true
            }
            return detail.type?.lowercased() == queryLower
        }

        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchLower.isEmpty else { return filteredByType }
        return filteredByType.filter { $0.title.lowercased().contains(searchLower) }
    }

    private func loadPage(page: Int, append: Bool, searchText: String?) async {
        guard !isLoadingResources, !isLoadingMore else { return }

        if query.lowercased() == ResourceType.modpack.rawValue {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        if query.lowercased() == ResourceType.minecraftJavaServer.rawValue {
            loadServers(searchText: searchText)
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

        if append {
            isLoadingMore = true
        } else {
            isLoadingResources = true
        }

        let effectiveSearchText = searchText ?? currentSearchText
        let isSearching = !effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let generationAtStart = searchGeneration

        let (details, hasMore): ([ModrinthProjectDetail], Bool)
        do {
            (details, hasMore) = try await DIContainer.shared.core.modScanner.scanResourceFilesPageThrowing(
                fileURLs: sourceFiles,
                page: page,
                pageSize: pageSize,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to scan resource files (paged): \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            (details, hasMore) = ([], false)
        }

        guard generationAtStart == searchGeneration else { return }

        let filteredDetails = filterResourcesByTitle(details, searchText: effectiveSearchText)

        if append {
            let existingIds = Set(scannedResources.map(\.id))
            let newDetails = filteredDetails.filter { !existingIds.contains($0.id) }
            scannedResources.append(contentsOf: newDetails)
        } else {
            scannedResources = filteredDetails
        }

        if isSearching, hasMore {
            isLoadingResources = false
            isLoadingMore = false
            let nextPage = page + 1
            currentPage = nextPage
            await loadPage(page: nextPage, append: true, searchText: effectiveSearchText)
        } else {
            hasMoreResults = hasMore
            isLoadingResources = false
            isLoadingMore = false
        }
    }

    private func loadServers(searchText: String? = nil) {
        guard let game else {
            scannedResources = []
            isLoadingResources = false
            isLoadingMore = false
            hasMoreResults = false
            return
        }

        isLoadingResources = true

        Task {
            do {
                let loadedServers = try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: game.gameName)
                let details = loadedServers.map {
                    ModrinthProjectDetail.fromServer($0, info: nil, status: .checking)
                }
                let searchLower = (searchText ?? currentSearchText).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                scannedResources = searchLower.isEmpty ? details : details.filter { $0.title.lowercased().contains(searchLower) }
                hasMoreResults = false
                checkServerStatuses(loadedServers)
            } catch {
                scannedResources = []
            }
            isLoadingResources = false
            isLoadingMore = false
        }
    }

    /// Checks connection status for all servers concurrently and updates the displayed details.
    private func checkServerStatuses(_ servers: [ServerAddress]) {
        guard !servers.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: (ServerAddress, ServerConnectionStatus, MinecraftServerInfo?).self) { group in
                for server in servers {
                    group.addTask {
                        let status = await NetworkUtils.checkServerConnectionStatus(
                            address: server.address,
                            port: server.port,
                            timeout: 5.0,
                        )
                        if case let .success(info) = status {
                            return (server, status, info)
                        }
                        return (server, status, nil)
                    }
                }

                for await (server, status, serverInfo) in group {
                    await MainActor.run {
                        self.applyServerResult(server: server, status: status, info: serverInfo)
                    }
                }
            }
        }
    }

    @MainActor
    private func applyServerResult(server: ServerAddress, status: ServerConnectionStatus, info: MinecraftServerInfo?) {
        guard let index = scannedResources.firstIndex(where: { $0.id == "server_\(server.id)" }) else { return }
        scannedResources[index] = ModrinthProjectDetail.fromServer(server, info: info, status: status)
    }
}
