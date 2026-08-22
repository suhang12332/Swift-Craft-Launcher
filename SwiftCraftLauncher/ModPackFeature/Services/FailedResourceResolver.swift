//
//  FailedResourceResolver.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Resolves failed modpack files and dependencies into `FailedModPackResource`s and
/// presents them for retry/skip, reporting results back to the caller.
@MainActor
enum FailedResourceResolver {
    static func makeFailedResources(
        from files: [ModrinthIndexFile],
        gameInfo: GameVersionInfo,
    ) async -> [FailedModPackResource] {
        await withTaskGroup(of: (Int, FailedModPackResource?).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    let resource = await makeFailedResource(from: file, gameInfo: gameInfo)
                    return (index, resource)
                }
            }

            var ordered: [(Int, FailedModPackResource?)] = []
            for await result in group {
                ordered.append(result)
            }
            return ordered.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    static func makeFailedResources(
        from dependencies: [ModrinthIndexProjectDependency],
        gameInfo: GameVersionInfo,
    ) async -> [FailedModPackResource] {
        await withTaskGroup(of: (Int, FailedModPackResource?).self) { group in
            for (index, dependency) in dependencies.enumerated() {
                group.addTask {
                    let resource = await makeFailedResource(from: dependency, gameInfo: gameInfo)
                    return (index, resource)
                }
            }

            var ordered: [(Int, FailedModPackResource?)] = []
            for await result in group {
                ordered.append(result)
            }
            return ordered.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    private static func makeFailedResource(
        from file: ModrinthIndexFile,
        gameInfo: GameVersionInfo,
    ) async -> FailedModPackResource? {
        let source = file.source ?? .modrinth
        let resourceType = AppPaths.resourceType(for: URL(fileURLWithPath: file.path))
            ?? ResourceType.mod.rawValue

        let projectDetail: ModrinthProjectDetail?
        switch source {
        case .curseforge:
            guard let projectId = file.curseForgeProjectId,
                  let cfDetail = try? await CurseForgeService.fetchModDetailThrowing(modId: projectId) else {
                return nil
            }
            projectDetail = CFToModrinthAdapter.convertProjectDetail(cfDetail)
        case .modrinth:
            guard let sha1 = file.hashes.sha1 else { return nil }
            projectDetail = try? await ModrinthService.fetchModrinthDetailThrowing(by: sha1)
        case .mmc:
            // MMC packs don't have a centralized project API for resolution.
            return nil
        }

        guard let projectDetail else { return nil }
        return FailedModPackResource(
            projectDetail: projectDetail,
            resourceType: resourceType,
            gameInfo: gameInfo,
        )
    }

    private static func makeFailedResource(
        from dependency: ModrinthIndexProjectDependency,
        gameInfo: GameVersionInfo,
    ) async -> FailedModPackResource? {
        guard let projectId = dependency.projectId,
              let projectDetail = try? await ModrinthService.fetchProjectDetailsThrowing(id: projectId) else {
            return nil
        }
        return FailedModPackResource(
            projectDetail: projectDetail,
            resourceType: ResourceType.mod.rawValue,
            gameInfo: gameInfo,
        )
    }

    static func presentFailedResources(
        _ failedResources: [FailedModPackResource],
        input: ModPackInstallCoordinator.RunInput,
    ) async -> Bool {
        guard let onShowFailedResources = input.onShowFailedResources, !failedResources.isEmpty else {
            return failedResources.isEmpty
        }

        return await withCheckedContinuation { continuation in
            onShowFailedResources(failedResources) { handled in
                continuation.resume(returning: handled)
            }
        }
    }
}
