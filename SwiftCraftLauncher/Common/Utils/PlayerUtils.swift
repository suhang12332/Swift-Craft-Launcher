import CryptoKit
import SwiftUI

/// 玩家工具类，提供UUID生成和头像名称获取等功能
enum PlayerUtils {
    // MARK: - Constants

    /// 预定义的玩家名称列表
    private static let names = ["alex", "ari", "efe", "kai", "makena", "noor", "steve", "sunny", "zuri"]

    /// UUID 前缀
    private static let offlinePrefix = "OfflinePlayer:"

    // MARK: - UUID Generation

    /// 为离线玩家生成UUID
    /// - Parameter username: 玩家用户名
    /// - Returns: 生成的UUID字符串（小写）
    /// - Throws: GlobalError 当操作失败时
    static func generateOfflineUUID(for username: String) throws -> String {
        guard !username.isEmpty else { 
            throw GlobalError.player(
                chineseMessage: "无效的用户名: 用户名不能为空",
                i18nKey: "error.player.invalid_username_empty",
                level: .notification
            )
        }
        
        guard let data = (offlinePrefix + username).data(using: .utf8) else { 
            throw GlobalError.validation(
                chineseMessage: "用户名编码失败: \(username)",
                i18nKey: "error.validation.username_encode_failed",
                level: .notification
            )
        }
        
        var bytes = [UInt8](Insecure.MD5.hash(data: data))
        bytes[6] = (bytes[6] & 0x0F) | 0x30 // 版本3
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122
        let uuid = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        let uuidString = uuid.uuidString.lowercased()
        Logger.shared.debug("生成离线 UUID - 用户名：\(username), UUID：\(uuidString)")
        return uuidString
    }

    // MARK: - Avatar Name Generation

    /// 根据UUID获取对应的头像名称
    /// - Parameter uuid: 玩家UUID
    /// - Returns: 头像名称，如果UUID无效则返回nil
    static func avatarName(for uuid: String) -> String? {
        guard let index = nameIndex(for: uuid) else {
            Logger.shared.warning("无法获取头像名称 - 无效的UUID: \(uuid)")
            return nil
        }
        return names[index]
    }

    /// 根据UUID计算名称数组的索引
    /// - Parameter uuid: 玩家UUID
    /// - Returns: 名称数组的索引（0~8），如果UUID无效则返回nil
    private static func nameIndex(for uuid: String) -> Int? {
        let cleanUUID = uuid.replacingOccurrences(of: "-", with: "")
        guard cleanUUID.count >= 32 else { return nil }
        let iStr = String(cleanUUID.prefix(16))
        let uStr = String(cleanUUID.dropFirst(16).prefix(16))
        guard let i = UInt64(iStr, radix: 16), let u = UInt64(uStr, radix: 16) else { return nil }
        let f = i ^ u
        let mixedBits = (f ^ (f >> 32)) & 0xffff_ffff
        let ii = Int32(bitPattern: UInt32(truncatingIfNeeded: mixedBits))
        return (Int(ii) % names.count + names.count) % names.count
    }
}

// MARK: - Legacy Support (向后兼容)

/// 玩家相关错误类型（已废弃，请使用 GlobalError.player）
@available(*, deprecated, message: "请使用 GlobalError.player 替代")
enum PlayerError: LocalizedError {
    case invalidUsername
    case encodingError
    case uuidGenerationFailed
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "error.invalid_username".localized()
        case .encodingError:
            return "error.encoding".localized()
        case .uuidGenerationFailed:
            return "error.uuid_generation".localized()
        case .custom(let message):
            return message
        }
    }

    init(localizedDescription: String) {
        self = .custom(localizedDescription)
    }
} 
