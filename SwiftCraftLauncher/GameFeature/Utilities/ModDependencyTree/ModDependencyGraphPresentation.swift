//
//  ModDependencyGraphPresentation.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension WindowManager {
    /// Opens the auxiliary dependency graph window for `game`.
    ///
    /// The window is only opened when the mods directory contains at least one
    /// mod; otherwise an error is shown immediately.
    func presentModDependencyGraph(for game: GameVersionInfo) {
        Task {
            do {
                let files = try await LocalModScanner().fileLister(
                    AppPaths.modsDirectory(gameName: game.gameName),
                )
                guard !files.isEmpty else {
                    DIContainer.shared.core.errorHandler.handle(ModDependencyGraphService.noModsError())
                    return
                }

                preparePayload(
                    ModDependencyGraphWindowPayload(game: game),
                    for: .modDependencyGraph,
                )
                openWindow(id: .modDependencyGraph)
            } catch {
                let globalError = GlobalError.from(error)
                if globalError.i18nKey == "error.resource.directory_not_found" {
                    DIContainer.shared.core.errorHandler.handle(ModDependencyGraphService.noModsError())
                } else {
                    DIContainer.shared.core.errorHandler.handle(globalError)
                }
            }
        }
    }
}
