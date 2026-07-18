//
//  GameAdvancedSettingsViewModel+Persistence.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Extension providing debounced auto-save persistence for advanced game settings.
extension GameAdvancedSettingsViewModel {
    func autoSave() {
        guard !isLoadingSettings, currentGame != nil else { return }
        saveTask?.cancel()

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            do {
                guard let repository = self.gameRepository else { return }
                guard let game = self.currentGame else { return }

                let xms = Int(self.memoryRange.lowerBound)
                let xmx = Int(self.memoryRange.upperBound)

                guard xms > 0, xmx > 0 else { return }
                guard xms <= xmx else { return }

                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
                updatedGame.jvmArguments = self.generateJvmArguments()
                updatedGame.environmentVariables = self.environmentVariables
                updatedGame.javaPath = self.javaPath

                try await repository.updateGame(updatedGame)
                AppLog.game.debug("Auto-saving game settings: \(game.gameName)")
            } catch {
                let globalError = error as? GlobalError ?? GlobalError.unknown(
                    i18nKey: "error.unknown.settings_save_failed",
                    level: .notification,
                )
                AppLog.game.error("Failed to auto-save game settings: \(globalError.localizedDescription)")
                await MainActor.run { self.error = globalError }
            }
        }
    }
}
