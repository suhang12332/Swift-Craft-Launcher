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
        guard !operationInProgress,
              let player = playerWithCredentialIfNeeded(resolvedPlayer) else { return }

        isResettingSkin = true
        resetSkinTask = Task {
            defer { self.isResettingSkin = false }

            let result = await PlayerSkinService.resetSkinAndRefresh(player: player)
            guard result.success, !Task.isCancelled else { return }
            self.applyResetState(skinInfo: result.skinInfo, player: player)
        }
    }

    /// Clears the pending selection and applies the refreshed skin state after a reset.
    private func applyResetState(
        skinInfo: PlayerSkinService.PublicSkinInfo?,
        player: Player,
    ) {
        deleteTemporarySkinFile()
        selectedSkinPath = nil
        selectedSkinData = nil
        selectedSkinImage = nil
        currentSkinRenderImage = nil

        publicSkinInfo = skinInfo
        currentModel = skinInfo?.model ?? .classic
        updateHasChanges()

        loadCurrentSkinRenderImageIfNeeded(resolvedPlayer: player)
    }

    /// Applies all pending skin and cape changes to the player's Minecraft profile.
    ///
    /// - Parameters:
    ///   - resolvedPlayer: The player to update.
    ///   - onAllSuccess: A closure called when both skin and cape changes succeed.
    func applyChanges(resolvedPlayer: Player?, onAllSuccess: @escaping () -> Void) {
        guard !operationInProgress,
              let player = playerWithCredentialIfNeeded(resolvedPlayer) else { return }

        isApplyingChanges = true
        applyChangesTask = Task {
            defer { self.isApplyingChanges = false }

            let skinSuccess = await self.handleSkinChanges(player: player)
            guard !Task.isCancelled else { return }

            let capeSuccess = await self.handleCapeChanges(player: player)
            guard !Task.isCancelled else { return }

            if skinSuccess, capeSuccess {
                onAllSuccess()
            }
        }
    }

    /// Uploads or updates the skin based on the current selection.
    ///
    /// - Parameter player: The player whose skin should be updated.
    /// - Returns: `true` if the skin change was applied successfully.
    func handleSkinChanges(player: Player) async -> Bool {
        let hasSkinChanges = PlayerSkinService.hasSkinChanges(
            selectedSkinData: selectedSkinData,
            currentModel: currentModel,
            originalModel: originalModel,
        )
        guard hasSkinChanges else { return true }

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
                }
                return result
            }

            guard let skinURL = publicSkinInfo?.skinURL else { return false }
            return await uploadCurrentSkinWithNewModel(skinURL: skinURL, player: player)
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
        guard selectedCapeId != currentActiveCapeId else { return true }

        do {
            try Task.checkCancellation()

            if let capeId = selectedCapeId {
                try await PlayerSkinService.showCapeThrowing(capeId: capeId, player: player)
            } else {
                try await PlayerSkinService.hideCapeThrowing(player: player)
            }

            try Task.checkCancellation()
            await refreshProfileAfterCapeChange(player: player)
            return true
        } catch is CancellationError {
            return false
        } catch {
            AppLog.player.error("Cape changes error: \(error)")
            return false
        }
    }

    /// Refreshes the cached profile and cape selection after a cape change.
    private func refreshProfileAfterCapeChange(player: Player) async {
        guard let newProfile = try? await PlayerSkinService.fetchPlayerProfileThrowing(player: player) else {
            return
        }

        playerProfile = newProfile
        selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
        updateHasChanges()
    }

    /// Downloads the current skin and re-uploads it with a new model variant.
    func uploadCurrentSkinWithNewModel(skinURL: String, player: Player) async -> Bool {
        do {
            try Task.checkCancellation()
            guard let url = URL(string: skinURL.httpToHttps()) else { return false }

            let accessToken = player.authAccessToken
            let headers: [String: String]? = accessToken.isEmpty
                ? nil
                : [APIClient.Header.authorization: APIClient.bearer(accessToken)]
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            try await PlayerSkinService.uploadSkinThrowing(
                imageData: data,
                model: currentModel,
                player: player,
            )
            return true
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
