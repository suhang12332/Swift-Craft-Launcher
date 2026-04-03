//
//  SwitchModLoaderSheetViewModel.swift
//  SwiftCraftLauncher
//
//  Created by Hongbro886 on 2026/4/3.
//

import SwiftUI

@MainActor
final class SwitchModLoaderSheetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedModLoader: String = ""
    @Published var selectedLoaderVersion: String = ""
    @Published var availableLoaderVersions: [String] = []
    @Published var isLoadingVersions = false
    @Published var isInstalling = false
    @Published var installProgress: (message: String, completed: Int, total: Int) = ("", 0, 0)
    @Published var installError: String?
    @Published var versionLoadError: String?

    // MARK: - Dependencies
    let gameInfo: GameVersionInfo
    private var gameRepository: GameRepository?

    // MARK: - Computed Properties
    var availableModLoaders: [String] {
        AppConstants.modLoaders.filter { $0 != GameLoader.vanilla.displayName }
    }

    var canInstall: Bool {
        !selectedModLoader.isEmpty &&
        !selectedLoaderVersion.isEmpty &&
        !isInstalling &&
        !isLoadingVersions
    }

    // MARK: - Initialization
    init(gameInfo: GameVersionInfo) {
        self.gameInfo = gameInfo
    }

    func setDependencies(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
    }

    // MARK: - Initialization Methods
    func initializeDefaultLoader() {
        if let firstLoader = availableModLoaders.first {
            selectedModLoader = firstLoader
        }
    }

    // MARK: - Data Loading
    func handleModLoaderChange(_ newLoader: String) {
        guard !newLoader.isEmpty else { return }

        Task {
            await loadLoaderVersions(for: newLoader)
        }
    }

    func loadLoaderVersions(for loader: String) async {
        isLoadingVersions = true
        availableLoaderVersions = []
        selectedLoaderVersion = ""
        versionLoadError = nil

        defer {
            isLoadingVersions = false
        }

        let gameVersion = gameInfo.gameVersion
        var versions: [String] = []
        var loadError: Error?

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map { $0.loader.version }
        case GameLoader.forge.displayName:
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map { $0.id }
            } catch {
                loadError = error
                Logger.shared.error("获取 Forge 版本失败: \(error.localizedDescription)")
            }
        case GameLoader.neoforge.displayName:
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map { $0.id }
            } catch {
                loadError = error
                Logger.shared.error("获取 NeoForge 版本失败: \(error.localizedDescription)")
            }
        case GameLoader.quilt.rawValue:
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map { $0.loader.version }
        default:
            break
        }

        availableLoaderVersions = versions
        if let firstVersion = versions.first {
            selectedLoaderVersion = firstVersion
        }

        // 如果版本列表为空，显示错误提示
        if versions.isEmpty {
            versionLoadError = String(format: "switch.modloader.no_versions_for_loader".localized(), getModLoaderDisplayName(loader), gameVersion)
        }
    }

    func getModLoaderDisplayName(_ loader: String) -> String {
        switch loader {
        case GameLoader.fabric.displayName:
            return "modloader.fabric.text".localized()
        case GameLoader.forge.displayName:
            return "modloader.forge.text".localized()
        case GameLoader.neoforge.displayName:
            return "modloader.neoforge.text".localized()
        case GameLoader.quilt.rawValue:
            return "modloader.quilt.text".localized()
        default:
            return loader.capitalized
        }
    }

    // MARK: - Helper Methods
    func getModLoaderHandler(for loader: String) -> (any ModLoaderHandler.Type)? {
        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            return FabricLoaderService.self
        case GameLoader.forge.displayName:
            return ForgeLoaderService.self
        case GameLoader.neoforge.displayName:
            return NeoForgeLoaderService.self
        case GameLoader.quilt.rawValue:
            return QuiltLoaderService.self
        default:
            return nil
        }
    }

    func fetchLoaderArguments(loader: String, gameVersion: String, loaderVersion: String) async throws -> (modJvm: [String], gameArguments: [String]) {
        var modJvm: [String] = []
        var gameArguments: [String] = []

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            if let fabricLoader = try? await FabricLoaderService.fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion) {
                modJvm = fabricLoader.arguments.jvm ?? []
                gameArguments = fabricLoader.arguments.game ?? []
            }
        case GameLoader.quilt.rawValue:
            if let quiltLoader = try? await QuiltLoaderService.fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion) {
                modJvm = quiltLoader.arguments.jvm ?? []
                gameArguments = quiltLoader.arguments.game ?? []
            }
        case GameLoader.forge.displayName:
            if let forgeLoader = try? await ForgeLoaderService.fetchSpecificForgeProfile(for: gameVersion, loaderVersion: loaderVersion) {
                gameArguments = forgeLoader.arguments.game ?? []
                let jvmArgs = forgeLoader.arguments.jvm ?? []
                modJvm = jvmArgs.map { arg in
                    arg.replacingOccurrences(of: "${version_name}", with: gameVersion)
                        .replacingOccurrences(of: "${classpath_separator}", with: ":")
                        .replacingOccurrences(of: "${library_directory}", with: AppPaths.librariesDirectory.path)
                }
            }
        case GameLoader.neoforge.displayName:
            if let neoForgeLoader = try? await NeoForgeLoaderService.fetchSpecificNeoForgeProfile(for: gameVersion, loaderVersion: loaderVersion) {
                gameArguments = neoForgeLoader.arguments.game ?? []
                let jvmArgs = neoForgeLoader.arguments.jvm ?? []
                modJvm = jvmArgs.map { arg -> String in
                    let mutableArg = NSMutableString(string: arg)
                    mutableArg.replaceOccurrences(
                        of: "${version_name}",
                        with: gameVersion,
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    mutableArg.replaceOccurrences(
                        of: "${classpath_separator}",
                        with: ":",
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    mutableArg.replaceOccurrences(
                        of: "${library_directory}",
                        with: AppPaths.librariesDirectory.path,
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    return mutableArg as String
                }
            }
        default:
            break
        }

        return (modJvm, gameArguments)
    }
}
