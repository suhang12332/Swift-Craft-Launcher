//
//  CategoryContentViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Loads and organizes category, version, and loader data for filtering.
@MainActor
final class CategoryContentViewModel: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published private(set) var features: [Category] = []
    @Published private(set) var resolutions: [Category] = []
    @Published private(set) var performanceImpacts: [Category] = []
    @Published private(set) var versions: [GameVersion] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var error: GlobalError?
    @Published private(set) var loaders: [Loader] = []
    @Published private(set) var plays: [Category] = []
    @Published private(set) var metas: [Category] = []
    @Published private(set) var serverFeatures: [Category] = []
    @Published private(set) var communitys: [Category] = []

    private let project: String
    private var loadTask: Task<Void, Never>?

    init(project: String) {
        self.project = project
    }

    deinit {
        loadTask?.cancel()
    }

    /// Loads categories, versions, and loaders from the API or cache.
    func loadData() async {
        loadTask?.cancel()
        loadTask = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            await fetchData()
        }
    }

    /// Cancels loading and resets all cached data.
    func clearCache() {
        loadTask?.cancel()
        loadTask = nil
        resetData()
    }

    /// Sets the current error value.
    func setError(_ error: GlobalError?) {
        self.error = error
    }

    private func fetchData() async {
        isLoading = true
        error = nil

        do {
            async let categoriesTask = ModrinthService.fetchCategories()
            async let versionsTask = ModrinthService.fetchGameVersions()

            let loadersTask: Task<[Loader], Never>
            if project == ProjectType.shader {
                loadersTask = Task {
                    await ModrinthService.fetchLoaders()
                }
            } else {
                loadersTask = Task {
                    Self.getStaticLoaders()
                }
            }

            let (categoriesResult, versionsResult, loadersResult) = await (
                categoriesTask, versionsTask, loadersTask.value
            )

            try Task.checkCancellation()

            guard !categoriesResult.isEmpty else {
                throw GlobalError.resource(
                    i18nKey: "error.resource.categories_not_found",
                    level: .notification,
                    message: "ModrinthService.fetchCategories() returned empty for project='\(project)'",
                )
            }

            guard !versionsResult.isEmpty else {
                throw GlobalError.resource(
                    i18nKey: "error.resource.game_versions_not_found",
                    level: .notification,
                    message: "ModrinthService.fetchGameVersions() returned empty for project='\(project)'",
                )
            }

            await processFetchedData(
                categories: categoriesResult,
                versions: versionsResult,
                loaders: loadersResult,
            )
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private static func getStaticLoaders() -> [Loader] {
        [
            Loader(
                name: GameLoader.fabric.displayName,
                icon: GameLoader.fabric.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue],
            ),
            Loader(
                name: GameLoader.forge.displayName,
                icon: GameLoader.forge.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue],
            ),
            Loader(
                name: GameLoader.quilt.rawValue,
                icon: GameLoader.quilt.rawValue,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue],
            ),
            Loader(
                name: GameLoader.neoforge.displayName,
                icon: GameLoader.neoforge.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue],
            ),
        ]
    }

    private func processFetchedData(
        categories: [Category],
        versions: [GameVersion],
        loaders: [Loader],
    ) async {
        let projectType =
            project == ProjectType.datapack ? ProjectType.mod : project
        let filteredCategories = categories.filter {
            $0.project_type == projectType
        }

        await MainActor.run {
            self.versions = CommonUtil.versionsAtLeast(versions) { $0.version }
            self.categories = filteredCategories.filter {
                $0.header == CategoryHeader.categories
            }
            self.features = filteredCategories.filter {
                $0.header == CategoryHeader.features
            }
            self.resolutions = filteredCategories.filter {
                $0.header == CategoryHeader.resolutions
            }
            self.performanceImpacts = filteredCategories.filter {
                $0.header == CategoryHeader.performanceImpact
            }
            self.metas = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerMeta
            }
            self.serverFeatures = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerFeatures
            }
            self.plays = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerGameplay
            }
            self.communitys = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerCommunity
            }
            self.loaders = loaders
        }
    }

    private func handleError(_ error: Error) {
        let globalError = GlobalError.from(error)
        AppLog.resource.error("Error loading category data: \(globalError.localizedDescription)")
        DIContainer.shared.core.errorHandler.handle(globalError)
        Task { @MainActor in
            self.error = globalError
        }
    }

    private func resetData() {
        categories.removeAll(keepingCapacity: false)
        features.removeAll(keepingCapacity: false)
        resolutions.removeAll(keepingCapacity: false)
        performanceImpacts.removeAll(keepingCapacity: false)
        versions.removeAll(keepingCapacity: false)
        loaders.removeAll(keepingCapacity: false)
        error = nil
        isLoading = false
    }
}
