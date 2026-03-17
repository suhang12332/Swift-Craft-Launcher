import Foundation

extension GameCreationViewModel {
    // MARK: - Game Save Methods

    func saveGame() async {
        guard let gameRepository = gameRepository,
              let playerListViewModel = playerListViewModel else {
            Logger.shared.error("GameRepository 或 PlayerListViewModel 未设置")
            return
        }

        // 对于非vanilla加载器，如果没有选择版本，则不允许保存
        let loaderVersion = selectedModLoader == "vanilla" ? selectedModLoader : selectedLoaderVersion

        var finalGameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalGameName.isEmpty {
            finalGameName = GameNameGenerator.generateGameName(
                gameVersion: selectedGameVersion,
                loaderVersion: loaderVersion,
                modLoader: selectedModLoader
            )
            gameNameValidator.gameName = finalGameName
        }

        await gameSetupService.saveGame(
            gameName: finalGameName,
            gameIcon: gameIcon,
            selectedGameVersion: selectedGameVersion,
            selectedModLoader: selectedModLoader,
            specifiedLoaderVersion: loaderVersion,
            pendingIconData: pendingIconData,
            playerListViewModel: playerListViewModel,
            gameRepository: gameRepository,
            onSuccess: {
                Task { @MainActor in
                    self.configuration.actions.onCancel()
                }
            },
            onError: { error, message in
                Task { @MainActor in
                    self.handleNonCriticalError(error, message: message)
                }
            }
        )
    }
}