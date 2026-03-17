import Foundation

extension ModrinthSearchViewModel {
    // MARK: - Private Methods
    func buildFacets(
        projectType: String,
        versions: [String],
        categories: [String],
        features: [String],
        filterOptions: FilterOptions
    ) -> [[String]] {
        var facets: [[String]] = []

        // Project type is always required
        facets.append([
            "\(ModrinthConstants.API.FacetType.projectType):\(projectType)"
        ])

        // Add versions if any
        if !versions.isEmpty {
            facets.append(
                versions.map {
                    "\(ModrinthConstants.API.FacetType.versions):\($0)"
                }
            )
        }

        // Add categories if any
        if !categories.isEmpty {
            facets.append(
                categories.map {
                    "\(ModrinthConstants.API.FacetType.categories):\($0)"
                }
            )
        }

        // Handle client_side and server_side based on features selection
        let (clientFacets, serverFacets) = buildEnvironmentFacets(features: features)
        if !clientFacets.isEmpty {
            facets.append(clientFacets)
        }
        if !serverFacets.isEmpty {
            facets.append(serverFacets)
        }

        // Add resolutions if any (as categories)
        if !filterOptions.resolutions.isEmpty {
            facets.append(filterOptions.resolutions.map { "categories:\($0)" })
        }

        // Add performance impact if any (as categories)
        if !filterOptions.performanceImpact.isEmpty {
            facets.append(filterOptions.performanceImpact.map { "categories:\($0)" })
        }

        // Add loaders if any (as categories)
        if !filterOptions.loaders.isEmpty && projectType != ResourceType.resourcepack.rawValue
            && projectType != ResourceType.datapack.rawValue {
            var loadersToUse = filterOptions.loaders
            if let first = filterOptions.loaders.first, first.lowercased() == "vanilla" {
                loadersToUse = ["minecraft"]
            }
            facets.append(loadersToUse.map { "categories:\($0)" })
        }

        return facets
    }

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
