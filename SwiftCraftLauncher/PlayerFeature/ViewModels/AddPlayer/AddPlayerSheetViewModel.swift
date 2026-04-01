import Foundation

@MainActor
final class AddPlayerSheetViewModel: ObservableObject {
    @Published var selectedAuthType: AccountAuthType = .premium

    /// 标记检查 loading
    @Published var isCheckingFlag: Bool = true
    /// IP检查结果（仅在列表中没有正版账户且没有标记时使用）
    @Published var isForeignIP: Bool = false

    private let playerSettings: PlayerSettingsManager

    init(playerSettings: PlayerSettingsManager = .shared) {
        self.playerSettings = playerSettings
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
        let flagManager = PremiumAccountFlagManager.shared
        let hasFlag = flagManager.hasAddedPremiumAccount()

        if !hasFlag {
            let locationService = IPLocationService.shared
            let foreign = await locationService.isForeignIP()
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
        let flagManager = PremiumAccountFlagManager.shared
        if flagManager.hasAddedPremiumAccount() {
            return true
        }
        return !isForeignIP
    }
}
