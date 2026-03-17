import Foundation

extension SkinToolDetailViewModel {
    // MARK: - Apply & Reset

    func resetSkin(resolvedPlayer: Player?) {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        resetSkinTask?.cancel()
        resetSkinTask = Task {
            do {
                let success = await PlayerSkinService.resetSkinAndRefresh(player: player)
                try Task.checkCancellation()

                self.operationInProgress = false
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

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
                if skinSuccess && capeSuccess {
                    onAllSuccess()
                }
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

    func handleSkinChanges(player: Player) async -> Bool {
        do {
            try Task.checkCancellation()

            if let skinData = selectedSkinData {
                let result = await PlayerSkinService.uploadSkinAndRefresh(
                    imageData: skinData,
                    model: currentModel,
                    player: player
                )
                try Task.checkCancellation()
                if result {
                    Logger.shared.info("Skin upload successful with model: \(currentModel.rawValue)")
                } else {
                    Logger.shared.error("Skin upload failed")
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
            } else if originalModel == nil && currentModel != .classic {
                return false
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            Logger.shared.error("Skin changes error: \(error)")
            return false
        }
    }

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
                            self.playerProfile = newProfile
                            self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            self.updateHasChanges()
                        }
                    }
                    return result
                } else {
                    let result = await PlayerSkinService.hideCape(player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            self.playerProfile = newProfile
                            self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            self.updateHasChanges()
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
                headers = ["Authorization": "Bearer \(p.authAccessToken)"]
            } else {
                headers = nil
            }
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            let result = await PlayerSkinService.uploadSkin(
                imageData: data,
                model: currentModel,
                player: p
            )
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            return false
        } catch {
            Logger.shared.error("Failed to re-upload skin with new model: \(error)")
            return false
        }
    }
}