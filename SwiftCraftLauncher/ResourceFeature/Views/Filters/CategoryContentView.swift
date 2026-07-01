//
//  CategoryContentView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays category filter sections for a given project type.
struct CategoryContentView: View {
    let project: String
    @StateObject private var viewModel: CategoryContentViewModel
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpacts: [String]
    @Binding var selectedVersions: [String]
    @Binding var selectedLoaders: [String]
    let type: String
    let gameVersion: String?
    let gameLoader: String?
    let dataSource: DataSource
    private let errorHandler: GlobalErrorHandler

    init(
        project: String,
        type: String,
        selectedCategories: Binding<[String]>,
        selectedFeatures: Binding<[String]>,
        selectedResolutions: Binding<[String]>,
        selectedPerformanceImpacts: Binding<[String]>,
        selectedVersions: Binding<[String]>,
        selectedLoaders: Binding<[String]>,
        gameVersion: String? = nil,
        gameLoader: String? = nil,
        dataSource: DataSource,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.project = project
        self.type = type
        _selectedCategories = selectedCategories
        _selectedFeatures = selectedFeatures
        _selectedResolutions = selectedResolutions
        _selectedPerformanceImpacts = selectedPerformanceImpacts
        _selectedVersions = selectedVersions
        _selectedLoaders = selectedLoaders
        self.gameVersion = gameVersion
        self.gameLoader = gameLoader
        self.dataSource = dataSource
        self.errorHandler = errorHandler
        _viewModel = StateObject(
            wrappedValue: CategoryContentViewModel(project: project),
        )
    }

    var body: some View {
        VStack {
            if let error = viewModel.error {
                errorView(error)
            } else {
                if type == "resource" {
                    versionSection
                }
                if project != ProjectType.minecraftJavaServer {
                    categorySection
                }
                projectSpecificSections
            }
        }
        .task {
            await loadDataWithErrorHandling()
            setupDefaultSelections()
        }
        .onDisappear {
            viewModel.clearCache()
        }
    }

    private func setupDefaultSelections() {
        if let gameVersion {
            selectedVersions = [gameVersion]
        }
        if let gameLoader {
            if project != ResourceType.shader.rawValue {
                selectedLoaders = [gameLoader]
            } else {
                selectedLoaders = []
            }
        }
    }

    private func loadDataWithErrorHandling() async {
        do {
            try await loadDataThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.resource.error("Failed to load category data: \(globalError.localizedDescription)")
            errorHandler.handle(globalError)
            await MainActor.run {
                viewModel.setError(globalError)
            }
        }
    }

    private func loadDataThrowing() async throws {
        guard !project.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_type_empty",
                level: .notification,
                message: "project type parameter is empty",
            )
        }

        await viewModel.loadData()
    }

    private var categorySection: some View {
        CategorySectionView(
            title: "filter.category",
            items: viewModel.categories.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedCategories,
            isLoading: viewModel.isLoading,
        )
    }

    private var versionSection: some View {
        CategorySectionView(
            title: "filter.version",
            items: viewModel.versions.map {
                FilterItem(id: $0.id, name: $0.id)
            },
            selectedItems: $selectedVersions,
            isLoading: viewModel.isLoading,
            isVersionSection: true,
        )
    }

    private var loaderSection: some View {
        CategorySectionView(
            title: "filter.loader",
            items: filteredLoaders.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedLoaders,
            isLoading: viewModel.isLoading,
        )
    }

    private var projectSpecificSections: some View {
        Group {
            switch project {
            case ProjectType.modpack, ProjectType.mod:
                if type == "resource" {
                    loaderSection
                }
                environmentSection
            case ProjectType.minecraftJavaServer:
                serverMetaSection
                serverGameplaySection
                serverFeaturesSection
                serverCommunitySection
            case ProjectType.resourcepack:
                resourcePackSections
            case ProjectType.shader:
                if dataSource == .modrinth {
                    loaderSection
                }
                shaderSections
            default:
                EmptyView()
            }
        }
    }

    private var environmentSection: some View {
        CategorySectionView(
            title: "filter.environment",
            items: environmentItems,
            selectedItems: $selectedFeatures,
            isLoading: viewModel.isLoading,
        )
    }

    private var resourcePackSections: some View {
        Group {
            CategorySectionView(
                title: "filter.behavior",
                items: viewModel.features.map {
                    FilterItem(id: $0.name, name: $0.name)
                },
                selectedItems: $selectedFeatures,
                isLoading: viewModel.isLoading,
            )
            CategorySectionView(
                title: "filter.resolutions",
                items: viewModel.resolutions.map {
                    FilterItem(id: $0.name, name: $0.name)
                },
                selectedItems: $selectedResolutions,
                isLoading: viewModel.isLoading,
            )
        }
    }

    private var shaderSections: some View {
        Group {
            // CurseForge does not support performance impact filtering.
            if dataSource == .modrinth {
                CategorySectionView(
                    title: "filter.behavior",
                    items: viewModel.features.map {
                        FilterItem(id: $0.name, name: $0.name)
                    },
                    selectedItems: $selectedFeatures,
                    isLoading: viewModel.isLoading,
                )
                CategorySectionView(
                    title: "filter.performance",
                    items: viewModel.performanceImpacts.map {
                        FilterItem(id: $0.name, name: $0.name)
                    },
                    selectedItems: $selectedPerformanceImpacts,
                    isLoading: viewModel.isLoading,
                )
            }
        }
    }

    private var serverMetaSection: some View {
        CategorySectionView(
            title: "filter.server.meta",
            items: viewModel.metas.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedCategories,
            isLoading: viewModel.isLoading,
        )
    }

    private var serverGameplaySection: some View {
        CategorySectionView(
            title: "filter.server.gameplay",
            items: viewModel.plays.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedFeatures,
            isLoading: viewModel.isLoading,
        )
    }

    private var serverFeaturesSection: some View {
        CategorySectionView(
            title: "filter.server.features",
            items: viewModel.serverFeatures.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedResolutions,
            isLoading: viewModel.isLoading,
        )
    }

    private var serverCommunitySection: some View {
        CategorySectionView(
            title: "filter.server.community",
            items: viewModel.communitys.map {
                FilterItem(id: $0.name, name: $0.name)
            },
            selectedItems: $selectedPerformanceImpacts,
            isLoading: viewModel.isLoading,
        )
    }

    private var filteredLoaders: [Loader] {
        viewModel.loaders.filter {
            $0.supported_project_types.contains(project)
        }
    }

    private var environmentItems: [FilterItem] {
        [
            FilterItem(id: AppConstants.EnvironmentTypes.client, name: "environment.client".localized()),
            FilterItem(id: AppConstants.EnvironmentTypes.server, name: "environment.server".localized()),
        ]
    }
}
