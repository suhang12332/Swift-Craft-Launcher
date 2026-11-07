//
//  ModDependencyGraphAppService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ModDependencyGraphKit

extension ModDependencyGraphProject {
    init(detail: ModrinthProjectDetail) {
        self.init(
            projectId: detail.id,
            title: detail.title,
            iconUrl: detail.iconUrl,
            isLocalFallback: detail.team == "local",
        )
    }
}

extension ModDependencyGraphVersion {
    init(version: ModrinthProjectDetailVersion) {
        self.init(
            dependencies: version.dependencies.map {
                Self.Dependency(
                    projectId: $0.projectId,
                    type: $0.dependencyType,
                )
            },
            files: version.files.map {
                Self.File(
                    sha1: $0.hashes.sha1,
                    isPrimary: $0.primary,
                )
            },
        )
    }
}

/// Connects the launcher's Modrinth data sources to the reusable graph kit.
enum ModDependencyGraphAppService {
    static func buildGraph(for game: GameVersionInfo) async throws -> ModDependencyGraph {
        do {
            return try await makeService().buildGraph(
                modsDirectory: AppPaths.modsDirectory(gameName: game.gameName),
            )
        } catch ModDependencyGraphService.Error.noMods {
            throw noModsError()
        }
    }

    static func makeService() -> ModDependencyGraphService {
        ModDependencyGraphService(scanner: makeScanner()) { projectId in
            guard let detail = try? await ModrinthService.fetchProjectDetailsThrowing(id: projectId) else {
                return nil
            }
            return ModDependencyGraphProject(detail: detail)
        }
    }

    static func makeScanner() -> ModDependencyGraphScanner {
        let logger: ModDependencyGraphScanner.LogHandler = { level, message in
            switch level {
            case .debug:
                AppLog.game.debug(message)
            case .error:
                AppLog.game.error(message)
            }
        }

        return ModDependencyGraphScanner(
            fileLister: { directory in
                try DIContainer.shared.core.modScanner.readJarZipFiles(from: directory)
            },
            detailProvider: { url in
                guard let resolved = try await DIContainer.shared.core.modScanner
                    .getModrinthProjectDetailWithHash(for: url)
                else {
                    return nil
                }
                return (ModDependencyGraphProject(detail: resolved.project), resolved.hash)
            },
            versionsProvider: { projectId in
                try await ModrinthService.fetchProjectVersionsThrowing(id: projectId)
                    .map(ModDependencyGraphVersion.init(version:))
            },
            maxConcurrentTasks: DIContainer.shared.ui.gameSettingsManager.concurrentDownloads,
            logger: logger,
        )
    }

    static func noModsError() -> GlobalError {
        GlobalError.validation(
            i18nKey: "mod.dependency_graph.empty.message",
            level: .popup,
        )
        .withTitleKey("mod.dependency_graph.empty.title")
    }
}
