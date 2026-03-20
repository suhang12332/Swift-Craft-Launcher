import Foundation

protocol ModPackIndexAdapter {
    /// 适配器标识（用于日志）
    var id: String { get }

    /// 判断该解压目录是否可由此适配器解析
    func canParse(extractedPath: URL) async -> Bool

    /// 解析并转换为统一的 Modrinth 索引信息
    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo?
}
