import Foundation

extension GameAdvancedSettingsViewModel {
    // MARK: - Persistence

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

                guard xms > 0 && xmx > 0 else { return }
                guard xms <= xmx else { return }

                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
                updatedGame.jvmArguments = self.generateJvmArguments()
                updatedGame.environmentVariables = self.environmentVariables
                updatedGame.javaPath = self.javaPath

                try await repository.updateGame(updatedGame)
                Logger.shared.debug("自动保存游戏设置: \(game.gameName)")
            } catch {
                let globalError = error as? GlobalError ?? GlobalError.unknown(
                    chineseMessage: "保存设置失败: \(error.localizedDescription)",
                    i18nKey: "error.unknown.settings_save_failed",
                    level: .notification
                )
                Logger.shared.error("自动保存游戏设置失败: \(globalError.chineseMessage)")
                await MainActor.run { self.error = globalError }
            }
        }
    }
}
