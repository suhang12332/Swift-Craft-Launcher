//
//  GameRepository.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// A repository that manages the persistence and retrieval of game version information.
///
/// `GameRepository` serves as the primary data access layer for game instances,
/// coordinating between the local SQLite database and the in-memory cache.
@MainActor
@Observable
class GameRepository {
    /// A dictionary of game instances keyed by their working path.
    private(set) var gamesByWorkingPath: [String: [GameVersionInfo]] = [:]

    /// A dictionary of corrupted game names keyed by their working path.
    ///
    /// A game is considered corrupted when its database record and local directory
    /// are inconsistent.
    private(set) var corruptedGamesByWorkingPath: [String: [String]] = [:]

    /// All working paths and their associated game counts from the database.
    private(set) var workingPathOptions: [(path: String, count: Int)] = []

    var games: [GameVersionInfo] {
        gamesByWorkingPath[currentWorkingPath] ?? []
    }

    /// The corrupted game names for the current working path.
    var corruptedGames: [String] {
        corruptedGamesByWorkingPath[currentWorkingPath] ?? []
    }

    private var currentWorkingPath: String {
        DIContainer.shared.ui.generalSettingsManager.currentWorkingPath
    }

    /// The backing store.
    ///
    /// `nonisolated` so database work can be performed off the main actor via
    /// `Task.detached`; `GameVersionDatabase` is safe to use from any thread.
    nonisolated let database: GameVersionDatabase
    private var lastWorkingPath: String = ""
    private var initialLoadTask: Task<Void, Never>?
    private var workspaceSwitchTask: Task<Void, Never>?
    private var hasLoadedInitialData = false

    var workingPathChanged: Bool = false

    /// Creates a game repository.
    init() {
        database = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)

        lastWorkingPath = currentWorkingPath

        observeWorkingPath()
    }

    private func initializeDatabase() async throws {
        let dataDir = AppPaths.dataDirectory
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        try database.initialize()
    }

    /// Reloads games whenever the configured working path changes.
    ///
    /// Uses Swift Observation (instead of a Combine subscription) to react to
    /// `GeneralSettingsManager.launcherWorkingDirectory`. The reload is debounced so
    /// that rapid edits coalesce into a single load; the path is re-read when the
    /// debounced work runs, so a change is never lost.
    private func observeWorkingPath() {
        let settingsManager = DIContainer.shared.ui.generalSettingsManager
        withObservationTracking {
            _ = settingsManager.launcherWorkingDirectory
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeWorkingPath()
                self?.scheduleWorkspaceSwitch()
            }
        }
    }

    private func scheduleWorkspaceSwitch() {
        let newPath = currentWorkingPath
        guard newPath != lastWorkingPath else { return }

        lastWorkingPath = newPath
        workspaceSwitchTask?.cancel()
        workspaceSwitchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                workingPathChanged = true
                try await loadGamesThrowing()
                if !Task.isCancelled {
                    await scanAllGamesModsDirectory()
                }
                workingPathChanged = false
            } catch {
                if !(error is CancellationError) {
                    DIContainer.shared.core.errorHandler.handle(error)
                }
                workingPathChanged = false
            }
        }
    }

    /// Loads initial data if it has not already been loaded.
    func loadInitialDataIfNeeded() async {
        if hasLoadedInitialData {
            return
        }
        if let initialLoadTask {
            await initialLoadTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await initializeDatabase()
                try await loadGamesThrowing()
                await scanAllGamesModsDirectory()
                await refreshWorkingPathOptions()
                hasLoadedInitialData = true
            } catch {
                DIContainer.shared.core.errorHandler.handle(error)
                gamesByWorkingPath = [:]
            }
        }

        initialLoadTask = task
        await task.value
        initialLoadTask = nil
    }

    /// Reloads all working paths and their game counts.
    func refreshWorkingPathOptions() async {
        let options = await fetchAllWorkingPathsWithCounts()
        workingPathOptions = options
    }

    func addGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.saveGame(gameToSave, workingPath: workingPath)
        }.value

        if gamesByWorkingPath[workingPath] == nil {
            gamesByWorkingPath[workingPath] = []
        }
        if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == game.id }) {
            gamesByWorkingPath[workingPath]?[index] = game
        } else {
            gamesByWorkingPath[workingPath]?.append(game)
        }

        AppLog.game.info("Successfully added game: \(game.gameName) (working path: \(workingPath))")
    }

    func deleteGame(id: String) async throws {
        let workingPath = currentWorkingPath
        guard let game = getGame(by: id) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.game_not_found_delete",
                level: .notification,
                message: "Game not found for deletion: id=\(id) in workingPath=\(workingPath)",
            )
        }
        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.deleteGame(id: id)
        }.value

        gamesByWorkingPath[workingPath]?.removeAll { $0.id == id }

        AppLog.game.info("Successfully deleted game: \(game.gameName) (working path: \(workingPath))")
    }

    /// Deletes all games with the specified name in the current working path.
    ///
    /// - Parameter gameName: The name of the games to delete.
    func deleteGamesByName(_ gameName: String) async throws {
        let workingPath = currentWorkingPath
        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.deleteGames(workingPath: workingPath, gameName: gameName)
        }.value

        gamesByWorkingPath[workingPath]?.removeAll { $0.gameName == gameName }
        corruptedGamesByWorkingPath[workingPath]?.removeAll { $0 == gameName }

        AppLog.game.info("Successfully deleted game record named \(gameName) (working path: \(workingPath))")
    }

    /// Renames a game by updating its profile directory and database record.
    func renameGame(id: String, to newName: String) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.game_not_found_status",
                level: .notification,
                message: "Game not found for rename: id=\(id)",
            )
        }

        let oldName = game.gameName
        guard oldName != newName else { return }

        let oldDir = AppPaths.profileDirectory(gameName: oldName)
        let newDir = AppPaths.profileDirectory(gameName: newName)

        guard !FileManager.default.fileExists(atPath: newDir.path) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.game_name_already_exists",
                level: .notification,
                message: "A game with the name '\(newName)' already exists",
            )
        }

        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.moveItem(at: oldDir, to: newDir)
        }.value

        game.gameName = newName
        try await updateGame(game)
        AppLog.game.info("Successfully renamed game from '\(oldName)' to '\(newName)'")
    }

    func getGame(by id: String) -> GameVersionInfo? {
        games.first { $0.id == id }
    }

    func updateGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.saveGame(gameToSave, workingPath: workingPath)
        }.value

        if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == game.id }) {
            gamesByWorkingPath[workingPath]?[index] = game
        } else {
            if gamesByWorkingPath[workingPath] == nil {
                gamesByWorkingPath[workingPath] = []
            }
            gamesByWorkingPath[workingPath]?.append(game)
        }

        AppLog.game.info("Successfully updated game: \(game.gameName) (working path: \(workingPath))")
    }

    private func scanAllGamesModsDirectory() async {
        let games = games
        AppLog.game.info("Starting scan of \(games.count) games mods directories")

        await withTaskGroup(of: Void.self) { group in
            for game in games {
                group.addTask {
                    await DIContainer.shared.core.modScanner.scanGameModsDirectory(game: game)
                }
            }
        }

        AppLog.game.info("Completed scan of all games mods directories")
    }

    /// Fetches all working paths with their game counts from the database.
    func fetchAllWorkingPathsWithCounts() async -> [(path: String, count: Int)] {
        let currentPath = currentWorkingPath
        let rows: [(path: String, count: Int)]
        do {
            rows = try await Task.detached(priority: .userInitiated) {
                try? self.database.initialize()
                return try self.database.loadWorkingPathsWithCounts()
            }.value
        } catch {
            return [(currentPath, 0)]
        }
        var result = rows
        if !result.contains(where: { $0.path == currentPath }) {
            result.append((currentPath, 0))
        }
        result.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return result
    }

    func loadGamesThrowing() async throws {
        let workingPath = currentWorkingPath

        let (validGames, corruptedNames, pathForLog): ([GameVersionInfo], [String], String) = try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            let games = try self.database.loadGames(workingPath: workingPath)
            let fm = FileManager.default
            let baseURL = URL(fileURLWithPath: workingPath, isDirectory: true)
            let profileRootDir = baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
            let localGameNames: Set<String>
            do {
                if fm.fileExists(atPath: profileRootDir.path) {
                    let contents = try fm.contentsOfDirectory(atPath: profileRootDir.path)
                    let filtered = contents.filter { !$0.hasPrefix(".") }
                    localGameNames = Set(filtered)
                } else {
                    localGameNames = []
                }
            } catch {
                AppLog.game.error("Unable to read game directory at working path: \(workingPath), error: \(error.localizedDescription)")
                localGameNames = []
            }
            let valid = games.filter { localGameNames.contains($0.gameName) }
            let dbGameNames = Set(games.map(\.gameName))
            let missingFolders = dbGameNames.subtracting(localGameNames)
            let missingDatabase = localGameNames.subtracting(dbGameNames)
            let corrupted = Array(missingFolders.union(missingDatabase)).sorted()
            return (valid, corrupted, workingPath)
        }.value

        gamesByWorkingPath[workingPath] = validGames
        corruptedGamesByWorkingPath[workingPath] = corruptedNames

        AppLog.game.info("Successfully loaded \(validGames.count) games (working path: \(pathForLog))")
    }
}
