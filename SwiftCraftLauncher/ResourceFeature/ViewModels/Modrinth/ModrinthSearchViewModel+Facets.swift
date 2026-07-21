//
//  ModrinthSearchViewModel+Facets.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModrinthSearchViewModel {
    /// Builds facet arrays for a Modrinth search request.
    ///
    /// Facets are grouped by OR within each inner array and AND between arrays.
    /// - Parameters:
    ///   - projectType: The project type facet value.
    ///   - filterOptions: The user's current filter selections.
    /// - Returns: An array of facet groups suitable for the Modrinth API.
    func buildFacets(
        projectType: String,
        filterOptions: FilterOptions,
    ) -> [[String]] {
        var facets: [[String]] = []

        facets.append([
            "\(ModrinthConstants.API.FacetType.projectType):\(projectType)",
        ])

        if !filterOptions.versions.isEmpty {
            facets.append(
                filterOptions.versions.map {
                    "\(ModrinthConstants.API.FacetType.versions):\($0)"
                },
            )
        }

        if !filterOptions.categories.isEmpty {
            facets.append(
                filterOptions.categories.map {
                    "\(ModrinthConstants.API.FacetType.categories):\($0)"
                },
            )
        }

        let (clientFacets, serverFacets) = buildEnvironmentFacets(features: filterOptions.features)
        if !clientFacets.isEmpty {
            facets.append(clientFacets)
        }
        if !serverFacets.isEmpty {
            facets.append(serverFacets)
        }

        if !filterOptions.resolutions.isEmpty {
            facets.append(filterOptions.resolutions.map { "categories:\($0)" })
        }

        if !filterOptions.performanceImpact.isEmpty {
            facets.append(filterOptions.performanceImpact.map { "categories:\($0)" })
        }

        if !filterOptions.loaders.isEmpty, projectType != ResourceType.resourcepack.rawValue,
           projectType != ResourceType.datapack.rawValue {
            var loadersToUse = filterOptions.loaders
            if let first = filterOptions.loaders.first, first.lowercased() == GameLoader.vanilla.displayName {
                loadersToUse = ["minecraft"]
            }
            facets.append(loadersToUse.map { "categories:\($0)" })
        }

        return facets
    }

    /// Builds client and server environment facet arrays.
    /// - Parameter features: The list of selected environment features.
    /// - Returns: A tuple of client-side and server-side facet groups.
    func buildEnvironmentFacets(features: [String]) -> (
        clientFacets: [String], serverFacets: [String]
    ) {
        let hasClient = features.contains(AppConstants.EnvironmentTypes.client)
        let hasServer = features.contains(AppConstants.EnvironmentTypes.server)

        var clientFacets: [String] = []
        var serverFacets: [String] = []

        if hasClient {
            clientFacets.append("client_side:required")
        } else if hasServer {
            clientFacets.append("client_side:optional")
        }

        if hasServer {
            serverFacets.append("server_side:required")
        } else if hasClient {
            serverFacets.append("server_side:optional")
        }

        return (clientFacets, serverFacets)
    }
}
