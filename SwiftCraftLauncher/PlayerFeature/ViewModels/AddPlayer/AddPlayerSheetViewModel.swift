//
//  AddPlayerSheetViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages the state for the add-player sheet.
@MainActor
final class AddPlayerSheetViewModel: ObservableObject {
    @Published var selectedAuthType: AccountAuthType = .premium

    /// A Boolean value indicating whether the premium account flag check is in progress.
    @Published var isCheckingFlag: Bool = true
    /// Whether the user's IP is detected as non-domestic (foreign), checked when no premium flag exists.
    @Published var isForeignIP: Bool = false

    private let playerSettings: PlayerSettingsManager
    private let premiumAccountFlagManager: PremiumAccountFlagManager
    private let ipLocationService: IPLocationService

    init(
        playerSettings: PlayerSettingsManager = AppServices.playerSettingsManager,
        premiumAccountFlagManager: PremiumAccountFlagManager = AppServices.premiumAccountFlagManager,
        ipLocationService: IPLocationService = AppServices.ipLocationService
    ) {
        self.playerSettings = playerSettings
        self.premiumAccountFlagManager = premiumAccountFlagManager
        self.ipLocationService = ipLocationService
    }

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
        let hasFlag = premiumAccountFlagManager.hasAddedPremiumAccount()

        if !hasFlag {
            let foreign = await ipLocationService.isForeignIP()
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

        if playerSettings.enableOfflineLogin {
            types.append(.yggdrasil)
        }

        types.append(.offline)
        return types
    }

    private func canAddOfflineAccount() -> Bool {
        if premiumAccountFlagManager.hasAddedPremiumAccount() {
            return true
        }
        return !isForeignIP
    }
}
