import XCTest
@testable import SwiftCraftLauncher

final class ResourceFeatureExtendedTests: XCTestCase {

    // MARK: - CategoryModels

    func testFilterItem_init() {
        let item = FilterItem(id: "1", name: "Test")
        XCTAssertEqual(item.id, "1")
        XCTAssertEqual(item.name, "Test")
    }

    func testFilterItem_equatable() {
        let a = FilterItem(id: "1", name: "Test")
        let b = FilterItem(id: "1", name: "Test")
        XCTAssertEqual(a, b)
    }

    func testFilterItem_hashable() {
        let a = FilterItem(id: "1", name: "Test")
        let b = FilterItem(id: "1", name: "Test")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testProjectType_constants() {
        XCTAssertEqual(ProjectType.modpack, "modpack")
        XCTAssertEqual(ProjectType.mod, "mod")
        XCTAssertEqual(ProjectType.datapack, "datapack")
        XCTAssertEqual(ProjectType.resourcepack, "resourcepack")
        XCTAssertEqual(ProjectType.shader, "shader")
        XCTAssertEqual(ProjectType.minecraftJavaServer, "minecraft_java_server")
    }

    func testCategoryHeader_constants() {
        XCTAssertEqual(CategoryHeader.categories, "categories")
        XCTAssertEqual(CategoryHeader.features, "features")
        XCTAssertEqual(CategoryHeader.environment, "environment")
    }

    func testFilterTitle_constants() {
        XCTAssertEqual(FilterTitle.category, "filter.category")
        XCTAssertEqual(FilterTitle.environment, "filter.environment")
        XCTAssertEqual(FilterTitle.version, "filter.version")
    }

    // MARK: - ModrinthConstants

    func testModrinthConstants_UIConstants() {
        XCTAssertEqual(ModrinthConstants.UIConstants.pageSize, 20)
        XCTAssertEqual(ModrinthConstants.UIConstants.maxTags, 3)
        XCTAssertEqual(ModrinthConstants.UIConstants.descriptionLineLimit, 1)
    }

    func testModrinthConstants_FacetType() {
        XCTAssertEqual(ModrinthConstants.API.FacetType.projectType, "project_type")
        XCTAssertEqual(ModrinthConstants.API.FacetType.versions, "versions")
        XCTAssertEqual(ModrinthConstants.API.FacetType.categories, "categories")
        XCTAssertEqual(ModrinthConstants.API.FacetType.clientSide, "client_side")
        XCTAssertEqual(ModrinthConstants.API.FacetType.serverSide, "server_side")
    }

    func testModrinthConstants_FacetValue() {
        XCTAssertEqual(ModrinthConstants.API.FacetValue.required, "required")
        XCTAssertEqual(ModrinthConstants.API.FacetValue.optional, "optional")
        XCTAssertEqual(ModrinthConstants.API.FacetValue.unsupported, "unsupported")
    }

    // MARK: - FilterOptions

    func testFilterOptions_init() {
        let options = FilterOptions(
            resolutions: ["16x"],
            performanceImpact: ["low"],
            loaders: ["fabric"]
        )
        XCTAssertEqual(options.resolutions, ["16x"])
        XCTAssertEqual(options.performanceImpact, ["low"])
        XCTAssertEqual(options.loaders, ["fabric"])
    }

    // MARK: - SearchCachePayload

    func testSearchCachePayload_codable() throws {
        let payload = ModrinthSearchViewModel.SearchCachePayload(
            hits: [],
            totalHits: 0,
            updatedAt: Date()
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ModrinthSearchViewModel.SearchCachePayload.self, from: data)
        XCTAssertEqual(decoded.totalHits, 0)
        XCTAssertEqual(decoded.hits.count, 0)
    }

    // MARK: - SearchCacheContext

    func testSearchCacheContext_init() {
        let context = ModrinthSearchViewModel.SearchCacheContext(
            query: "test",
            projectType: "mod",
            versions: ["1.20.1"],
            categories: [],
            features: [],
            resolutions: [],
            performanceImpact: [],
            loaders: [],
            dataSource: .modrinth
        )
        XCTAssertEqual(context.query, "test")
        XCTAssertEqual(context.projectType, "mod")
        XCTAssertEqual(context.versions, ["1.20.1"])
    }

    // MARK: - buildEnvironmentFacets

    @MainActor
    func testBuildEnvironmentFacets_bothClientAndServer() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let (client, server) = vm.buildEnvironmentFacets(features: ["client", "server"])
        XCTAssertEqual(client, ["client_side:required"])
        XCTAssertEqual(server, ["server_side:required"])
    }

    @MainActor
    func testBuildEnvironmentFacets_clientOnly() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let (client, server) = vm.buildEnvironmentFacets(features: ["client"])
        XCTAssertEqual(client, ["client_side:required"])
        XCTAssertEqual(server, ["server_side:optional"])
    }

    @MainActor
    func testBuildEnvironmentFacets_serverOnly() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let (client, server) = vm.buildEnvironmentFacets(features: ["server"])
        XCTAssertEqual(client, ["client_side:optional"])
        XCTAssertEqual(server, ["server_side:required"])
    }

    @MainActor
    func testBuildEnvironmentFacets_empty() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let (client, server) = vm.buildEnvironmentFacets(features: [])
        XCTAssertTrue(client.isEmpty)
        XCTAssertTrue(server.isEmpty)
    }

    // MARK: - buildFacets

    @MainActor
    func testBuildFacets_projectTypeOnly() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let options = FilterOptions(resolutions: [], performanceImpact: [], loaders: [])
        let facets = vm.buildFacets(
            projectType: "mod",
            versions: [],
            categories: [],
            features: [],
            filterOptions: options
        )
        XCTAssertEqual(facets.count, 1)
        XCTAssertEqual(facets[0], ["project_type:mod"])
    }

    @MainActor
    func testBuildFacets_withVersions() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let options = FilterOptions(resolutions: [], performanceImpact: [], loaders: [])
        let facets = vm.buildFacets(
            projectType: "mod",
            versions: ["1.20.1", "1.19.4"],
            categories: [],
            features: [],
            filterOptions: options
        )
        XCTAssertEqual(facets.count, 2)
        XCTAssertTrue(facets[1].contains("versions:1.20.1"))
        XCTAssertTrue(facets[1].contains("versions:1.19.4"))
    }

    @MainActor
    func testBuildFacets_withCategories() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let options = FilterOptions(resolutions: [], performanceImpact: [], loaders: [])
        let facets = vm.buildFacets(
            projectType: "mod",
            versions: [],
            categories: ["technology"],
            features: [],
            filterOptions: options
        )
        XCTAssertEqual(facets.count, 2)
        XCTAssertTrue(facets[1].contains("categories:technology"))
    }

    @MainActor
    func testBuildFacets_resourcepack_excludesLoaders() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let options = FilterOptions(resolutions: [], performanceImpact: [], loaders: ["fabric"])
        let facets = vm.buildFacets(
            projectType: "resourcepack",
            versions: [],
            categories: [],
            features: [],
            filterOptions: options
        )
        // Loaders should not be added for resourcepack
        for facet in facets {
            XCTAssertFalse(facet.contains("categories:fabric"))
        }
    }

    @MainActor
    func testBuildFacets_vanillaLoader_mappedToMinecraft() {
        let vm = ModrinthSearchViewModel(errorHandler: GlobalErrorHandler.shared)
        let options = FilterOptions(resolutions: [], performanceImpact: [], loaders: ["vanilla"])
        let facets = vm.buildFacets(
            projectType: "mod",
            versions: [],
            categories: [],
            features: [],
            filterOptions: options
        )
        let loaderFacets = facets.first { $0.contains("categories:minecraft") }
        XCTAssertNotNil(loaderFacets)
    }
}
