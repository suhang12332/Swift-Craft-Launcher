//
//  LocalModScanner.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Scans a game's `mods` directory and resolves every file to a lightweight local
/// record. Required dependency IDs are extracted immediately, so the full version
/// payload does not stay alive during graph construction.
struct LocalModScanner: Sendable {
    typealias FileLister = @Sendable (URL) async throws -> [URL]
    typealias DetailProvider = @Sendable (URL) async throws
        -> (project: ModrinthProjectDetail, hash: String)?
    typealias VersionsProvider = @Sendable (String) async throws -> [ModrinthProjectDetailVersion]

    let fileLister: FileLister
    let detailProvider: DetailProvider
    let versionsProvider: VersionsProvider
    let maxConcurrentTasks: Int

    init(
        fileLister: @escaping FileLister = { directory in
            try DIContainer.shared.core.modScanner.readJarZipFiles(from: directory)
        },
        detailProvider: @escaping DetailProvider = { url in
            try await DIContainer.shared.core.modScanner.getModrinthProjectDetailWithHash(for: url)
        },
        versionsProvider: @escaping VersionsProvider = { projectId in
            try await ModrinthService.fetchProjectVersionsThrowing(id: projectId)
        },
        maxConcurrentTasks: Int = DIContainer.shared.ui.gameSettingsManager.concurrentDownloads,
    ) {
        self.fileLister = fileLister
        self.detailProvider = detailProvider
        self.versionsProvider = versionsProvider
        self.maxConcurrentTasks = min(8, max(1, maxConcurrentTasks))
    }

    /// Scans all mod files of `game` and returns their resolved local records.
    func scan(game: GameVersionInfo) async throws -> [LocalMod] {
        let directory = AppPaths.modsDirectory(gameName: game.gameName)
        let files = try await fileLister(directory)

        let semaphore = AsyncSemaphore(value: maxConcurrentTasks)

        return await withTaskGroup(of: LocalMod?.self) { group in
            for file in files {
                group.addTask {
                    await semaphore.wait()
                    let mod = await scanFile(file)
                    await semaphore.signal()
                    return mod
                }
            }

            var results: [LocalMod] = []
            results.reserveCapacity(files.count)
            for await mod in group {
                if let mod {
                    results.append(mod)
                }
            }
            return results
        }
    }

    private func scanFile(_ fileURL: URL) async -> LocalMod? {
        let project: ModrinthProjectDetail
        let hash: String
        do {
            guard let resolved = try await detailProvider(fileURL) else {
                AppLog.game.debug("Skipping mod file without resolved detail: \(fileURL.lastPathComponent)")
                return nil
            }
            project = resolved.project
            hash = resolved.hash
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error(
                "Failed to resolve mod detail for \(fileURL.lastPathComponent): \(globalError.localizedDescription)",
            )
            return nil
        }

        var installedVersion: ModrinthProjectDetailVersion?

        // Fallback details use a synthetic `file_...` project ID and have no
        // remote version to query.
        if project.team != "local" {
            do {
                let versions = try await versionsProvider(project.id)
                installedVersion = ModDependencyGraphBuilder.installedVersion(
                    matching: hash,
                    in: versions,
                )
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.debug(
                    "Failed to resolve installed version for \(project.id): \(globalError.localizedDescription)",
                )
            }
        }

        return LocalMod(
            project: project,
            installedVersion: installedVersion,
            fileName: fileURL.lastPathComponent,
            isEnabled: !fileURL.lastPathComponent.lowercased().hasSuffix(".disable"),
        )
    }
}
