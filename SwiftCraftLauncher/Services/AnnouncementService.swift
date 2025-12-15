import Foundation

/// 公告服务
class AnnouncementService {
    static let shared = AnnouncementService()

    private init() {}

    /// 获取公告
    /// - Parameters:
    ///   - version: 应用版本号
    ///   - language: 语言代码
    /// - Returns: 公告数据，如果不存在或失败则返回nil
    func fetchAnnouncement(version: String, language: String) async -> AnnouncementData? {
        let url = URLConfig.API.GitHub.announcement(version: version, language: language)

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.shared.debug("公告API响应无效")
                return nil
            }

            // 如果是404，返回nil（不显示公告）
            if httpResponse.statusCode == 404 {
                Logger.shared.debug("公告不存在 (404)")
                return nil
            }

            // 检查状态码是否为200
            guard httpResponse.statusCode == 200 else {
                Logger.shared.debug("公告API请求失败，状态码: \(httpResponse.statusCode)")
                return nil
            }

            // 解析JSON
            let announcementResponse = try JSONDecoder().decode(AnnouncementResponse.self, from: data)

            // 检查是否成功且有数据
            guard announcementResponse.success, let announcementData = announcementResponse.data else {
                Logger.shared.debug("公告响应不成功或无数据")
                return nil
            }

            return announcementData
        } catch {
            // HTTP 404 已经在上面通过状态码检查处理了
            // 这里只处理网络错误和解析错误
            Logger.shared.debug("获取公告失败: \(error.localizedDescription)")
            return nil
        }
    }
}
