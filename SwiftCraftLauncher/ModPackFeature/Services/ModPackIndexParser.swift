import Foundation

enum ModPackIndexParser {
    static func parseIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        for adapter in adapters where await adapter.canParse(extractedPath: extractedPath) {
            if let info = await adapter.parseToModrinthIndexInfo(extractedPath: extractedPath) {
                return info
            }
        }
        return nil
    }

    /// 优先解析 Modrinth，其次再尝试其他格式
    private static let adapters: [any ModPackIndexAdapter] = [
        ModrinthIndexAdapter(),
        CurseForgeZipIndexAdapter(),
    ]
}
