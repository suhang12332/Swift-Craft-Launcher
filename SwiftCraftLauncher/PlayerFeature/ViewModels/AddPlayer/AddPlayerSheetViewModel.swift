//
//  AddPlayerSheetViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Manages the state for the add-player sheet.
@MainActor
@Observable
final class AddPlayerSheetViewModel {
    var selectedAuthType: AccountAuthType = .premium

    /// A Boolean value indicating whether the premium account flag check is in progress.
    var isCheckingFlag: Bool = true
    /// Whether the user's IP is detected as non-domestic (foreign), checked when no premium flag exists.
    var isForeignIP: Bool = false

    init() { }

    /// Resets all selection state.
    func reset() {
        selectedAuthType = .premium
        isCheckingFlag = true
        isForeignIP = false
    }

    /// Starts the premium (Microsoft) authentication flow.
    func startPremiumAuthentication(authService: MinecraftAuthService) async {
        await authService.startAuthentication()
    }

    /// Starts the Yggdrasil authentication flow.
    func startYggdrasilAuthentication(yggdrasilAuthService: YggdrasilAuthService) async {
        await yggdrasilAuthService.startAuthentication()
    }

    /// Checks whether a premium account flag exists and detects foreign IP if not.
    func checkPremiumAccountFlag() async {
        let hasFlag = DIContainer.shared.system.premiumAccountFlagManager.hasAddedPremiumAccount()

        if !hasFlag {
            let foreign = await DIContainer.shared.system.ipLocationService.isForeignIP()
            isForeignIP = foreign
        }

        isCheckingFlag = false

        if !availableAuthTypes.contains(selectedAuthType) {
            selectedAuthType = .premium
        }
    }

    /// The authentication types available to the user based on settings and flags.
    var availableAuthTypes: [AccountAuthType] {
        var types: [AccountAuthType] = [.premium]

        let canAdd = canAddOfflineAccount()
        guard canAdd else { return types }

        if DIContainer.shared.ui.playerSettingsManager.enableOfflineLogin {
            types.append(.yggdrasil)
        }

        types.append(.offline)
        return types
    }

    private func canAddOfflineAccount() -> Bool {
        if DIContainer.shared.system.premiumAccountFlagManager.hasAddedPremiumAccount() {
            return true
        }
        return !isForeignIP
    }
}
