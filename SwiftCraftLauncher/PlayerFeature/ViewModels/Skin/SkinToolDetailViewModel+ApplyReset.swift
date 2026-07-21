//
//  SkinToolDetailViewModel+ApplyReset.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension SkinToolDetailViewModel {
    /// Resets the player's skin to the default via the Minecraft API.
    ///
    /// - Parameter resolvedPlayer: The player whose skin should be reset.
    func resetSkin(resolvedPlayer: Player?) {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        resetSkinTask?.cancel()
        resetSkinTask = Task {
            do {
                _ = await PlayerSkinService.resetSkinAndRefresh(player: player)
                try Task.checkCancellation()

                self.operationInProgress = false
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

    /// Applies all pending skin and cape changes to the player's Minecraft profile.
    ///
    /// - Parameters:
    ///   - resolvedPlayer: The player to update.
    ///   - onAllSuccess: A closure called when both skin and cape changes succeed.
    func applyChanges(resolvedPlayer: Player?, onAllSuccess: @escaping () -> Void) {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        applyChangesTask?.cancel()
        applyChangesTask = Task {
            do {
                let skinSuccess = await self.handleSkinChanges(player: player)
                try Task.checkCancellation()
                let capeSuccess = await self.handleCapeChanges(player: player)
                try Task.checkCancellation()

                self.operationInProgress = false
                if skinSuccess, capeSuccess {
                    onAllSuccess()
                }
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

    /// Uploads or updates the skin based on the current selection.
    ///
    /// - Parameter player: The player whose skin should be updated.
    /// - Returns: `true` if the skin change was applied successfully.
    func handleSkinChanges(player: Player) async -> Bool {
        do {
            try Task.checkCancellation()

            if let skinData = selectedSkinData {
                let result = await PlayerSkinService.uploadSkinAndRefresh(
                    imageData: skinData,
                    model: currentModel,
                    player: player,
                )
                try Task.checkCancellation()
                if result {
                    persistSelectedSkinToLibrary()
                    let model = currentModel.rawValue
                    AppLog.player.info("Skin upload successful with model: \(model)")
                } else {
                    AppLog.player.error("Skin upload failed")
                }
                return result
            } else if let original = originalModel, currentModel != original {
                if let currentSkinInfo = publicSkinInfo, let skinURL = currentSkinInfo.skinURL {
                    let result = await uploadCurrentSkinWithNewModel(skinURL: skinURL, player: player)
                    try Task.checkCancellation()
                    return result
                } else {
                    return false
                }
            } else if originalModel == nil, currentModel != .classic {
                return false
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            AppLog.player.error("Skin changes error: \(error)")
            return false
        }
    }

    /// Updates the cape based on the current selection.
    ///
    /// - Parameter player: The player whose cape should be updated.
    /// - Returns: `true` if the cape change was applied successfully.
    func handleCapeChanges(player: Player) async -> Bool {
        do {
            try Task.checkCancellation()

            if selectedCapeId != currentActiveCapeId {
                try Task.checkCancellation()
                if let capeId = selectedCapeId {
                    let result = await PlayerSkinService.showCape(capeId: capeId, player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            playerProfile = newProfile
                            selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            updateHasChanges()
                        }
                    }
                    return result
                } else {
                    let result = await PlayerSkinService.hideCape(player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            playerProfile = newProfile
                            selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            updateHasChanges()
                        }
                    }
                    return result
                }
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }

    /// Downloads the current skin and re-uploads it with a new model variant.
    func uploadCurrentSkinWithNewModel(skinURL: String, player: Player) async -> Bool {
        do {
            try Task.checkCancellation()
            let p = playerWithCredentialIfNeeded(player) ?? player

            let httpsURL = skinURL.httpToHttps()

            guard let url = URL(string: httpsURL) else {
                return false
            }
            var headers: [String: String]?
            if !p.authAccessToken.isEmpty {
                headers = [APIClient.Header.authorization: APIClient.bearer(p.authAccessToken)]
            } else {
                headers = nil
            }
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            let result = await PlayerSkinService.uploadSkin(
                imageData: data,
                model: currentModel,
                player: p,
            )
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            return false
        } catch {
            AppLog.player.error("Failed to re-upload skin with new model: \(error)")
            return false
        }
    }

    /// Persists the selected skin to the skin library when history is enabled.
    private func persistSelectedSkinToLibrary() {
        guard DIContainer.shared.ui.playerSettingsManager.enableHistorySkinLibrary else { return }
        guard let selectedSkinData else { return }
        let originalFileName = selectedSkinPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        if let item = try? skinLibraryStore.saveSkin(
            data: selectedSkinData,
            model: currentModel,
            originalFileName: originalFileName,
        ) {
            selectedSkinPath = item.fileURL.path
        }
    }
}
