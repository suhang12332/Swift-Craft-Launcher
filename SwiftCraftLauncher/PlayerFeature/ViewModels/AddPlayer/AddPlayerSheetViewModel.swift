import Foundation

@MainActor
final class AddPlayerSheetViewModel: ObservableObject {
    @Published var selectedAuthType: AccountAuthType = .premium

    /// 标记检查 loading
    @Published var isCheckingFlag: Bool = true
    /// IP检查结果（仅在列表中没有正版账户且没有标记时使用）
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

    func reset() {
        selectedAuthType = .premium
        isCheckingFlag = true
        isForeignIP = false
    }

    func startPremiumAuthentication(authService: MinecraftAuthService) async {
        await authService.startAuthentication()
    }

    func startYggdrasilAuthentication(yggdrasilAuthService: YggdrasilAuthService) async {
        await yggdrasilAuthService.startAuthentication()
    }

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
