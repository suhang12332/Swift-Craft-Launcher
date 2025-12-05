import Foundation

/// 公告响应模型
struct AnnouncementResponse: Codable {
    let success: Bool
    let data: AnnouncementData?
}

/// 公告数据模型
struct AnnouncementData: Codable {
    let title: String
    let content: String
    let author: String
}
