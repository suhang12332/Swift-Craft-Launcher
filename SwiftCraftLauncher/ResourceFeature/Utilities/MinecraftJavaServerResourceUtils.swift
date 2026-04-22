import Foundation

enum MinecraftJavaServerResourceUtils {
    static func parseAddress(from detail: ModrinthProjectDetail) -> String {
        let rawFileName = detail.fileName ?? ""
        return CommonUtil.parseMinecraftJavaServerInfo(from: rawFileName).address
    }

    @MainActor
    static func addServerToGameIfNeeded(
        game: GameVersionInfo,
        detail: ModrinthProjectDetail
    ) async throws {
        let address = parseAddress(from: detail)
        guard !address.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "无法解析服务器地址",
                i18nKey: "error.server.invalid_address",
                level: .notification
            )
        }

        try await AppServices.serverAddressService.addServerIfNeeded(
            for: game.gameName,
            address: address,
            name: detail.title
        )
    }
}
