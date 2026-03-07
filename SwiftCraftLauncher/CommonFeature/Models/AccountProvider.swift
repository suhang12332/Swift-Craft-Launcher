import Foundation

enum AccountProvider: String, Codable, Equatable {
    case offline
    case microsoft
    case littleskin

    var isOnline: Bool {
        self != .offline
    }

    var defaultAuthServerBaseURL: String {
        switch self {
        case .littleskin:
            return "https://littleskin.cn/api/yggdrasil"
        case .offline, .microsoft:
            return ""
        }
    }

    static func inferFromLegacyAvatar(_ avatar: String) -> Self {
        if avatar.hasPrefix("http://") || avatar.hasPrefix("https://") {
            return Self.microsoft
        }
        return Self.offline
    }
}
